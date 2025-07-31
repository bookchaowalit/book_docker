# 🏗️ Infrastructure Services

This directory contains core infrastructure services that provide the foundation for your Docker ecosystem. These services handle networking, service discovery, CI/CD, message queuing, and other essential infrastructure components.

## 📋 Available Infrastructure Services

### 🌐 **Networking & Proxy**
- **Traefik** (`traefik`) - Modern reverse proxy and load balancer with automatic service discovery
- **NGINX** (`nginx`) - High-performance web server and reverse proxy with custom configurations

### 🔍 **Service Discovery & Configuration**
- **Consul** (`consul`) - Service discovery, health checking, and key-value configuration store
- **Vault** (`vault`) - Secrets management and encryption services

### 📊 **Container Management**
- **Portainer** (`portainer`) - Docker container management with web UI
- **Airflow** (`airflow`) - Workflow orchestration and data pipeline management

### 🚀 **CI/CD & Version Control**
- **GitLab CE** (`gitlab`) - Complete DevOps platform with Git repository, CI/CD, and container registry
- **GitLab Runner** (`gitlab-runner`) - CI/CD runner for GitLab pipelines
- **Jenkins** (`jenkins`) - Automation server for continuous integration and deployment

### 📨 **Message Brokers & Event Streaming**
- **RabbitMQ** (`rabbitmq`) - Message broker with management UI for reliable message delivery
- **Apache Kafka** (`kafka`) - Distributed event streaming platform with Kafka UI and Zookeeper

## 🚀 Quick Start

### Start All Infrastructure Services
```bash
./docker-manager.sh category infrastructure up
```

### Start Essential Infrastructure Only
```bash
./docker-manager.sh up traefik portainer vault consul
```

### Start CI/CD Stack
```bash
./docker-manager.sh up gitlab gitlab-runner jenkins
```

### Start Message Brokers
```bash
./docker-manager.sh up rabbitmq kafka
```

## 🌐 Service Access Points

### Web Interfaces
- **Traefik Dashboard**: http://localhost:8090
- **Portainer**: http://portainer.localhost:9000
- **Consul UI**: http://consul.localhost
- **Vault UI**: http://vault.localhost
- **NGINX**: http://nginx.localhost
- **GitLab**: http://gitlab.localhost
- **Jenkins**: http://jenkins.localhost
- **RabbitMQ Management**: http://rabbitmq.localhost
- **Kafka UI**: http://kafka.localhost

### Service Endpoints

#### Traefik
- **Dashboard**: http://localhost:8090
- **HTTP**: Port 80
- **HTTPS**: Port 443

#### Consul
- **HTTP API**: http://localhost:8500
- **DNS**: Port 8600

#### Vault
- **HTTP API**: http://localhost:8200
- **Token**: `myroot` (development only!)

#### GitLab
- **Web**: http://gitlab.localhost
- **SSH**: Port 2222
- **Registry**: http://registry.localhost
- **Root Password**: `gitlab123`

#### Jenkins
- **Web**: http://jenkins.localhost
- **Agent Port**: 50000

#### RabbitMQ
- **AMQP**: Port 5672
- **Management**: Port 15672
- **Credentials**: admin/admin123

#### Kafka
- **Broker**: Port 9092
- **UI**: http://kafka.localhost

## 🔧 Service-Specific Features

### Traefik
- **Automatic SSL** with Let's Encrypt
- **Service discovery** from Docker labels
- **Load balancing** and failover
- **Rate limiting** and middleware support

### Consul
- **Service registration** and health checks
- **Key-value store** for configuration
- **Service mesh** connectivity
- **Multi-datacenter** support

### Vault
- **Secret storage** with encryption at rest
- **Dynamic secrets** generation
- **Authentication** backends (LDAP, JWT, etc.)
- **Audit logging** for compliance

### GitLab CE
- **Git repository** management
- **CI/CD pipelines** with YAML configuration
- **Container registry** for Docker images
- **Issue tracking** and project management
- **Wiki and documentation**

### Jenkins
- **Pipeline as Code** with Jenkinsfile
- **Plugin ecosystem** (1800+ plugins)
- **Distributed builds** with agents
- **Integration** with version control systems

### RabbitMQ
- **AMQP 0.9.1** protocol support
- **Message persistence** and clustering
- **Management UI** for monitoring
- **Plugin system** for extensions

### Kafka
- **High-throughput** message streaming
- **Distributed architecture** with partitioning
- **Consumer groups** for scalability
- **Stream processing** capabilities

