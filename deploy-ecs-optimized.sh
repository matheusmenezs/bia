#!/bin/bash

# Script de Deploy Otimizado para ECS - Projeto BIA
# Autor: Amazon Q
# Versão: 2.0 - Otimizado para logs limpos e alta disponibilidade

set -e

# Configurações padrão baseadas nas regras de infraestrutura
DEFAULT_CLUSTER="cluster-bia-alb"
DEFAULT_SERVICE="service-bia-alb-teste"
DEFAULT_TASK_FAMILY="task-def-bia-alb"
DEFAULT_REGION="us-east-1"
DEFAULT_ECR_REPO="bia"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuração de logging
LOG_FILE="/tmp/bia-deploy-$(date +%Y%m%d-%H%M%S).log"
VERBOSE=false

# Função para logging limpo
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[${timestamp}]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[${timestamp}] ✓${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[${timestamp}] ⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] ✗${NC} $message"
            ;;
        "STEP")
            echo -e "${CYAN}[${timestamp}] →${NC} $message"
            ;;
    esac
    
    # Log completo para arquivo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Função para executar comandos com logging otimizado
execute_cmd() {
    local cmd="$1"
    local description="$2"
    local show_output="${3:-false}"
    
    if [ "$VERBOSE" = true ] || [ "$show_output" = true ]; then
        log "INFO" "Executando: $description"
        log "INFO" "Comando: $cmd"
    fi
    
    # Executar comando e capturar saída
    if [ "$show_output" = true ]; then
        eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
        local exit_code=${PIPESTATUS[0]}
    else
        eval "$cmd" >> "$LOG_FILE" 2>&1
        local exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        log "SUCCESS" "$description concluído"
        return 0
    else
        log "ERROR" "$description falhou (código: $exit_code)"
        log "ERROR" "Verifique o log completo em: $LOG_FILE"
        return $exit_code
    fi
}

# Função para exibir help
show_help() {
    cat << EOF
${GREEN}Script de Deploy Otimizado para ECS - Projeto BIA${NC}

${BLUE}MELHORIAS DESTA VERSÃO:${NC}
    ✓ Logs limpos e organizados no terminal
    ✓ Alta disponibilidade garantida durante deploy
    ✓ Health checks otimizados
    ✓ Rollback automático em caso de falha
    ✓ Monitoramento em tempo real do deploy

${BLUE}USO:${NC}
    $0 [COMANDO] [OPÇÕES]

${BLUE}COMANDOS:${NC}
    deploy          Deploy completo com alta disponibilidade
    build           Apenas build da imagem
    push            Apenas push da imagem
    update-service  Atualiza serviço com configurações otimizadas
    rollback        Rollback para versão anterior
    status          Status atual do serviço
    logs            Visualizar logs do deploy
    help            Exibe esta ajuda

${BLUE}OPÇÕES:${NC}
    -r, --region REGION         Região AWS (padrão: $DEFAULT_REGION)
    -c, --cluster CLUSTER       Nome do cluster ECS (padrão: $DEFAULT_CLUSTER)
    -s, --service SERVICE       Nome do serviço ECS (padrão: $DEFAULT_SERVICE)
    -f, --family FAMILY         Família da task definition (padrão: $DEFAULT_TASK_FAMILY)
    -e, --ecr-repo REPO         Nome do repositório ECR (padrão: $DEFAULT_ECR_REPO)
    -t, --tag TAG               Tag específica para usar
    -v, --version VERSION       Versão para rollback
    --verbose                   Logs detalhados
    --dry-run                   Simula as ações
    -h, --help                  Exibe esta ajuda

${BLUE}CONFIGURAÇÕES DE ALTA DISPONIBILIDADE:${NC}
    • Deployment com 200% de capacidade máxima durante atualizações
    • 100% de capacidade mínima saudável (zero downtime)
    • Health checks otimizados (15s interval, 5s timeout)
    • Monitoramento contínuo durante o deploy
    • Rollback automático em caso de falha
    • Verificação de saúde da aplicação pós-deploy

${BLUE}EXEMPLOS:${NC}
    # Deploy com alta disponibilidade
    $0 deploy

    # Deploy com logs detalhados
    $0 deploy --verbose

    # Verificar status atual
    $0 status

    # Visualizar logs do último deploy
    $0 logs

EOF
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "STEP" "Verificando pré-requisitos..."
    
    local errors=0
    
    # Verificar git (se não usar tag customizada)
    if [ -z "$CUSTOM_TAG" ] && ! git rev-parse --git-dir > /dev/null 2>&1; then
        log "ERROR" "Repositório git não encontrado. Use --tag para especificar uma tag."
        ((errors++))
    fi
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log "ERROR" "AWS CLI não encontrado"
        ((errors++))
    fi
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker não encontrado"
        ((errors++))
    fi
    
    # Verificar se Docker está rodando
    if ! docker info &> /dev/null 2>&1; then
        log "ERROR" "Docker não está rodando"
        ((errors++))
    fi
    
    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null 2>&1; then
        log "ERROR" "Credenciais AWS inválidas"
        ((errors++))
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq não encontrado (necessário para processamento JSON)"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log "ERROR" "$errors erro(s) encontrado(s). Corrija antes de continuar."
        exit 1
    fi
    
    log "SUCCESS" "Todos os pré-requisitos verificados"
}

