# Centralized Docker Infrastructure Documentation

Welcome to the centralized Docker infrastructure documentation. This system provides shared services and standardized deployment patterns for all applications.

## 📚 Documentation Overview

| Document | Purpose | Audience |
|----------|---------|----------|
| **[Centralized Infrastructure Guide](centralized-infrastructure-guide.md)** | Complete integration guide with detailed explanations | Developers integrating new applications |
| **[Quick Integration Reference](quick-integration-reference.md)** | Essential configuration and quick reference | Developers who need quick answers |
| **[Integration Examples](integration-examples.md)** | Practical examples for different tech stacks | Developers implementing specific technologies |

## 🏗️ Infrastructure Overview

### Shared Services Available

| Service | Internal Host | External Port | Purpose |
|---------|---------------|---------------|---------|
| **PostgreSQL** | `postgres` | 5432 | Primary relational database |
| **MySQL** | `mysql` | 3306 | Alternative relational database |
| **Redis** | `redis` | 6379 | Caching and session storage |
| **MongoDB** | `mongodb` | 27017 | Document database |
| **Traefik** | `shared_traefik` | 8080/8443 | Reverse proxy and load balancer |

### Access Points

- **Traefik Dashboard**: http://localhost:8090
- **Applications**: http://[app-name].localhost:8080
- **Direct Database Access**: Available on standard ports

## 🚀 Quick Start

### For New Applications

1. **Choose your guide**:
   - New to the system? → [Centralized Infrastructure Guide](centralized-infrastructure-guide.md)
   - Need quick reference? → [Quick Integration Reference](quick-integration-reference.md)
   - Looking for examples? → [Integration Examples](integration-examples.md)

2. **Basic integration steps**:
   ```bash
   # 1. Add shared networks to your docker-compose.yml
   # 2. Configure database connections to use shared services
   # 3. Add Traefik labels for web access
   # 4. Deploy your application
   docker-compose up -d
   ```

3. **Verify integration**:
   ```bash
   # Check if accessible
   curl http://your-app.localhost:8080
   
   # Test database connectivity
   docker exec your-app-container ping postgres
   ```

### For Infrastructure Management

```bash
# Start centralized infrastructure
./docker-manager.sh infra-start

# Check status of all services
./docker-manager.sh status

# Start all applications with cleanup
./docker-manager.sh start-all

# Monitor disk usage
./docker-manager.sh disk-usage

# Setup automatic cleanup
./docker-manager.sh setup-auto-cleanup
```

## 🔧 Essential Configuration

### Required Networks
All applications must connect to this network:
```yaml
networks:
  shared-networks:
    external: true
```

### Database Connection Patterns
```bash
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123

# MySQL
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=mysql123

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123
```

### Traefik Integration
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`)"
  - "traefik.http.routers.your-app.entrypoints=web"
  - "traefik.http.services.your-app.loadbalancer.server.port=3000"
```

## 📋 Supported Technologies

We provide integration examples for:

- **Python**: Django, Flask, FastAPI
- **Node.js**: Express, NestJS, Next.js
- **PHP**: Laravel, Symfony, WordPress
- **Ruby**: Rails, Sinatra
- **Go**: Gin, Echo, Fiber
- **Java**: Spring Boot, Quarkus
- **C#**: .NET Core, ASP.NET
- **Frontend**: React, Vue, Angular (with backend APIs)

## 🔍 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| Can't connect to database | Check if infrastructure is running: `./docker-manager.sh infra-status` |
| App not accessible via browser | Verify Traefik labels and network configuration |
| "Network not found" error | Start centralized infrastructure first |
| Port conflicts | Use Traefik instead of direct port mapping |

### Debug Commands
```bash
# Check infrastructure status
./docker-manager.sh status

# View service logs
docker-compose logs your-service

# Test network connectivity
docker exec your-app ping postgres

# Check Traefik routing
curl http://localhost:8090/api/rawdata | grep your-app
```

