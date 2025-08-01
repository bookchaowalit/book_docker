# Cross-Platform Migration Tools

This directory contains tools for migrating configurations between Docker Compose and Kubernetes deployments, as well as synchronizing and validating configurations across both platforms.

## Tools Overview

### 1. Docker to Kubernetes Migration (`docker-to-k8s.sh`)

Converts Docker Compose files to Kubernetes manifests with intelligent mapping of services, volumes, networks, and environment variables.

**Usage:**
```bash
./docker-to-k8s.sh <docker-compose-path> [output-dir] [namespace]
```

**Examples:**
```bash
# Convert single service
./docker-to-k8s.sh docker/applications/nocodb/docker-compose.yml

# Convert with custom output and namespace
./docker-to-k8s.sh docker/applications/nocodb/ ./k8s/applications/ book-stack

# Convert database service
./docker-to-k8s.sh docker/databases/postgres/docker-compose.yml ./k8s/databases/ databases
```

**Features:**
- Automatic ConfigMap generation from environment variables
- PersistentVolumeClaim creation for volumes
- Service and Ingress generation
- Traefik label conversion to Kubernetes Ingress
- Resource limits and health checks
- Namespace management

### 2. Kubernetes to Docker Migration (`k8s-to-docker.sh`)

Converts Kubernetes manifests back to Docker Compose format with environment file generation.

**Usage:**
```bash
./k8s-to-docker.sh <k8s-manifest-path> [output-dir]
```

**Examples:**
```bash
# Convert single manifest
./k8s-to-docker.sh k8s/applications/nocodb.yaml

# Convert entire directory
./k8s-to-docker.sh k8s/applications/ ./docker/applications/

# Convert database manifest
./k8s-to-docker.sh k8s/databases/postgres.yaml ./docker/databases/
```

**Features:**
- Docker Compose service generation from Deployments
- Environment file (.env) creation from ConfigMaps
- Volume mapping from PersistentVolumeClaims
- Port mapping from Services
- Traefik label generation from Ingress rules
- Network configuration

### 3. Configuration Synchronization (`sync-configs.sh`)

Synchronizes environment variables and configurations between Docker and Kubernetes deployments.

**Usage:**
```bash
./sync-configs.sh <source-type> <target-type> [service-name]
```

**Examples:**
```bash
# Sync all Docker configs to Kubernetes
./sync-configs.sh docker k8s

# Sync all Kubernetes configs to Docker
./sync-configs.sh k8s docker

# Sync specific service
./sync-configs.sh docker k8s nocodb

# Validate configurations (special mode)
./sync-configs.sh validate all
```

**Features:**
- Environment variable synchronization
- ConfigMap and .env file management
- Configuration drift detection
- Backup creation before changes
- Cross-platform validation

### 4. Configuration Validation (`validate-configs.sh`)

Validates Docker Compose files and Kubernetes manifests for syntax errors, best practices, and common issues.

**Usage:**
```bash
./validate-configs.sh [platform] [service-name]
```

**Examples:**
```bash
# Validate all services on both platforms
./validate-configs.sh

# Validate only Docker services
./validate-configs.sh docker

# Validate only Kubernetes services
./validate-configs.sh k8s

# Validate specific service
./validate-configs.sh both nocodb
```

**Features:**
- YAML syntax validation
- Docker Compose syntax checking
- Kubernetes manifest validation
- Resource requirement checks
- Port conflict detection
- Volume mount validation
- Network configuration checks
- Best practice recommendations

## Dependencies

### Required Dependencies
- **yq**: YAML processor for parsing and manipulating YAML files
  - Installation: https://github.com/mikefarah/yq#install

### Optional Dependencies
- **docker**: For Docker Compose validation
  - Installation: https://docs.docker.com/get-docker/
- **kubectl**: For Kubernetes manifest validation
  - Installation: https://kubernetes.io/docs/tasks/tools/

## Migration Workflow

