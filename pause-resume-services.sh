#!/bin/bash

# Script para Pausar/Reativar Serviços - Projeto BIA
# Autor: Amazon Q
# Versão: 1.0

set -e

# Configurações padrão
DEFAULT_CLUSTER="cluster-bia-alb"
DEFAULT_SERVICE="service-bia-alb-teste"
DEFAULT_REGION="us-east-1"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para logging
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
}

# Função para exibir help
show_help() {
    cat << EOF
${GREEN}Script de Pausa/Reativação de Serviços - Projeto BIA${NC}

${BLUE}DESCRIÇÃO:${NC}
    Este script permite pausar e reativar os serviços da infraestrutura BIA
    de forma segura, mantendo todos os recursos criados.

${BLUE}USO:${NC}
    $0 [COMANDO] [OPÇÕES]

${BLUE}COMANDOS:${NC}
    pause           Pausa todos os serviços (define desiredCount=0)
    resume          Reativa todos os serviços (define desiredCount=2)
    status          Mostra status atual dos serviços
    help            Exibe esta ajuda

${BLUE}OPÇÕES:${NC}
    -r, --region REGION         Região AWS (padrão: $DEFAULT_REGION)
    -c, --cluster CLUSTER       Nome do cluster ECS (padrão: $DEFAULT_CLUSTER)
    -s, --service SERVICE       Nome do serviço ECS (padrão: $DEFAULT_SERVICE)
    --dry-run                   Simula as ações sem executar
    -h, --help                  Exibe esta ajuda

${BLUE}EXEMPLOS:${NC}
    # Pausar todos os serviços
    $0 pause

    # Reativar todos os serviços
    $0 resume

    # Verificar status atual
    $0 status

    # Simular pausa (dry-run)
    $0 pause --dry-run

${BLUE}O QUE É PAUSADO:${NC}
    ✓ Serviço ECS (desiredCount = 0)
    ✓ Tasks do ECS são finalizadas
    
${BLUE}O QUE NÃO É AFETADO:${NC}
    ✓ Cluster ECS (mantido)
    ✓ Task Definitions (mantidas)
    ✓ Application Load Balancer (mantido)
    ✓ Target Groups (mantidos)
    ✓ Security Groups (mantidos)
    ✓ Banco RDS (mantido)
    ✓ Repositório ECR (mantido)

${BLUE}ECONOMIA DE CUSTOS:${NC}
    Pausar os serviços elimina os custos de:
    • Instâncias EC2 do cluster ECS
    • Processamento de tasks
    • Transferência de dados

EOF
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "STEP" "Verificando pré-requisitos..."
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log "ERROR" "AWS CLI não encontrado"
        exit 1
    fi
    
    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null 2>&1; then
        log "ERROR" "Credenciais AWS inválidas"
        exit 1
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq não encontrado (necessário para processamento JSON)"
        exit 1
    fi
    
    log "SUCCESS" "Pré-requisitos verificados"
}

