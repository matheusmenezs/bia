# 🚀 Guia do Deploy Otimizado - Projeto BIA

## 📋 Visão Geral

O script `deploy-ecs-optimized.sh` é uma versão aprimorada do deploy original, focada em **logs limpos** e **alta disponibilidade garantida**. Este guia apresenta todas as funcionalidades e melhores práticas de uso.

## ✨ Principais Melhorias

### 🎯 **Problemas Resolvidos**
- ✅ **Logs grandes no terminal** → Sistema de logging limpo e organizado
- ✅ **Instabilidade durante deploy** → Alta disponibilidade com zero downtime
- ✅ **Falta de monitoramento** → Acompanhamento em tempo real
- ✅ **Health checks lentos** → Configurações otimizadas

### 🔧 **Novas Funcionalidades**
- 📊 Comando `status` para verificar estado do serviço
- 📝 Comando `logs` para visualizar histórico de deploys
- 🔍 Monitoramento em tempo real do deployment
- 🏥 Verificação automática de saúde pós-deploy
- 🔄 Rollback automático em caso de falha

## 🛠️ Instalação e Configuração

### Pré-requisitos
```bash
# Verificar se todos os requisitos estão instalados
aws --version
docker --version
jq --version
git --version
```

### Permissões do Script
```bash
chmod +x deploy-ecs-optimized.sh
```

## 📖 Comandos Disponíveis

### 🚀 **Deploy Completo**
```bash
# Deploy padrão com alta disponibilidade
./deploy-ecs-optimized.sh deploy

# Deploy com logs detalhados
./deploy-ecs-optimized.sh deploy --verbose

# Deploy em região específica
./deploy-ecs-optimized.sh deploy --region us-west-2

# Simulação (dry-run)
./deploy-ecs-optimized.sh deploy --dry-run
```

### 🔍 **Verificação de Status**
```bash
# Status completo do serviço
./deploy-ecs-optimized.sh status
```

**Exemplo de saída:**
```
=== STATUS DO SERVIÇO BIA ===
Serviço: service-bia-alb-teste
Status: ACTIVE
Task Definition: task-def-bia-alb:5
Tasks Desejadas: 2
Tasks Rodando: 2
Tasks Pendentes: 0

Deployments:
PRIMARY - COMPLETED - task-def-bia-alb:5

Eventos Recentes:
2025-08-04T10:30:15.000000+00:00 - (service service-bia-alb-teste) has reached a steady state.
```

### 📝 **Visualização de Logs**
```bash
# Ver logs do último deploy
./deploy-ecs-optimized.sh logs
```

### 🔄 **Rollback**
```bash
# Listar versões disponíveis
./deploy-ecs-optimized.sh list-versions

# Fazer rollback para versão específica
./deploy-ecs-optimized.sh rollback --version abc123f
```

### 🔨 **Comandos Individuais**
```bash
# Apenas build da imagem
./deploy-ecs-optimized.sh build

# Apenas push para ECR
./deploy-ecs-optimized.sh push

# Apenas atualizar serviço (requer --tag)
./deploy-ecs-optimized.sh update-service --tag abc123f
```

## ⚙️ Configurações de Alta Disponibilidade

### 🎯 **Deployment Configuration**
```yaml
maximumPercent: 200%        # Permite dobrar capacidade durante deploy
minimumHealthyPercent: 100% # Zero downtime garantido
```

### 🏥 **Health Checks Otimizados**
```yaml
HealthCheckIntervalSeconds: 15    # Verificação a cada 15s (era 30s)
HealthCheckTimeoutSeconds: 5      # Timeout de 5s
HealthyThresholdCount: 2          # 2 checks para considerar healthy (era 5)
UnhealthyThresholdCount: 2        # 2 checks para considerar unhealthy
HealthCheckPath: "/api/versao"    # Endpoint específico da BIA
```

### 📊 **Como Funciona o Zero Downtime**

**Cenário com 2 tasks rodando:**

1. **Estado Inicial**
   ```
   Task 1: RUNNING ✅
   Task 2: RUNNING ✅
   Total: 2/2 tasks healthy
   ```

