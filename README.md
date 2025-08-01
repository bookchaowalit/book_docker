# Centralized Docker Infrastructure

A comprehensive, centralized Docker infrastructure setup with shared databases, automated management, and standardized deployment patterns.

## 🚀 Quick Start

```bash
# Start all services with centralized infrastructure
./docker-manager.sh start-all

# Check status
./docker-manager.sh status

# Access Traefik dashboard
open http://localhost:8090
```

## 📊 Current Infrastructure

### ✅ **22+ Applications Running**
- **Baserow**, **NocoDB**, **WordPress**, **Ghost**, **Metabase**
- **Jupyter Hub**, **VS Code Server**, **Rocket.Chat**, **Vikunja**
- **GitLab**, **Jenkins**, **Portainer**, **Airflow**, and more...

### 🗄️ **Centralized Databases**
- **PostgreSQL**: `localhost:5432` (shared by 10+ applications)
- **MySQL**: `localhost:3306` (shared by WordPress, Ghost, etc.)
- **Redis**: `localhost:6379` (shared caching)
- **MongoDB**: `localhost:27017` (shared document storage)

### 🌐 **Unified Access**
- **Traefik Dashboard**: http://localhost:8090
- **Applications**: http://[service].localhost:8080
- **Automatic SSL** and **Load Balancing**

## 📚 Documentation

### For Application Integration
- **[📖 Integration Guide](docs/centralized-infrastructure-guide.md)** - Complete guide for integrating new applications
- **[⚡ Quick Reference](docs/quick-integration-reference.md)** - Essential configuration and commands
- **[💡 Examples](docs/integration-examples.md)** - Practical examples for different tech stacks

### For Infrastructure Management
- **[🏗️ Architecture Overview](docs/README.md)** - Complete documentation index
- **[🔧 Management Commands](#management-commands)** - Daily operations guide

## 🎯 Key Features

### 🏗️ **Centralized Infrastructure**
- **Shared Databases**: One PostgreSQL, MySQL, Redis, MongoDB for all apps
- **Unified Proxy**: Single Traefik instance handling all routing
- **Automated Management**: Smart startup, health checks, and cleanup

### 🧹 **Intelligent Resource Management**
- **Automatic Cleanup**: Removes unused images, containers, networks
- **Scheduled Maintenance**: Daily and weekly cleanup jobs
- **Space Optimization**: Reduced from 59.5GB to 33.35GB (26GB saved!)

### 🔧 **Developer Experience**
- **Quick Integration**: Standard patterns for all technologies
- **Consistent Configuration**: Same database hosts across all apps
- **Easy Debugging**: Centralized logging and monitoring

## 🛠️ Management Commands

### Daily Operations
```bash
# Start everything (includes automatic cleanup)
./docker-manager.sh start-all

# Check comprehensive status
./docker-manager.sh status

# Monitor resource usage
./docker-manager.sh disk-usage
```

### Infrastructure Management
```bash
# Start only centralized infrastructure
./docker-manager.sh infra-start

# Stop all services
./docker-manager.sh stop-all

# Fix common issues
./docker-manager.sh fix-issues
```

### Cleanup and Maintenance
```bash
# Safe cleanup (removes unused resources)
./docker-manager.sh cleanup

# Aggressive cleanup (maximum space recovery)
./docker-manager.sh cleanup-aggressive

# Setup automatic daily/weekly cleanup
./docker-manager.sh setup-auto-cleanup

# View cleanup statistics
./docker-manager.sh cleanup-stats
```

## 🌐 Application Access

All applications are accessible through the centralized Traefik proxy:

| Application | URL | Database |
|-------------|-----|----------|
| **Baserow** | http://baserow.localhost:8080 | PostgreSQL |
| **NocoDB** | http://nocodb.localhost:8080 | PostgreSQL |
| **WordPress** | http://wordpress.localhost:8080 | MySQL |
| **Ghost** | http://ghost.localhost:8080 | MySQL |
| **Metabase** | http://metabase.localhost:8080 | PostgreSQL |
| **Jupyter Hub** | http://jupyterhub.localhost:8080 | PostgreSQL |
| **VS Code Server** | http://vscode-server.localhost:8080 | - |
| **Rocket.Chat** | http://rocketchat.localhost:8080 | MongoDB |
| **GitLab** | http://gitlab.localhost:8080 | PostgreSQL |
| **Jenkins** | http://jenkins.localhost:8080 | - |
| **Portainer** | http://portainer.localhost:9000 | - |
| **Traefik Dashboard** | http://localhost:8090 | - |

## 🔧 Integration for New Applications

### 1. Quick Setup
```yaml
# docker-compose.yml
version: '3.8'
services:
  your-app:
    image: your-app:latest
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: your_app_db
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`)"
      - "traefik.http.routers.your-app.entrypoints=web"
      - "traefik.http.services.your-app.loadbalancer.server.port=3000"
    networks:
      - shared-networks