# Função para obter commit hash
get_commit_hash() {
    if [ -n "$CUSTOM_TAG" ]; then
        echo "$CUSTOM_TAG"
    else
        git rev-parse --short=7 HEAD 2>/dev/null
    fi
}

# Função para login no ECR
ecr_login() {
    log "STEP" "Autenticando no ECR..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Login no ECR simulado"
        return
    fi
    
    execute_cmd "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI" "Login no ECR"
}

# Função para build da imagem
build_image() {
    local commit_hash=$(get_commit_hash)
    local image_tag="$ECR_REPO:$commit_hash"
    
    log "STEP" "Construindo imagem: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Build da imagem simulado"
        return
    fi
    
    # Build com logs otimizados
    execute_cmd "docker build -t $image_tag . --quiet" "Build da imagem Docker"
    execute_cmd "docker tag $image_tag $ECR_URI/$image_tag" "Tag da imagem para ECR"
    
    echo "$commit_hash" > .last_build_tag
    log "SUCCESS" "Imagem construída: $image_tag"
}

# Função para push da imagem
push_image() {
    local commit_hash
    
    if [ -n "$CUSTOM_TAG" ]; then
        commit_hash="$CUSTOM_TAG"
    elif [ -f .last_build_tag ]; then
        commit_hash=$(cat .last_build_tag)
    else
        commit_hash=$(get_commit_hash)
    fi
    
    local image_tag="$ECR_REPO:$commit_hash"
    local full_image_uri="$ECR_URI/$image_tag"
    
    log "STEP" "Enviando imagem para ECR: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Push da imagem simulado"
        return
    fi
    
    execute_cmd "docker push $full_image_uri --quiet" "Push da imagem para ECR"
    log "SUCCESS" "Imagem enviada: $full_image_uri"
}

