# HashiCorp Vault Secret Management

This setup provides centralized secret management for all Docker and Kubernetes services using HashiCorp Vault.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Docker Compose │    │  HashiCorp Vault │    │   Kubernetes    │
│   Services       │◄──►│  (vault.localhost│◄──►│   Secrets       │
│                 │    │   Port: 8200)    │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 1. Start Vault
```bash
cd /home/bookchaowalit/book/book_docker/vault
docker-compose up -d
```

### 2. Initialize with secrets
```bash
./vault-manager.sh init
```

### 3. Update environment files
```bash
./vault-manager.sh update-env
```

### 4. Sync to Kubernetes
```bash
./vault-manager.sh sync-k8s
```

## 📋 Available Commands

### Main Management Script
```bash
./vault-manager.sh [command]
```

**Commands:**
- `init` - Initialize Vault with all secrets
- `status` - Show Vault status and list secrets
- `get <service>` - Get secrets for specific service
- `update-env` - Update all .env files with Vault secrets
- `sync-k8s` - Sync secrets to Kubernetes
- `backup` - Backup all secrets to JSON file
- `add-secret` - Add new secret interactively

### Individual Scripts
- `./init-vault.sh` - Initialize Vault with secrets
- `./get-secrets.sh <service>` - Get secrets for service
- `./update-env-files.sh` - Update .env files
- `./sync-k8s-secrets.sh` - Sync to Kubernetes

## 🗂️ Secret Organization

### Database Secrets
```
secret/database/postgres
├── username
├── password
├── host
├── port
└── database

secret/database/mysql
├── root_password
├── username
├── password
├── host
└── port

secret/database/mariadb
├── root_password
├── username
├── password
├── host
└── port
```

### Application Secrets
```
secret/app/n8n
├── encryption_key
├── secure_cookie
└── host

secret/app/twenty
├── app_secret
├── server_url
└── storage_type

secret/app/open-webui
└── openai_api_key
```

### Kubernetes Secrets
```
secret/k8s/grafana
├── admin_user
└── admin_password
```

## 🔐 Access Information

- **Vault UI**: http://vault.localhost
- **Root Token**: `myroot`
- **API Endpoint**: http://vault.localhost:8200

## 🔄 Workflow

### Adding New Service
1. Add secrets to Vault:
   ```bash
   vault kv put secret/app/myservice key1=value1 key2=value2
   ```

2. Update `get-secrets.sh` to include your service

3. Update `update-env-files.sh` to generate .env for your service

4. Update your docker-compose.yml to use the new .env

### Rotating Secrets
1. Update secret in Vault:
   ```bash
   vault kv put secret/app/myservice key1=newvalue1
   ```

2. Update environment files:
   ```bash
   ./vault-manager.sh update-env
   ```

3. Restart affected services:
   ```bash
   ./docker-compose-manager.sh down myservice
   ./docker-compose-manager.sh up myservice
   ```

## 🛡️ Security Features

### Policies
- **docker-policy**: Read access to database and app secrets
- **k8s-policy**: Read access to k8s and database secrets

### Access Control
```bash
# View policies
vault policy list

# Read policy
vault policy read docker-policy
```

### Audit Logging
All secret access is logged by Vault for security auditing.

## 📊 Current Services Using Vault

### Docker Services
- ✅ Twenty CRM
- ✅ N8N
- ✅ Open WebUI
- ✅ PostgreSQL
- ✅ MySQL
- ✅ MariaDB

### Kubernetes Services
- ✅ Grafana
- 🔄 Database connections (via secrets)

## 🔧 Troubleshooting

### Vault Not Accessible
```bash
# Check if Vault is running
docker ps | grep vault

# Check logs
docker logs vault_server

# Restart Vault
cd /home/bookchaowalit/book/book_docker/vault
docker-compose restart
```

### Environment Files Not Updating
```bash
# Check Vault connectivity
curl http://vault.localhost/v1/sys/health

# Manually regenerate
./vault-manager.sh update-env
```

### Kubernetes Secrets Not Syncing
```bash
# Check kubectl connectivity
kubectl get nodes

# Check namespaces
kubectl get namespaces

# Manually sync
./vault-manager.sh sync-k8s
```

## 📈 Monitoring

### Vault Health Check
```bash
./vault-manager.sh status
```

### Secret Usage Audit
```bash
# List all secrets
vault kv list secret/

# Get specific secret details
vault kv get secret/app/myservice
```

## 🚧 Future Enhancements

- [ ] Automatic secret rotation
- [ ] Vault Agent for dynamic secret injection
- [ ] Integration with CI/CD pipelines
- [ ] Encrypted storage backend
- [ ] High availability setup
- [ ] Integration with external identity providers

## 📝 Backup & Recovery

### Manual Backup
```bash
./vault-manager.sh backup
```

### Restore from Backup
```bash
# Coming soon
./vault-manager.sh restore backup-file.json
```

## 🤝 Contributing

When adding new services or secrets:

1. Update the initialization script (`init-vault.sh`)
2. Add to the secrets retrieval script (`get-secrets.sh`)
3. Update the environment file generator (`update-env-files.sh`)
4. Update this documentation

---

**🔒 Remember**: Never commit actual secrets to git. Use Vault for all sensitive data!