### 1. Docker to Kubernetes Migration

```bash
# Step 1: Validate existing Docker Compose files
./validate-configs.sh docker

# Step 2: Convert Docker Compose to Kubernetes
./docker-to-k8s.sh docker/applications/nocodb/ ./k8s/applications/ book-stack

# Step 3: Validate generated Kubernetes manifests
./validate-configs.sh k8s nocodb

# Step 4: Apply to cluster (manual step)
kubectl apply -f ./k8s/applications/nocodb.yaml
```

### 2. Kubernetes to Docker Migration

```bash
# Step 1: Validate existing Kubernetes manifests
./validate-configs.sh k8s

# Step 2: Convert Kubernetes to Docker Compose
./k8s-to-docker.sh k8s/applications/nocodb.yaml ./docker/applications/nocodb/

# Step 3: Validate generated Docker Compose
./validate-configs.sh docker nocodb

# Step 4: Deploy with Docker Compose (manual step)
cd ./docker/applications/nocodb/
docker compose up -d
```

### 3. Configuration Synchronization

```bash
# Sync environment variables from Docker to Kubernetes
./sync-configs.sh docker k8s

# Validate synchronization
./sync-configs.sh validate all

# Sync back from Kubernetes to Docker if needed
./sync-configs.sh k8s docker
```

## Generated File Structure

### Docker to Kubernetes Output
```
k8s-output/
├── namespace.yaml          # Namespace definition
├── service-name.yaml       # Complete Kubernetes manifest
│   ├── ConfigMap          # Environment variables
│   ├── PersistentVolumeClaim  # Volume storage
│   ├── Deployment         # Application deployment
│   ├── Service            # Network service
│   └── Ingress            # External access (if applicable)
```

### Kubernetes to Docker Output
```
docker-output/
├── docker-compose.yml      # Docker Compose service definition
├── .env                    # Environment variables
└── .env.backup.*          # Backup of previous .env file
```

## Best Practices

### Before Migration
1. **Backup existing configurations**
2. **Validate source configurations** using validation tools
3. **Review dependencies** between services
4. **Plan namespace and network strategy** for Kubernetes

### During Migration
1. **Review generated manifests** before applying
2. **Adjust resource limits** based on your environment
3. **Update volume mount paths** as needed
4. **Configure ingress hostnames** appropriately

### After Migration
1. **Test service connectivity** between components
2. **Verify data persistence** for stateful services
3. **Monitor resource usage** and adjust limits
4. **Update documentation** with new deployment procedures

## Troubleshooting

### Common Issues

#### Docker to Kubernetes
- **Volume mount paths**: Adjust container mount paths in generated manifests
- **Resource limits**: Review and adjust CPU/memory limits
- **Network policies**: Configure Kubernetes network policies if needed
- **Ingress configuration**: Update hostnames and paths for your environment

#### Kubernetes to Docker
- **Port conflicts**: Check for port conflicts in generated compose files
- **Environment variables**: Review .env files for sensitive data
- **Volume mappings**: Adjust host volume paths as needed
- **Network configuration**: Ensure shared networks exist

#### Configuration Sync
- **Permission issues**: Ensure write permissions for config files
- **Backup conflicts**: Clean up old backup files if needed
- **Environment differences**: Review environment-specific variables

### Validation Errors
- **YAML syntax**: Use `yq` to validate YAML syntax
- **Docker Compose**: Use `docker compose config` to validate
- **Kubernetes**: Use `kubectl apply --dry-run=client` to validate

## Contributing

When adding new features or fixing bugs:

1. **Test with sample configurations** from both platforms
2. **Update documentation** for new features
3. **Add validation checks** for new configuration patterns
4. **Maintain backward compatibility** where possible

## Support

For issues or questions:
1. Check the validation output for specific error messages
2. Review the generated files for manual adjustments needed
3. Consult the troubleshooting section above
4. Check dependencies are properly installed