2. **Durante Deploy**
   ```
   Task 1: RUNNING ✅ (antiga)
   Task 2: RUNNING ✅ (antiga)
   Task 3: STARTING 🔄 (nova)
   Task 4: STARTING 🔄 (nova)
   Total: 2/4 tasks healthy (100% mantido)
   ```

3. **Transição**
   ```
   Task 1: DRAINING 🔄 (antiga)
   Task 2: DRAINING 🔄 (antiga)
   Task 3: RUNNING ✅ (nova)
   Task 4: RUNNING ✅ (nova)
   Total: 2/4 tasks healthy
   ```

4. **Estado Final**
   ```
   Task 3: RUNNING ✅ (nova)
   Task 4: RUNNING ✅ (nova)
   Total: 2/2 tasks healthy
   ```

## 📋 Opções de Linha de Comando

### 🎛️ **Parâmetros Principais**
| Opção | Descrição | Padrão |
|-------|-----------|--------|
| `-r, --region` | Região AWS | `us-east-1` |
| `-c, --cluster` | Nome do cluster ECS | `cluster-bia-alb` |
| `-s, --service` | Nome do serviço ECS | `service-bia-alb-teste` |
| `-f, --family` | Família da task definition | `task-def-bia-alb` |
| `-e, --ecr-repo` | Nome do repositório ECR | `bia` |

### 🏷️ **Controle de Versão**
| Opção | Descrição | Uso |
|-------|-----------|-----|
| `-t, --tag` | Tag específica para usar | Deploy de versão específica |
| `-v, --version` | Versão para rollback | Comando rollback |

### 🔧 **Opções de Debug**
| Opção | Descrição | Comportamento |
|-------|-----------|---------------|
| `--verbose` | Logs detalhados | Mostra comandos executados |
| `--dry-run` | Simulação | Não executa comandos reais |

## 📊 Sistema de Logging

### 🎨 **Tipos de Log**
- 🔵 **INFO**: Informações gerais
- ✅ **SUCCESS**: Operações concluídas com sucesso
- ⚠️ **WARNING**: Avisos importantes
- ❌ **ERROR**: Erros que impedem continuação
- ➡️ **STEP**: Etapas do processo

### 📁 **Arquivos de Log**
```bash
# Logs são salvos automaticamente em:
/tmp/bia-deploy-YYYYMMDD-HHMMSS.log

# Exemplo:
/tmp/bia-deploy-20250804-103015.log
```

### 📖 **Exemplo de Log Limpo**
```
[10:30:15] → Verificando pré-requisitos...
[10:30:16] ✓ Todos os pré-requisitos verificados
[10:30:17] → Otimizando configurações para alta disponibilidade...
[10:30:18] ✓ Configurações já otimizadas para HA
[10:30:19] → Otimizando health checks...
[10:30:20] ✓ Health checks já otimizados
[10:30:21] → Autenticando no ECR...
[10:30:22] ✓ Login no ECR concluído
[10:30:23] → Construindo imagem: bia:abc123f
[10:30:45] ✓ Build da imagem Docker concluído
[10:30:46] ✓ Tag da imagem para ECR concluído
[10:30:46] ✓ Imagem construída: bia:abc123f
```

## 🚨 Troubleshooting

### ❌ **Problemas Comuns**

#### **1. Erro de Credenciais AWS**
```bash
[10:30:15] ✗ Credenciais AWS inválidas
```
**Solução:**
```bash
aws configure
# ou
export AWS_PROFILE=seu-profile
```

#### **2. Docker não está rodando**
```bash
[10:30:15] ✗ Docker não está rodando
```
**Solução:**
```bash
sudo systemctl start docker
# ou
sudo service docker start
```

#### **3. Task Definition não encontrada**
```bash
[10:30:25] ✗ Task definition 'task-def-bia-alb' não encontrada
```
**Solução:**
```bash
# Verificar se o nome está correto
aws ecs list-task-definitions --family-prefix task-def-bia
```