# Função para obter status atual do serviço
get_service_status() {
    local service_info=$(aws ecs describe-services \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" \
        --query 'services[0]' \
        --output json 2>/dev/null)
    
    if [ "$service_info" = "null" ] || [ -z "$service_info" ]; then
        log "ERROR" "Serviço não encontrado: $SERVICE"
        return 1
    fi
    
    echo "$service_info"
}

# Função para exibir status detalhado
show_status() {
    log "STEP" "Verificando status dos serviços..."
    
    local service_info=$(get_service_status)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local status=$(echo "$service_info" | jq -r '.status')
    local desired=$(echo "$service_info" | jq -r '.desiredCount')
    local running=$(echo "$service_info" | jq -r '.runningCount')
    local pending=$(echo "$service_info" | jq -r '.pendingCount')
    local task_def=$(echo "$service_info" | jq -r '.taskDefinition' | sed 's/.*\///')
    
    echo
    echo -e "${CYAN}=== STATUS DA INFRAESTRUTURA BIA ===${NC}"
    echo -e "Serviço ECS: ${GREEN}$SERVICE${NC}"
    echo -e "Status: ${GREEN}$status${NC}"
    echo -e "Task Definition: ${BLUE}$task_def${NC}"
    echo -e "Tasks Desejadas: ${YELLOW}$desired${NC}"
    echo -e "Tasks Rodando: ${GREEN}$running${NC}"
    echo -e "Tasks Pendentes: ${YELLOW}$pending${NC}"
    
    # Determinar estado
    if [ "$desired" -eq 0 ]; then
        echo -e "Estado: ${YELLOW}PAUSADO${NC} 💤"
        echo -e "Economia: ${GREEN}Custos de compute eliminados${NC}"
    elif [ "$running" -eq "$desired" ] && [ "$pending" -eq 0 ]; then
        echo -e "Estado: ${GREEN}ATIVO${NC} ✅"
        echo -e "Aplicação: ${GREEN}Disponível${NC}"
    else
        echo -e "Estado: ${YELLOW}TRANSITÓRIO${NC} 🔄"
        echo -e "Aplicação: ${YELLOW}Indisponível temporariamente${NC}"
    fi
    
    # Verificar eventos recentes
    local recent_events=$(echo "$service_info" | jq -r '.events[0:3][] | "\(.createdAt) - \(.message)"' | head -3)
    echo -e "\n${CYAN}Eventos Recentes:${NC}"
    echo "$recent_events"
    echo
}

# Função para pausar serviços
pause_services() {
    log "STEP" "Pausando serviços da infraestrutura BIA..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Pausaria o serviço ECS definindo desiredCount=0"
        return
    fi
    
    # Verificar se já está pausado
    local service_info=$(get_service_status)
    local current_desired=$(echo "$service_info" | jq -r '.desiredCount')
    
    if [ "$current_desired" -eq 0 ]; then
        log "WARNING" "Serviços já estão pausados"
        return
    fi
    
    # Salvar estado atual para restauração
    echo "$current_desired" > .last_desired_count
    log "INFO" "Estado atual salvo (desiredCount: $current_desired)"
    
    # Pausar serviço ECS
    log "INFO" "Pausando serviço ECS..."
    aws ecs update-service \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --desired-count 0 \
        --region "$REGION" \
        --output table > /dev/null
    
    log "SUCCESS" "Serviço ECS pausado"
    
    # Aguardar finalização das tasks
    log "INFO" "Aguardando finalização das tasks..."
    local max_wait=300  # 5 minutos
    local wait_time=0
    local check_interval=10
    
    while [ $wait_time -lt $max_wait ]; do
        local current_running=$(aws ecs describe-services \
            --cluster "$CLUSTER" \
            --services "$SERVICE" \
            --region "$REGION" \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null)
        
        if [ "$current_running" -eq 0 ]; then
            log "SUCCESS" "Todas as tasks foram finalizadas"
            break
        fi
        
        log "INFO" "Tasks ainda rodando: $current_running"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        log "WARNING" "Timeout aguardando finalização das tasks"
    fi
    
    log "SUCCESS" "=== SERVIÇOS PAUSADOS COM SUCESSO ==="
    log "INFO" "Custos de compute eliminados"
    log "INFO" "Para reativar, execute: $0 resume"
}

# Função para reativar serviços
resume_services() {
    log "STEP" "Reativando serviços da infraestrutura BIA..."
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[DRY-RUN] Reativaria o serviço ECS"
        return
    fi
    
    # Verificar se está pausado
    local service_info=$(get_service_status)
    local current_desired=$(echo "$service_info" | jq -r '.desiredCount')
    
    if [ "$current_desired" -gt 0 ]; then
        log "WARNING" "Serviços já estão ativos (desiredCount: $current_desired)"
        return
    fi
    
    # Determinar desiredCount para restaurar
    local target_desired=2  # Padrão
    if [ -f .last_desired_count ]; then
        target_desired=$(cat .last_desired_count)
        log "INFO" "Restaurando estado anterior (desiredCount: $target_desired)"
    else
        log "INFO" "Usando configuração padrão (desiredCount: $target_desired)"
    fi
    
    # Reativar serviço ECS
    log "INFO" "Reativando serviço ECS..."
    aws ecs update-service \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --desired-count "$target_desired" \
        --region "$REGION" \
        --output table > /dev/null
    
    log "SUCCESS" "Serviço ECS reativado"
    
    # Aguardar inicialização das tasks
    log "INFO" "Aguardando inicialização das tasks..."
    local max_wait=600  # 10 minutos
    local wait_time=0
    local check_interval=15
    
    while [ $wait_time -lt $max_wait ]; do
        local current_status=$(aws ecs describe-services \
            --cluster "$CLUSTER" \
            --services "$SERVICE" \
            --region "$REGION" \
            --query 'services[0].{running:runningCount,desired:desiredCount}' \
            --output json 2>/dev/null)
        
        local running=$(echo "$current_status" | jq -r '.running')
        local desired=$(echo "$current_status" | jq -r '.desired')
        
        if [ "$running" -eq "$desired" ]; then
            log "SUCCESS" "Todas as tasks estão rodando ($running/$desired)"
            break
        fi
        
        log "INFO" "Tasks inicializando: $running/$desired"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        log "WARNING" "Timeout aguardando inicialização completa"
        log "INFO" "Verifique o status com: $0 status"
    fi
    
    log "SUCCESS" "=== SERVIÇOS REATIVADOS COM SUCESSO ==="
    log "INFO" "Aplicação deve estar disponível em alguns minutos"
    log "INFO" "Verifique o status com: $0 status"
}

# Parsing dos argumentos
COMMAND=""
REGION="$DEFAULT_REGION"
CLUSTER="$DEFAULT_CLUSTER"
SERVICE="$DEFAULT_SERVICE"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        pause|resume|status|help)
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

# Verificar pré-requisitos
check_prerequisites

# Executar comando
case $COMMAND in
    help)
        show_help
        ;;
    pause)
        pause_services
        ;;
    resume)
        resume_services
        ;;
    status)
        show_status
        ;;
    *)
        log "ERROR" "Comando desconhecido: $COMMAND"
        exit 1
        ;;
esac