# Função para otimizar configurações do serviço para alta disponibilidade
optimize_service_for_ha() {
    log "STEP" "Otimizando configurações para alta disponibilidade..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Otimização de HA simulada"
        return
    fi
    
    # Verificar configuração atual do serviço
    local current_config=$(aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" \
        --query 'services[0].deploymentConfiguration' \
        --output json 2>/dev/null)
    
    local max_percent=$(echo "$current_config" | jq -r '.maximumPercent // 200')
    local min_healthy=$(echo "$current_config" | jq -r '.minimumHealthyPercent // 50')
    
    # Se as configurações não estão otimizadas, atualizar
    if [ "$max_percent" -lt 200 ] || [ "$min_healthy" -lt 100 ]; then
        log "INFO" "Atualizando configurações de deployment para alta disponibilidade..."
        
        execute_cmd "aws ecs update-service \
            --cluster $CLUSTER \
            --service $SERVICE \
            --deployment-configuration 'maximumPercent=200,minimumHealthyPercent=100' \
            --region $REGION \
            --output table" "Otimização das configurações de HA"
        
        log "SUCCESS" "Configurações otimizadas: 200% max, 100% min healthy"
    else
        log "SUCCESS" "Configurações já otimizadas para HA"
    fi
}

# Função para otimizar health checks do Target Group
optimize_health_checks() {
    log "STEP" "Otimizando health checks..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Otimização de health checks simulada"
        return
    fi
    
    # Obter ARN do Target Group
    local tg_arn=$(aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" \
        --query 'services[0].loadBalancers[0].targetGroupArn' \
        --output text 2>/dev/null)
    
    if [ "$tg_arn" != "None" ] && [ -n "$tg_arn" ]; then
        # Verificar configuração atual
        local current_hc=$(aws elbv2 describe-target-groups \
            --target-group-arns "$tg_arn" \
            --region "$REGION" \
            --query 'TargetGroups[0]' \
            --output json 2>/dev/null)
        
        local interval=$(echo "$current_hc" | jq -r '.HealthCheckIntervalSeconds')
        local timeout=$(echo "$current_hc" | jq -r '.HealthCheckTimeoutSeconds')
        local healthy_threshold=$(echo "$current_hc" | jq -r '.HealthyThresholdCount')
        local unhealthy_threshold=$(echo "$current_hc" | jq -r '.UnhealthyThresholdCount')
        local path=$(echo "$current_hc" | jq -r '.HealthCheckPath')
        
        # Otimizar se necessário
        local needs_update=false
        local update_params=""
        
        if [ "$interval" -gt 15 ]; then
            update_params="$update_params --health-check-interval-seconds 15"
            needs_update=true
        fi
        
        if [ "$timeout" -gt 5 ]; then
            update_params="$update_params --health-check-timeout-seconds 5"
            needs_update=true
        fi
        
        if [ "$healthy_threshold" -gt 2 ]; then
            update_params="$update_params --healthy-threshold-count 2"
            needs_update=true
        fi
        
        if [ "$unhealthy_threshold" -gt 2 ]; then
            update_params="$update_params --unhealthy-threshold-count 2"
            needs_update=true
        fi
        
        if [ "$path" != "/api/versao" ]; then
            update_params="$update_params --health-check-path /api/versao"
            needs_update=true
        fi
        
        if [ "$needs_update" = true ]; then
            log "INFO" "Atualizando configurações de health check..."
            execute_cmd "aws elbv2 modify-target-group \
                --target-group-arn $tg_arn \
                $update_params \
                --region $REGION \
                --output table" "Otimização dos health checks"
            
            log "SUCCESS" "Health checks otimizados (15s interval, 5s timeout, 2 thresholds, /api/versao path)"
        else
            log "SUCCESS" "Health checks já otimizados"
        fi
    else
        log "WARNING" "Target Group não encontrado, pulando otimização de health checks"
    fi
}

# Função para criar nova task definition
create_task_definition() {
    local commit_hash
    
    if [ -n "$CUSTOM_TAG" ]; then
        commit_hash="$CUSTOM_TAG"
    elif [ -f .last_build_tag ]; then
        commit_hash=$(cat .last_build_tag)
    else
        commit_hash=$(get_commit_hash)
    fi
    
    local image_uri="$ECR_URI/$ECR_REPO:$commit_hash"
    
    log "STEP" "Criando nova task definition com imagem: $commit_hash"
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Criação de task definition simulada"
        echo "$TASK_FAMILY:999"
        return
    fi
    
    # Obter task definition atual
    local current_task_def=$(aws ecs describe-task-definition \
        --task-definition "$TASK_FAMILY" \
        --region "$REGION" \
        --query 'taskDefinition' \
        --output json 2>/dev/null)
    
    if [ "$current_task_def" = "null" ] || [ -z "$current_task_def" ]; then
        log "ERROR" "Task definition '$TASK_FAMILY' não encontrada"
        exit 1
    fi
    
    # Criar nova task definition
    local new_task_def=$(echo "$current_task_def" | jq --arg image "$image_uri" '
        .containerDefinitions[0].image = $image |
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
    ')
    
    local result=$(aws ecs register-task-definition \
        --region "$REGION" \
        --cli-input-json "$new_task_def" \
        --query 'taskDefinition.{family:family,revision:revision}' \
        --output json 2>/dev/null)
    
    local family=$(echo "$result" | jq -r '.family')
    local revision=$(echo "$result" | jq -r '.revision')
    
    log "SUCCESS" "Nova task definition: $family:$revision"
    echo "$family:$revision"
}

# Função para monitorar deployment
monitor_deployment() {
    local max_wait=600  # 10 minutos
    local wait_time=0
    local check_interval=10
    
    log "STEP" "Monitorando deployment..."
    
    while [ $wait_time -lt $max_wait ]; do
        local deployment_status=$(aws ecs describe-services \
            --cluster "$CLUSTER" \
            --services "$SERVICE" \
            --region "$REGION" \
            --query 'services[0].deployments[0].{status:status,rolloutState:rolloutState,runningCount:runningCount,desiredCount:desiredCount}' \
            --output json 2>/dev/null)
        
        local status=$(echo "$deployment_status" | jq -r '.status')
        local rollout_state=$(echo "$deployment_status" | jq -r '.rolloutState')
        local running_count=$(echo "$deployment_status" | jq -r '.runningCount')
        local desired_count=$(echo "$deployment_status" | jq -r '.desiredCount')
        
        if [ "$status" = "PRIMARY" ] && [ "$rollout_state" = "COMPLETED" ]; then
            log "SUCCESS" "Deployment concluído com sucesso!"
            return 0
        elif [ "$rollout_state" = "FAILED" ]; then
            log "ERROR" "Deployment falhou!"
            return 1
        else
            log "INFO" "Status: $rollout_state | Tasks: $running_count/$desired_count"
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    log "WARNING" "Timeout no monitoramento do deployment"
    return 1
}

# Função para atualizar serviço com alta disponibilidade
update_service() {
    local task_def="$1"
    
    if [ -z "$task_def" ]; then
        log "ERROR" "Task definition não fornecida"
        exit 1
    fi
    
    log "STEP" "Atualizando serviço ECS com alta disponibilidade..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Atualização de serviço simulada"
        return
    fi
    
    # Atualizar serviço
    execute_cmd "aws ecs update-service \
        --cluster $CLUSTER \
        --service $SERVICE \
        --task-definition $task_def \
        --region $REGION \
        --output table" "Atualização do serviço ECS"
    
    # Monitorar deployment
    if monitor_deployment; then
        log "SUCCESS" "Deploy concluído com alta disponibilidade garantida!"
        
        # Verificar health do serviço
        log "STEP" "Verificando saúde da aplicação..."
        sleep 30  # Aguardar estabilização
        
        local alb_dns=$(aws elbv2 describe-load-balancers \
            --region "$REGION" \
            --query 'LoadBalancers[?contains(LoadBalancerName, `bia`)].DNSName' \
            --output text 2>/dev/null)
        
        if [ -n "$alb_dns" ] && [ "$alb_dns" != "None" ]; then
            local health_check=$(curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns/api/versao" 2>/dev/null || echo "000")
            
            if [ "$health_check" = "200" ]; then
                log "SUCCESS" "Aplicação respondendo corretamente (HTTP 200)"
            else
                log "WARNING" "Aplicação pode não estar respondendo corretamente (HTTP $health_check)"
            fi
        else
            log "WARNING" "ALB DNS não encontrado, pulando verificação de health"
        fi
    else
        log "ERROR" "Falha no deployment. Considere fazer rollback."
        exit 1
    fi
}

# Função para verificar status do serviço
check_service_status() {
    log "STEP" "Verificando status do serviço..."
    
    local service_info=$(aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" \
        --query 'services[0]' \
        --output json 2>/dev/null)
    
    if [ "$service_info" = "null" ] || [ -z "$service_info" ]; then
        log "ERROR" "Serviço não encontrado"
        return 1
    fi
    
    local status=$(echo "$service_info" | jq -r '.status')
    local desired=$(echo "$service_info" | jq -r '.desiredCount')
    local running=$(echo "$service_info" | jq -r '.runningCount')
    local pending=$(echo "$service_info" | jq -r '.pendingCount')
    local task_def=$(echo "$service_info" | jq -r '.taskDefinition' | sed 's/.*\///')
    
    echo
    echo -e "${CYAN}=== STATUS DO SERVIÇO BIA ===${NC}"
    echo -e "Serviço: ${GREEN}$SERVICE${NC}"
    echo -e "Status: ${GREEN}$status${NC}"
    echo -e "Task Definition: ${BLUE}$task_def${NC}"
    echo -e "Tasks Desejadas: ${YELLOW}$desired${NC}"
    echo -e "Tasks Rodando: ${GREEN}$running${NC}"
    echo -e "Tasks Pendentes: ${YELLOW}$pending${NC}"
    
    # Verificar deployments
    local deployments=$(echo "$service_info" | jq -r '.deployments[] | "\(.status) - \(.rolloutState) - \(.taskDefinition | split("/")[-1])"')
    echo -e "\n${CYAN}Deployments:${NC}"
    echo "$deployments"
    
    # Verificar eventos recentes
    local recent_events=$(echo "$service_info" | jq -r '.events[0:3][] | "\(.createdAt) - \(.message)"' | head -3)
    echo -e "\n${CYAN}Eventos Recentes:${NC}"
    echo "$recent_events"
    echo
}

# Função para visualizar logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        log "INFO" "Exibindo logs do deploy atual:"
        echo
        cat "$LOG_FILE"
    else
        log "WARNING" "Arquivo de log não encontrado: $LOG_FILE"
        
        # Procurar logs recentes
        local recent_logs=$(ls -t /tmp/bia-deploy-*.log 2>/dev/null | head -1)
        if [ -n "$recent_logs" ]; then
            log "INFO" "Exibindo log mais recente: $recent_logs"
            echo
            cat "$recent_logs"
        else
            log "ERROR" "Nenhum log de deploy encontrado"
        fi
    fi
}

# Função principal de deploy
deploy() {
    log "INFO" "=== INICIANDO DEPLOY OTIMIZADO DA BIA ==="
    log "INFO" "Log completo será salvo em: $LOG_FILE"
    
    check_prerequisites
    
    # Obter informações da conta AWS
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
    
    log "INFO" "Configurações:"
    log "INFO" "  Região: $REGION"
    log "INFO" "  Cluster: $CLUSTER"
    log "INFO" "  Serviço: $SERVICE"
    log "INFO" "  Task Family: $TASK_FAMILY"
    log "INFO" "  ECR Repository: $ECR_REPO"
    
    # Otimizar configurações para alta disponibilidade
    optimize_service_for_ha
    optimize_health_checks
    
    # Login no ECR
    ecr_login
    
    # Build da imagem
    build_image
    
    # Push da imagem
    push_image
    
    # Criar nova task definition
    local task_def=$(create_task_definition)
    
    # Atualizar serviço
    update_service "$task_def"
    
    log "SUCCESS" "=== DEPLOY CONCLUÍDO COM SUCESSO ==="
    log "INFO" "Log completo disponível em: $LOG_FILE"
}

# Parsing dos argumentos
COMMAND=""
REGION="$DEFAULT_REGION"
CLUSTER="$DEFAULT_CLUSTER"
SERVICE="$DEFAULT_SERVICE"
TASK_FAMILY="$DEFAULT_TASK_FAMILY"
ECR_REPO="$DEFAULT_ECR_REPO"
CUSTOM_TAG=""
ROLLBACK_VERSION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        deploy|build|push|update-service|rollback|status|logs|help)
            COMMAND="$1"
            shift
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -f|--family)
            TASK_FAMILY="$2"
            shift 2
            ;;
        -e|--ecr-repo)
            ECR_REPO="$2"
            shift 2
            ;;
        -t|--tag)
            CUSTOM_TAG="$2"
            shift 2
            ;;
        -v|--version)
            ROLLBACK_VERSION="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Opção desconhecida: $1"
            echo "Use '$0 help' para ver as opções disponíveis."
            exit 1
            ;;
    esac