## 🛡️ Best Practices

### Security
- ✅ Use environment variables for credentials
- ✅ Connect applications through internal networks
- ✅ Use Traefik for external access (no direct port exposure)
- ✅ Implement health checks for monitoring

### Performance
- ✅ Use connection pooling for databases
- ✅ Implement Redis caching where appropriate
- ✅ Add health checks for proper load balancing
- ✅ Use specific image tags (not `latest`)

### Maintenance
- ✅ Regular cleanup with `./docker-manager.sh cleanup`
- ✅ Monitor disk usage with `./docker-manager.sh disk-usage`
- ✅ Setup automatic cleanup with `./docker-manager.sh setup-auto-cleanup`
- ✅ Keep applications stateless when possible

## 📊 Infrastructure Management

### Daily Operations
```bash
# Start everything (includes automatic cleanup)
./docker-manager.sh start-all

# Check status
./docker-manager.sh status

# View resource usage
./docker-manager.sh disk-usage
```

### Maintenance
```bash
# Manual cleanup
./docker-manager.sh cleanup

# Aggressive cleanup (when needed)
./docker-manager.sh cleanup-aggressive

# Setup automatic maintenance
./docker-manager.sh setup-auto-cleanup
```

### Monitoring
```bash
# View cleanup statistics
./docker-manager.sh cleanup-stats

# Check infrastructure health
./docker-manager.sh infra-status

# View application logs
./docker-manager.sh logs <service-name>
```

## 🆘 Getting Help

### Documentation Priority
1. **Quick answers**: [Quick Integration Reference](quick-integration-reference.md)
2. **Detailed guidance**: [Centralized Infrastructure Guide](centralized-infrastructure-guide.md)
3. **Practical examples**: [Integration Examples](integration-examples.md)

### Support Process
1. Check the troubleshooting sections in the guides
2. Run diagnostic commands: `./docker-manager.sh status`
3. Check service logs: `docker-compose logs <service>`
4. Verify network connectivity: `docker exec <container> ping postgres`

### Common Resources
- **Traefik Dashboard**: http://localhost:8090 (for routing issues)
- **Database Access**: Direct connection available on standard ports
- **Log Files**: Available via `docker-compose logs` or `./docker-manager.sh logs`

## 🔄 Migration Guide

### From Individual Databases to Centralized
1. **Backup your data** from individual database containers
2. **Update docker-compose.yml** to use shared database hosts
3. **Remove individual database services** from your compose file
4. **Add shared networks** configuration
5. **Restore data** to centralized databases
6. **Test connectivity** and functionality

### From Direct Port Access to Traefik
1. **Add Traefik labels** to your services
2. **Remove direct port mappings** from docker-compose.yml
3. **Add shared networks** configuration
4. **Test access** via `http://your-app.localhost:8080`

## 📈 Benefits of Centralized Infrastructure

### Resource Efficiency
- **Reduced Memory Usage**: Shared databases instead of per-app instances
- **Disk Space Savings**: Automatic cleanup and resource optimization
- **Network Efficiency**: Optimized internal communication

### Operational Benefits
- **Simplified Management**: Single point of control for infrastructure
- **Consistent Configuration**: Standardized database and network setup
- **Automated Maintenance**: Scheduled cleanup and health monitoring
- **Easy Scaling**: Add new applications without infrastructure setup

### Developer Experience
- **Quick Integration**: Standard patterns for all technologies
- **Consistent Access**: Same database hosts and credentials across apps
- **Easy Debugging**: Centralized logging and monitoring
- **Reduced Complexity**: No need to manage individual infrastructure

---

**🎯 Ready to integrate your application?** Start with the [Quick Integration Reference](quick-integration-reference.md) for immediate setup, or dive into the [Centralized Infrastructure Guide](centralized-infrastructure-guide.md) for comprehensive understanding.