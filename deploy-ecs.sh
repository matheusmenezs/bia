#!/bin/bash

# Script de Deploy para ECS - Projeto BIA
# Autor: Amazon Q
# Versão: 1.0

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
NC='\033[0m' # No Color

# Função para exibir mensagens coloridas
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Função para exibir help
show_help() {
    cat << EOF
${GREEN}Script de Deploy para ECS - Projeto BIA${NC}

${BLUE}DESCRIÇÃO:${NC}
    Este script automatiza o processo de deploy para ECS, incluindo:
    - Build da imagem Docker com tag baseada no commit hash
    - Push para ECR
    - Criação de nova task definition
    - Deploy no serviço ECS
    - Funcionalidade de rollback

${BLUE}USO:${NC}
    $0 [COMANDO] [OPÇÕES]

${BLUE}COMANDOS:${NC}
    deploy          Executa o deploy completo (build + push + deploy)
    build           Apenas faz o build da imagem
    push            Apenas faz o push da imagem (requer build prévio)
    update-service  Apenas atualiza o serviço ECS
    rollback        Faz rollback para uma versão anterior
    list-versions   Lista as versões disponíveis para rollback
    help            Exibe esta ajuda

${BLUE}OPÇÕES:${NC}
    -r, --region REGION         Região AWS (padrão: $DEFAULT_REGION)
    -c, --cluster CLUSTER       Nome do cluster ECS (padrão: $DEFAULT_CLUSTER)
    -s, --service SERVICE       Nome do serviço ECS (padrão: $DEFAULT_SERVICE)
    -f, --family FAMILY         Família da task definition (padrão: $DEFAULT_TASK_FAMILY)
    -e, --ecr-repo REPO         Nome do repositório ECR (padrão: $DEFAULT_ECR_REPO)
    -t, --tag TAG               Tag específica para usar (padrão: commit hash)
    -v, --version VERSION       Versão para rollback (usar com comando rollback)
    --dry-run                   Simula as ações sem executar
    -h, --help                  Exibe esta ajuda

${BLUE}EXEMPLOS:${NC}
    # Deploy completo com configurações padrão
    $0 deploy

    # Deploy em região específica
    $0 deploy --region us-west-2

    # Apenas build da imagem
    $0 build

    # Rollback para versão específica
    $0 rollback --version abc123f

    # Listar versões disponíveis
    $0 list-versions

    # Deploy com dry-run (simulação)
    $0 deploy --dry-run

${BLUE}PRÉ-REQUISITOS:${NC}
    - AWS CLI configurado
    - Docker instalado e rodando
    - Permissões para ECR e ECS
    - Repositório ECR já criado
    - Cluster e serviço ECS já configurados

${BLUE}ESTRUTURA DE TAGS:${NC}
    As imagens são tagueadas com os últimos 7 caracteres do commit hash.
    Exemplo: bia:abc123f

${BLUE}ROLLBACK:${NC}
    O rollback funciona criando uma nova task definition que aponta para
    uma imagem anterior e atualizando o serviço para usar essa versão.

EOF
}

# Função para obter o commit hash
get_commit_hash() {
    if [ -n "$CUSTOM_TAG" ]; then
        echo "$CUSTOM_TAG"
    else
        git rev-parse --short=7 HEAD 2>/dev/null || {
            log_error "Não foi possível obter o commit hash. Certifique-se de estar em um repositório git."
            exit 1
        }
    fi
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log_info "Verificando pré-requisitos..."
    
    # Verificar se está em um repositório git (se não usar tag customizada)
    if [ -z "$CUSTOM_TAG" ] && ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Este diretório não é um repositório git. Use --tag para especificar uma tag customizada."
        exit 1
    fi
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI não encontrado. Instale o AWS CLI."
        exit 1
    fi
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker não encontrado. Instale o Docker."
        exit 1
    fi
    
    # Verificar se Docker está rodando
    if ! docker info &> /dev/null; then
        log_error "Docker não está rodando. Inicie o Docker."
        exit 1
    fi
    
    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "Credenciais AWS não configuradas ou inválidas."
        exit 1
    fi
    
    log_success "Pré-requisitos verificados com sucesso!"
}

# Função para fazer login no ECR
ecr_login() {
    log_info "Fazendo login no ECR..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI"
        return
    fi
    
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URI" || {
        log_error "Falha no login do ECR"
        exit 1
    }
    
    log_success "Login no ECR realizado com sucesso!"
}

# Função para build da imagem
build_image() {
    local commit_hash=$(get_commit_hash)
    local image_tag="$ECR_REPO:$commit_hash"
    
    log_info "Fazendo build da imagem: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] docker build -t $image_tag ."
        log_info "[DRY-RUN] docker tag $image_tag $ECR_URI/$image_tag"
        return
    fi
    
    # Build da imagem
    docker build -t "$image_tag" . || {
        log_error "Falha no build da imagem"
        exit 1
    }
    
    # Tag para ECR
    docker tag "$image_tag" "$ECR_URI/$image_tag" || {
        log_error "Falha ao criar tag para ECR"
        exit 1
    }
    
    log_success "Build da imagem concluído: $image_tag"
    echo "$commit_hash" > .last_build_tag
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
    
    log_info "Fazendo push da imagem: $full_image_uri"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] docker push $full_image_uri"
        return
    fi
    
    docker push "$full_image_uri" || {
        log_error "Falha no push da imagem"
        exit 1
    }
    
    log_success "Push da imagem concluído: $full_image_uri"
}