## 🔐 Security Configuration

### Default Credentials (Change for Production!)

#### GitLab
- **Root User**: `root`
- **Password**: `gitlab123`

#### Jenkins
- **Admin User**: `admin`
- **Password**: `jenkins123`

#### RabbitMQ
- **User**: `admin`
- **Password**: `admin123`

#### Vault
- **Root Token**: `myroot` (development mode)

### Security Best Practices
1. **Change default passwords** before production use
2. **Enable HTTPS** with proper SSL certificates
3. **Configure authentication** backends (LDAP, OIDC)
4. **Set up network policies** to restrict access
5. **Enable audit logging** for compliance
6. **Regular updates** of container images

## 📊 Monitoring Integration

### Health Checks
All services include comprehensive health checks:
- **HTTP endpoints** for service availability
- **Custom scripts** for service-specific checks
- **Dependency checks** for service readiness

### Metrics Collection
Services expose metrics for monitoring:
- **Traefik**: Built-in Prometheus metrics
- **Consul**: Telemetry and health metrics
- **GitLab**: Performance and usage metrics
- **Jenkins**: Build and system metrics
- **RabbitMQ**: Queue and connection metrics
- **Kafka**: Broker and topic metrics

## 🔄 Service Dependencies

### Startup Order
1. **Core Infrastructure**: Traefik, Consul, Vault
2. **Container Management**: Portainer
3. **CI/CD**: GitLab → GitLab Runner, Jenkins
4. **Message Brokers**: RabbitMQ, Kafka (Zookeeper first)
5. **Applications**: Dependent services

### Network Dependencies
- All services connect to `shared-networks`
- **Traefik** manages external access
- **Consul** provides service discovery
- **Vault** provides secrets to other services

## 💾 Data Persistence

### Volume Management
Each service uses named volumes for persistence:
- **Configuration files** and settings
- **Application data** and logs
- **SSL certificates** and keys
- **Build artifacts** and repositories

### Backup Strategy
```bash
# GitLab backup
docker exec gitlab_container gitlab-backup create

# Jenkins backup
docker exec jenkins_container tar -czf /backup/jenkins-backup.tar.gz /var/jenkins_home

# Consul backup
docker exec consul_container consul snapshot save /consul/data/backup.snap
```

## 🛠️ Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check port usage
./docker-manager.sh fix-ports

# View service status
./docker-manager.sh status
```

#### Service Dependencies
```bash
# Start in proper order
./docker-manager.sh up traefik
./docker-manager.sh up consul vault
./docker-manager.sh up gitlab
```

#### GitLab Issues
```bash
# Check GitLab logs
./docker-manager.sh logs gitlab

# Reconfigure GitLab
docker exec gitlab_container gitlab-ctl reconfigure
```

#### Jenkins Plugin Issues
```bash
# Install plugins manually
docker exec jenkins_container jenkins-plugin-cli --plugins plugin-name:version
```

### Performance Tuning

#### Resource Allocation
- **GitLab**: Requires 4GB+ RAM for optimal performance
- **Jenkins**: Scale based on concurrent build needs
- **Kafka**: Adjust heap size based on throughput requirements

#### Network Optimization
- Use **host networking** for high-performance scenarios
- Configure **connection pooling** for database connections
- Optimize **message broker** settings for throughput

## 🚦 Service Health Monitoring

### Health Check Commands
```bash
# Check all infrastructure services
./docker-manager.sh category infrastructure status

# Individual service health
docker exec traefik_container wget --spider http://localhost:8080/ping
docker exec consul_container consul members
docker exec vault_container vault status
```

## 📚 Integration Examples

### Using Services Together

#### CI/CD Pipeline with GitLab + Vault
```yaml
# .gitlab-ci.yml
variables:
  VAULT_ADDR: "http://vault.localhost:8200"

deploy:
  script:
    - vault kv get -field=password secret/deploy/production
```

#### Service Discovery with Consul + Traefik
```yaml
# Service registration in Consul automatically discovered by Traefik
services:
  my-app:
    labels:
      - "consul.http.routers.my-app.rule=Host(`app.localhost`)"
```

#### Message Processing with Kafka + Applications
```bash
# Produce messages
docker exec kafka_container kafka-console-producer --topic events --bootstrap-server localhost:9092

# Consume messages
docker exec kafka_container kafka-console-consumer --topic events --bootstrap-server localhost:9092
```

---

**💡 Pro Tip**: Start with core infrastructure (Traefik, Consul, Vault) and gradually add other services based on your needs!