networks:
  shared-networks:
    external: true
```

### 2. Deploy
```bash
# Ensure infrastructure is running
./docker-manager.sh infra-status

# Deploy your application
docker-compose up -d

# Verify access
curl http://your-app.localhost:8080
```

## 📊 Resource Optimization

### Before Centralization
- **75 Docker images** (59.5GB)
- **Multiple database instances** per application
- **44% reclaimable space**
- **Manual resource management**

### After Centralization
- **36 Docker images** (33.35GB) - **26GB saved!**
- **4 shared database instances** for all applications
- **0.8% reclaimable space**
- **Automated cleanup and maintenance**

## 🔍 Troubleshooting

### Common Issues
```bash
# Infrastructure not running
./docker-manager.sh infra-start

# Application not accessible
curl http://localhost:8090/api/rawdata | grep your-app

# Database connection issues
docker exec your-app-container ping postgres

# Resource issues
./docker-manager.sh disk-usage
./docker-manager.sh cleanup
```

### Health Checks
```bash
# Check all services
./docker-manager.sh status

# Check specific service
./docker-manager.sh logs <service-name>

# Check infrastructure health
./docker-manager.sh infra-status
```

## 🏗️ Architecture Benefits

### Resource Efficiency
- **26GB disk space saved** through intelligent cleanup
- **Shared databases** eliminate duplication
- **Automated maintenance** prevents resource accumulation

### Operational Excellence
- **Single point of management** for all infrastructure
- **Standardized deployment patterns** across all applications
- **Automated health monitoring** and recovery

### Developer Experience
- **Quick integration** with standard patterns
- **Consistent configuration** across all environments
- **Easy debugging** with centralized logging

## 📈 Monitoring and Maintenance

### Automatic Maintenance
- **Daily cleanup** (2:00 AM): Safe removal of unused resources
- **Weekly deep cleanup** (Sunday 3:00 AM): Comprehensive optimization
- **Continuous monitoring** of resource usage and health

### Manual Monitoring
```bash
# Resource usage analysis
./docker-manager.sh disk-usage

# Cleanup statistics
./docker-manager.sh cleanup-stats

# Infrastructure health
./docker-manager.sh status
```

## 🚀 Getting Started

1. **For New Users**: Start with [Quick Reference](docs/quick-integration-reference.md)
2. **For Integration**: Read [Integration Guide](docs/centralized-infrastructure-guide.md)
3. **For Examples**: Check [Integration Examples](docs/integration-examples.md)
4. **For Management**: Use the commands above

## 🎯 Next Steps

- **Add your application** using the integration guides
- **Setup automatic cleanup** with `./docker-manager.sh setup-auto-cleanup`
- **Monitor resources** regularly with `./docker-manager.sh disk-usage`
- **Explore applications** at http://localhost:8090

---

**💡 Pro Tip**: The system automatically performs cleanup on startup, so `./docker-manager.sh start-all` is the recommended way to start your infrastructure!