# Função para obter a task definition atual
get_current_task_definition() {
    aws ecs describe-task-definition \
        --task-definition "$TASK_FAMILY" \
        --region "$REGION" \
        --query 'taskDefinition' \
        --output json 2>/dev/null || echo "{}"
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
    
    log_info "Criando nova task definition com imagem: $image_uri"
    
    # Obter task definition atual
    local current_task_def=$(get_current_task_definition)
    
    if [ "$current_task_def" = "{}" ]; then
        log_error "Não foi possível obter a task definition atual. Certifique-se de que '$TASK_FAMILY' existe."
        exit 1
    fi
    
    # Criar nova task definition baseada na atual, mas com nova imagem
    local new_task_def=$(echo "$current_task_def" | jq --arg image "$image_uri" '
        .containerDefinitions[0].image = $image |
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
    ')
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Criaria nova task definition com imagem: $image_uri"
        return
    fi
    
    # Registrar nova task definition
    local result=$(aws ecs register-task-definition \
        --region "$REGION" \
        --cli-input-json "$new_task_def" \
        --query 'taskDefinition.{family:family,revision:revision}' \
        --output json)
    
    local family=$(echo "$result" | jq -r '.family')
    local revision=$(echo "$result" | jq -r '.revision')
    
    log_success "Nova task definition criada: $family:$revision"
    echo "$family:$revision"
}

# Função para atualizar o serviço
update_service() {
    local task_def="$1"
    
    if [ -z "$task_def" ]; then
        log_error "Task definition não fornecida"
        exit 1
    fi
    
    log_info "Atualizando serviço ECS: $SERVICE com task definition: $task_def"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $task_def --region $REGION"
        return
    fi
    
    aws ecs update-service \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --task-definition "$task_def" \
        --region "$REGION" \
        --output table || {
        log_error "Falha ao atualizar o serviço"
        exit 1
    }
    
    log_success "Serviço atualizado com sucesso!"
    
    # Aguardar estabilização
    log_info "Aguardando estabilização do serviço..."
    aws ecs wait services-stable \
        --cluster "$CLUSTER" \
        --services "$SERVICE" \
        --region "$REGION" || {
        log_warning "Timeout aguardando estabilização do serviço"
    }
    
    log_success "Deploy concluído com sucesso!"
}

# Função para listar versões disponíveis
list_versions() {
    log_info "Listando versões disponíveis no ECR..."
    
    aws ecr describe-images \
        --repository-name "$ECR_REPO" \
        --region "$REGION" \
        --query 'sort_by(imageDetails,&imagePushedAt)[*].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
        --output table 2>/dev/null || {
        log_error "Falha ao listar imagens do ECR"
        exit 1
    }
}

# Função para rollback
rollback() {
    local version="$1"
    
    if [ -z "$version" ]; then
        log_error "Versão para rollback não especificada. Use --version VERSION"
        exit 1
    fi
    
    log_info "Fazendo rollback para versão: $version"
    
    # Verificar se a imagem existe
    aws ecr describe-images \
        --repository-name "$ECR_REPO" \
        --image-ids imageTag="$version" \
        --region "$REGION" \
        --output table &>/dev/null || {
        log_error "Versão $version não encontrada no ECR"
        exit 1
    }
    
    # Definir tag customizada para usar na criação da task definition
    CUSTOM_TAG="$version"
    
    # Criar nova task definition com a versão anterior
    local task_def=$(create_task_definition)
    
    # Atualizar serviço
    update_service "$task_def"
    
    log_success "Rollback para versão $version concluído!"
}

# Função principal de deploy
deploy() {
    check_prerequisites
    
    # Obter informações da conta AWS
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
    
    log_info "Iniciando deploy..."
    log_info "Região: $REGION"
    log_info "Cluster: $CLUSTER"
    log_info "Serviço: $SERVICE"
    log_info "Task Family: $TASK_FAMILY"
    log_info "ECR Repository: $ECR_REPO"
    log_info "ECR URI: $ECR_URI"
    
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
        deploy|build|push|update-service|rollback|list-versions|help)
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Opção desconhecida: $1"
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
            log_error "Para update-service, especifique a tag com --tag"
            exit 1
        fi
        check_prerequisites
        account_id=$(aws sts get-caller-identity --query Account --output text)
        ECR_URI="$account_id.dkr.ecr.$REGION.amazonaws.com"
        task_def=$(create_task_definition)
        update_service "$task_def"
        ;;
    rollback)
        rollback "$ROLLBACK_VERSION"
        ;;
    list-versions)
        list_versions
        ;;
    *)
        log_error "Comando desconhecido: $COMMAND"
        exit 1
        ;;
esac
