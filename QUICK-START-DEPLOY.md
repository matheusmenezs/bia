# 🚀 Guia Rápido - Deploy ECS

## Comandos Essenciais

### 1. Deploy Completo
```bash
./deploy-ecs.sh deploy
```

### 2. Testar Antes de Executar
```bash
./deploy-ecs.sh deploy --dry-run
```

### 3. Ver Versões Disponíveis
```bash
./deploy-ecs.sh list-versions
```

### 4. Fazer Rollback
```bash
# Primeiro, veja as versões disponíveis
./deploy-ecs.sh list-versions

# Depois, faça rollback para uma versão específica
./deploy-ecs.sh rollback --version abc123f
```

### 5. Ver Ajuda Completa
```bash
./deploy-ecs.sh help
```

## ⚡ Fluxo Típico de Uso

1. **Fazer mudanças no código**
2. **Commit das mudanças**
   ```bash
   git add .
   git commit -m "Nova funcionalidade"
   ```
3. **Testar deploy (opcional)**
   ```bash
   ./deploy-ecs.sh deploy --dry-run
   ```
4. **Executar deploy**
   ```bash
   ./deploy-ecs.sh deploy
   ```
5. **Se algo der errado, fazer rollback**
   ```bash
   ./deploy-ecs.sh rollback --version VERSAO_ANTERIOR
   ```

## 🏷️ Como Funcionam as Tags

- **Automática**: Usa os últimos 7 caracteres do commit hash
  - Exemplo: commit `dbcf5ba1234567` → tag `dbcf5ba`
- **Manual**: Especifique uma tag customizada
  ```bash
  ./deploy-ecs.sh deploy --tag v1.0.0
  ```

## 🔧 Configurações Padrão

O script usa as configurações do projeto BIA:
- **Cluster**: `bia-cluster-alb`
- **Service**: `bia-service`
- **Task Family**: `bia-tf`
- **ECR Repo**: `bia`
- **Region**: `us-east-1`

## ⚠️ Antes do Primeiro Uso

1. Certifique-se de que o repositório ECR existe
2. Certifique-se de que o cluster e serviço ECS existem
3. Tenha uma task definition inicial criada
4. Configure suas credenciais AWS

## 🆘 Problemas Comuns

### "Task definition não encontrada"
Você precisa ter uma task definition inicial. Use o MCP ECS Server para criar a infraestrutura primeiro.

### "Docker não está rodando"
```bash
sudo systemctl start docker
```

### "Credenciais AWS inválidas"
```bash
aws configure
```

## 📞 Suporte

Para mais detalhes, consulte:
- `./deploy-ecs.sh help` - Ajuda completa
- `DEPLOY-README.md` - Documentação detalhada
