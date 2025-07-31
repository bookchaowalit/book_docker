# 🐳 Docker Services Manager

A comprehensive system for managing multiple Docker services with proper dependencies and ordering.

## 🚀 Quick Start

### Start All Services
```bash
./docker-manager.sh start-all
```

### Stop All Services
```bash
./docker-manager.sh stop-all
```

### Restart All Services
```bash
./docker-manager.sh restart-all
```

### Check Status
```bash
./docker-manager.sh status
```

## 📋 Available Services

### Infrastructure
- **Traefik**: Reverse proxy and load balancer
- **Portainer**: Docker container management UI

### Databases
- **PostgreSQL**: Main relational database (with pgvector)
- **MySQL**: Alternative database
- **MariaDB**: MySQL-compatible database

### Monitoring
- **Elasticsearch**: Search and analytics engine
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards

### Storage
- **MinIO**: S3-compatible object storage

### Applications
- **Baserow**: No-code database platform
- **NocoDB**: No-code database platform
- **N8N**: Workflow automation
- **Twenty**: CRM system
- **Open WebUI**: AI chat interface
- **ComfyUI**: AI image generation
- **WordPress**: Content management
- **And many more...**

## 🎯 Service Management

### Start Specific Services
```bash
./docker-manager.sh up postgres grafana
./docker-manager.sh up traefik
```

### Stop Specific Services
```bash
./docker-manager.sh down postgres
./docker-manager.sh down grafana prometheus
```

### Start by Category
```bash
./docker-manager.sh category databases up      # Start all databases
./docker-manager.sh category monitoring up     # Start monitoring stack
./docker-manager.sh category applications up   # Start all applications
```

### View Logs
```bash
./docker-manager.sh logs postgres
./docker-manager.sh logs grafana
```

## 🔧 Service Categories

Services are organized in categories and started in proper dependency order:

1. **Infrastructure** → Load balancers, management tools
2. **Databases** → Data storage services
3. **Monitoring** → Observability stack
4. **Storage** → File and object storage
5. **Applications** → Business applications
6. **Utilities** → Helper services

## 🌐 Service Access

After starting services, access them through Traefik at:

- **Grafana**: http://grafana.localhost
- **Prometheus**: http://prometheus.localhost
- **BaseRow**: http://baserow.localhost
- **NocoDB**: http://nocodb.localhost
- **N8N**: http://n8n.localhost
- **Twenty**: http://twenty.localhost
- **Open WebUI**: http://openwebui.localhost
- **ComfyUI**: http://comfyui.localhost
- **Vault**: http://vault.localhost
- **Portainer**: http://portainer.localhost:9000

## 🔐 Vault Integration

The system integrates with HashiCorp Vault for secret management:

```bash
# Start Vault first
./docker-manager.sh up vault

# Initialize Vault with secrets
cd docker/vault && ./init-vault.sh

# Update environment files with Vault secrets
cd docker/vault && ./update-env-files.sh
```

## 📊 Monitoring Your Services

```bash
# Check what's running
./docker-manager.sh ps

# View service status
./docker-manager.sh status

# Clean up unused resources
./docker-manager.sh clean
```

## 🛠️ Troubleshooting

### Service Won't Start
1. Check logs: `./docker-manager.sh logs [service]`
2. Verify dependencies are running
3. Check port conflicts
4. Ensure environment variables are set

### Port Conflicts
- PostgreSQL: 5432
- MySQL: 3306
- MariaDB: 3307
- Traefik: 80, 443
- Portainer: 9000

### Reset Everything
```bash
./docker-manager.sh stop-all
docker system prune -a
./docker-manager.sh start-all
```

## 📝 Configuration

- Main services config: `docker/docker-compose-manager.sh`
- Individual service configs: `docker/[service]/docker-compose.yml`
- Environment variables: `docker/[service]/.env`
- Vault secrets: `docker/vault/`

---

**💡 Pro Tip**: Use `./docker-manager.sh` without arguments to see the help menu!
