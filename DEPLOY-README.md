# Script de Deploy ECS - Projeto BIA

Este script automatiza o processo completo de deploy para ECS, incluindo versionamento baseado em commit hash e funcionalidade de rollback.

## 🚀 Funcionalidades

- **Build automatizado** com tag baseada no commit hash (7 caracteres)
- **Push para ECR** com autenticação automática
- **Criação de task definitions** versionadas
- **Deploy no ECS** com aguardo de estabilização
- **Rollback** para versões anteriores
- **Listagem de versões** disponíveis
- **Dry-run** para simulação
- **Logs coloridos** para melhor visualização

## 📋 Pré-requisitos

1. **AWS CLI** configurado com credenciais válidas
2. **Docker** instalado e rodando
3. **Git** (para obter commit hash)
4. **jq** instalado (para manipulação JSON)
5. **Repositório ECR** já criado
6. **Cluster e serviço ECS** já configurados

### Instalação do jq (se necessário)
```bash
# Ubuntu/Debian
sudo apt-get install jq

# Amazon Linux/CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

## 🛠️ Configuração

### Opção 1: Usar configurações padrão
O script usa as configurações baseadas nas regras de infraestrutura do projeto BIA:
- Cluster: `bia-cluster-alb`
- Service: `bia-service`
- Task Family: `bia-tf`
- ECR Repository: `bia`
- Region: `us-east-1`

### Opção 2: Usar arquivo de configuração
```bash
# Copiar arquivo de exemplo
cp .deploy-config.example .deploy-config

# Editar configurações
nano .deploy-config

# Carregar configurações
source .deploy-config
```

### Opção 3: Usar parâmetros na linha de comando
```bash
./deploy-ecs.sh deploy --region us-west-2 --cluster meu-cluster
```

## 📖 Uso Básico

### Deploy Completo
```bash
# Deploy com configurações padrão
./deploy-ecs.sh deploy

# Deploy com dry-run (simulação)
./deploy-ecs.sh deploy --dry-run

# Deploy em região específica
./deploy-ecs.sh deploy --region us-west-2
```

### Comandos Individuais
```bash
# Apenas build da imagem
./deploy-ecs.sh build

# Apenas push (após build)
./deploy-ecs.sh push

# Apenas atualizar serviço com tag específica
./deploy-ecs.sh update-service --tag abc123f
```

### Rollback
```bash
# Listar versões disponíveis
./deploy-ecs.sh list-versions

# Fazer rollback para versão específica
./deploy-ecs.sh rollback --version abc123f
```

### Ajuda
```bash
# Exibir help completo
./deploy-ecs.sh help
```

## 🏷️ Sistema de Versionamento

### Tags Automáticas
- As imagens são tagueadas automaticamente com os **últimos 7 caracteres** do commit hash
- Exemplo: `bia:abc123f`

### Tags Customizadas
```bash
# Usar tag específica
./deploy-ecs.sh deploy --tag minha-versao-1.0
```

### Estrutura no ECR
```
bia:abc123f  <- commit hash
bia:def456a  <- commit anterior
bia:ghi789b  <- commit mais antigo
```

## 🔄 Processo de Deploy

1. **Verificação de pré-requisitos**
2. **Login no ECR**
3. **Build da imagem Docker** com tag do commit
4. **Push para ECR**
5. **Criação de nova task definition** apontando para a nova imagem
6. **Atualização do serviço ECS**
7. **Aguardo de estabilização**

## 🔙 Processo de Rollback

1. **Verificação se a versão existe** no ECR
2. **Criação de nova task definition** apontando para a versão anterior
3. **Atualização do serviço ECS**
4. **Aguardo de estabilização**

## 📊 Exemplos de Output

### Deploy Bem-sucedido
```
[INFO] Verificando pré-requisitos...
[SUCCESS] Pré-requisitos verificados com sucesso!
[INFO] Fazendo login no ECR...
[SUCCESS] Login no ECR realizado com sucesso!
[INFO] Fazendo build da imagem: bia:abc123f
[SUCCESS] Build da imagem concluído: bia:abc123f
[INFO] Fazendo push da imagem: 123456789.dkr.ecr.us-east-1.amazonaws.com/bia:abc123f
[SUCCESS] Push da imagem concluído
[INFO] Criando nova task definition com imagem: 123456789.dkr.ecr.us-east-1.amazonaws.com/bia:abc123f
[SUCCESS] Nova task definition criada: bia-tf:15
[INFO] Atualizando serviço ECS: bia-service
[SUCCESS] Serviço atualizado com sucesso!
[INFO] Aguardando estabilização do serviço...
[SUCCESS] Deploy concluído com sucesso!
```

### Listagem de Versões
```
[INFO] Listando versões disponíveis no ECR...
|    Tag    |         Pushed          |    Size    |
|-----------|-------------------------|------------|
| abc123f   | 2024-08-03T20:30:00Z   | 157834567  |
| def456a   | 2024-08-03T18:15:00Z   | 157834234  |
| ghi789b   | 2024-08-03T16:45:00Z   | 157833891  |
```

## 🚨 Troubleshooting

### Erro: "Docker não está rodando"
```bash
# Iniciar Docker
sudo systemctl start docker

# Verificar status
docker info
```

### Erro: "Credenciais AWS não configuradas"
```bash
# Configurar AWS CLI
aws configure

# Ou usar profile específico
export AWS_PROFILE=meu-profile
```

### Erro: "Não foi possível obter o commit hash"
```bash
# Verificar se está em repositório git
git status

# Ou usar tag customizada
./deploy-ecs.sh deploy --tag minha-tag
```

### Erro: "Task definition não encontrada"
```bash
# Verificar se a task definition existe
aws ecs describe-task-definition --task-definition bia-tf

# Criar task definition inicial se necessário
```

## 🔧 Personalização

### Modificar Configurações Padrão
Edite as variáveis no início do script:
```bash
DEFAULT_CLUSTER="meu-cluster"
DEFAULT_SERVICE="meu-service"
DEFAULT_TASK_FAMILY="minha-tf"
```

### Adicionar Validações Customizadas
Modifique a função `check_prerequisites()` para incluir suas validações específicas.

### Personalizar Logs
Modifique as funções `log_*()` para alterar cores ou formato dos logs.

## 📝 Logs e Debugging

### Arquivo de Log da Última Build
O script cria um arquivo `.last_build_tag` com a tag da última build realizada.

### Dry-run para Debugging
Use `--dry-run` para ver exatamente quais comandos seriam executados:
```bash
./deploy-ecs.sh deploy --dry-run
```

### Verbose AWS CLI
Para mais detalhes dos comandos AWS, adicione `--debug` aos comandos aws no script.

## 🔒 Segurança

- O script não armazena credenciais AWS
- Usa autenticação temporária do ECR
- Valida permissões antes de executar ações
- Suporta AWS profiles para isolamento de ambientes

## 🤝 Contribuição

Para melhorias no script:
1. Teste em ambiente de desenvolvimento
2. Documente mudanças
3. Mantenha compatibilidade com as regras de infraestrutura do projeto BIA