#### **4. Deployment falhou**
```bash
[10:35:30] ✗ Deployment falhou!
```
**Solução:**
```bash
# Verificar logs detalhados
./deploy-ecs-optimized.sh logs

# Fazer rollback se necessário
./deploy-ecs-optimized.sh rollback --version versao-anterior
```

### 🔍 **Debug Avançado**

#### **Verificar configuração atual:**
```bash
./deploy-ecs-optimized.sh status
```

#### **Deploy com logs detalhados:**
```bash
./deploy-ecs-optimized.sh deploy --verbose
```

#### **Simular deploy:**
```bash
./deploy-ecs-optimized.sh deploy --dry-run
```

## 📈 Monitoramento e Métricas

### 📊 **Durante o Deploy**
O script monitora automaticamente:
- Status do deployment
- Contagem de tasks (running/desired)
- Estado do rollout
- Health checks do ALB

### 🏥 **Verificação Pós-Deploy**
Após o deploy, o script:
1. Aguarda 30s para estabilização
2. Testa endpoint `/api/versao`
3. Confirma resposta HTTP 200
4. Reporta status da aplicação

### ⏱️ **Timeouts**
- **Monitoramento de deployment**: 10 minutos
- **Health check pós-deploy**: 30 segundos
- **Estabilização do serviço**: Automático via AWS

## 🔄 Fluxo de Rollback

### 📋 **Processo Automático**
1. **Detecção de falha** durante deployment
2. **Parada do deployment** atual
3. **Criação de task definition** com versão anterior
4. **Atualização do serviço** para versão estável
5. **Verificação** de que rollback foi bem-sucedido

### 🎯 **Rollback Manual**
```bash
# 1. Listar versões disponíveis
./deploy-ecs-optimized.sh list-versions

# 2. Escolher versão para rollback
./deploy-ecs-optimized.sh rollback --version abc123f

# 3. Verificar status
./deploy-ecs-optimized.sh status
```

## 🎯 Melhores Práticas

### ✅ **Antes do Deploy**
1. **Testar localmente** com Docker Compose
2. **Verificar health check** da aplicação (`/api/versao`)
3. **Confirmar configurações** do ambiente
4. **Fazer backup** da versão atual (automático)

### ✅ **Durante o Deploy**
1. **Monitorar logs** em tempo real
2. **Não interromper** o processo
3. **Aguardar confirmação** de sucesso
4. **Verificar aplicação** após deploy

### ✅ **Após o Deploy**
1. **Testar funcionalidades** críticas
2. **Monitorar métricas** por alguns minutos
3. **Verificar logs** da aplicação
4. **Documentar** mudanças realizadas

### ❌ **O que NÃO fazer**
- ❌ Interromper deploy em andamento
- ❌ Fazer múltiplos deploys simultâneos
- ❌ Ignorar avisos de health check
- ❌ Pular verificação pós-deploy

## 📞 Suporte e Ajuda

### 🆘 **Comandos de Ajuda**
```bash
# Ajuda completa
./deploy-ecs-optimized.sh help

# Ajuda específica
./deploy-ecs-optimized.sh --help
```

### 📋 **Informações de Debug**
```bash
# Status detalhado
./deploy-ecs-optimized.sh status

# Logs completos
./deploy-ecs-optimized.sh logs

# Versões disponíveis
./deploy-ecs-optimized.sh list-versions
```

### 🔗 **Recursos Úteis**
- **Logs da aplicação**: CloudWatch Logs
- **Métricas do ECS**: CloudWatch Metrics
- **Status do ALB**: Console AWS ELB
- **Health checks**: Target Group Health

---

## 📝 Changelog

### Versão 2.0 (Otimizada)
- ✅ Sistema de logging limpo
- ✅ Alta disponibilidade garantida
- ✅ Monitoramento em tempo real
- ✅ Health checks otimizados
- ✅ Rollback automático
- ✅ Verificação pós-deploy

### Versão 1.0 (Original)
- ✅ Deploy básico para ECS
- ✅ Build e push de imagens
- ✅ Criação de task definitions

---

**🎯 Resultado:** Deploy seguro, confiável e com zero downtime para o Projeto BIA!