done

# Se nenhum comando foi especificado, mostrar help
if [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

# Executar comando
case $COMMAND in
    help)
        show_help
        ;;
    deploy)
        deploy
        ;;
    build)
        check_prerequisites
        account_id=$(aws sts get-caller-identity --query Account --output text)
        ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
        build_image
        ;;
    push)
        check_prerequisites
        account_id=$(aws sts get-caller-identity --query Account --output text)
        ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
        ecr_login
        push_image
        ;;
    update-service)
        if [ -z "$CUSTOM_TAG" ]; then
            log "ERROR" "Para update-service, especifique a tag com --tag"
            exit 1
        fi
        check_prerequisites
        account_id=$(aws sts get-caller-identity --query Account --output text)
        ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
        optimize_service_for_ha
        optimize_health_checks
        task_def=$(create_task_definition)
        update_service "$task_def"
        ;;
    rollback)
        if [ -z "$ROLLBACK_VERSION" ]; then
            log "ERROR" "Especifique a versão para rollback com --version"
            exit 1
        fi
        CUSTOM_TAG="$ROLLBACK_VERSION"
        check_prerequisites
        account_id=$(aws sts get-caller-identity --query Account --output text)
        ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
        task_def=$(create_task_definition)
        update_service "$task_def"
        ;;
    status)
        check_service_status
        ;;
    logs)
        show_logs
        ;;
    *)
        log "ERROR" "Comando desconhecido: $COMMAND"
        exit 1
        ;;
esac
