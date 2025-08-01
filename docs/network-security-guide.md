# Network and Security Configuration Guide

This guide covers the network and security configuration implementation for the infrastructure organization project.

## Overview

The network and security configuration provides:

1. **Network Setup Scripts** for both Docker and Kubernetes
2. **Security Policy Templates** and configurations
3. **Ingress and Proxy Configuration Management**

## Components

### 1. Network Setup

#### Docker Network Setup (integrated in `docker-manager.sh`)

Creates and manages Docker networks with proper isolation:

- **shared-networks** (172.20.0.0/16) - Main shared network
- **monitoring-network** (172.21.0.0/16) - Monitoring services
- **database-network** (172.22.0.0/16) - Database services
- **application-network** (172.23.0.0/16) - Application services
- **security-network** (172.24.0.0/16) - Security services

**Usage:**
```bash
# Create all networks
./docker-manager.sh setup-networks

# List network status
./docker-manager.sh list-networks

# Validate networks
./docker-manager.sh validate-networks
```

**Features:**
- Automatic network creation with security settings
- Network isolation rules using iptables
- Health checking and validation
- Proper subnet allocation

#### Kubernetes Network Setup (`scripts/network-setup-k8s.sh`)

Creates namespaces and network policies for Kubernetes:

- **Namespaces**: book-stack, book-monitoring, book-databases, book-infrastructure, book-security
- **Network Policies**: Default deny, database access, application access, monitoring access, security access
- **Service Mesh Configuration**: Istio-ready configurations

**Usage:**
```bash
# Create namespaces and policies
./scripts/network-setup-k8s.sh create

# Apply network policies
./scripts/network-setup-k8s.sh apply

# Create service mesh config
./scripts/network-setup-k8s.sh mesh

# Validate setup
./scripts/network-setup-k8s.sh validate
```

### 2. Security Policies (integrated in `docker-manager.sh`)

Comprehensive security policy management for both platforms.

#### Docker Security Features

- **Daemon Configuration** (`docker/security/daemon.json`)
  - Security-hardened Docker daemon settings
  - Logging configuration
  - Resource limits
  - TLS settings

- **Secure Compose Template** (`docker/security/templates/secure-compose-template.yml`)
  - Non-root user execution
  - Read-only root filesystem
  - Capability dropping
  - Resource limits
  - Health checks

- **Image Security Scanner** (`docker/security/scan-images.sh`)
  - Trivy integration for vulnerability scanning
  - Security best practices checking
  - Image analysis and reporting

#### Kubernetes Security Features

- **Pod Security Policies** (`k8s/security/policies/pod-security-policy.yaml`)
  - Restricted security contexts
  - Non-root execution requirements
  - Capability restrictions

- **Network Security Policies** (`k8s/security/policies/network-security-policy.yaml`)
  - Default deny all traffic
  - DNS access allowance
  - Namespace-based isolation

- **RBAC Templates** (`k8s/security/templates/rbac-template.yaml`)
  - Service account configurations
  - Role-based access control
  - Least privilege principles

- **Security Scanner** (`k8s/security/tools/k8s-security-scan.sh`)
  - RBAC configuration checking
  - Pod security validation
  - Network policy verification
  - Secret management analysis

**Usage:**
```bash
# Create security policies
./docker-manager.sh setup-security

# Validate security configuration
./docker-manager.sh validate-security
```

### 3. Ingress and Proxy Management (integrated in `docker-manager.sh`)

Manages ingress and proxy configurations for both platforms.

#### Templates Created

- **Traefik Configuration** (`templates/ingress/docker/traefik-template.yml`)
  - SSL/TLS termination
  - Automatic certificate management
  - Security middleware
  - Load balancing
  - Health checks

- **Nginx Proxy Configuration** (`templates/ingress/docker/nginx-template.yml`)
  - Upstream load balancing
  - Security headers
  - Rate limiting
  - SSL configuration

- **Kubernetes Ingress Templates** (`templates/ingress/kubernetes/ingress-template.yaml`)
  - NGINX Ingress Controller configuration
  - SSL/TLS with cert-manager
  - Security annotations
  - Rate limiting

- **Gateway API Templates** (`templates/ingress/kubernetes/gateway-api-template.yaml`)
  - Next-generation ingress configuration
  - Advanced routing capabilities
  - Header manipulation

#### Dynamic Configurations

- **Traefik Middlewares** (`docker/infrastructure/traefik/config/dynamic/middlewares.yml`)
  - Security headers
  - Rate limiting
  - Authentication
  - Circuit breakers
  - Load balancing

- **Nginx Upstreams** (`docker/infrastructure/nginx/conf.d/upstreams.conf`)
  - Backend server pools
  - Health checking
  - Load balancing algorithms

- **Security Configuration** (`docker/infrastructure/nginx/conf.d/security.conf`)
  - Security headers
  - Rate limiting zones
  - SSL/TLS configuration
  - Attack pattern blocking

**Usage:**
```bash
# Create ingress templates and configurations
./docker-manager.sh create-ingress

# Generate service-specific ingress
./docker-manager.sh generate-ingress myapp example.com 8080 production

# Validate ingress configurations
./docker-manager.sh validate-ingress
```

## Security Features

### Network Security

1. **Network Isolation**
   - Separate networks for different service tiers
   - iptables rules for traffic control
   - Kubernetes network policies for pod isolation

2. **Traffic Control**
   - Rate limiting at proxy level
   - Connection limits
   - Request size restrictions

3. **SSL/TLS Configuration**
   - Automatic certificate management
   - Strong cipher suites
   - HSTS headers

### Container Security

1. **Runtime Security**
   - Non-root user execution
   - Read-only root filesystems
   - Capability dropping
   - Security contexts

2. **Image Security**
   - Vulnerability scanning with Trivy
   - Base image validation
   - Security best practices checking

3. **Resource Security**
   - CPU and memory limits
   - Storage quotas
   - Network bandwidth controls

### Access Control

1. **Authentication**
   - Basic authentication for admin interfaces
   - Service account management
   - RBAC implementation

2. **Authorization**
   - Role-based access control
   - Namespace isolation
   - Service-to-service authentication

## Integration with Requirements

This implementation addresses the following requirements:

### Requirement 6.1 (Network Policies)
- ✅ Network policies enforce proper isolation
- ✅ Docker networks with security settings
- ✅ Kubernetes network policies for pod isolation

### Requirement 6.2 (Access Controls)
- ✅ Ingress/proxy configurations control access
- ✅ Authentication middleware
- ✅ RBAC templates for Kubernetes

### Requirement 6.3 (Secure Communication)
- ✅ Internal networking uses secure protocols
- ✅ SSL/TLS termination at proxy level
- ✅ Service mesh ready configurations

## Best Practices Implemented

1. **Defense in Depth**
   - Multiple layers of security controls
   - Network, container, and application security

2. **Least Privilege**
   - Minimal required permissions
   - Non-root execution
   - Capability restrictions

3. **Security by Default**
   - Secure templates and configurations
   - Automatic security headers
   - Default deny network policies

4. **Monitoring and Auditing**
   - Security scanning tools
   - Configuration validation
   - Status monitoring

## Usage Examples

### Setting up a new environment

```bash
# 1. Create Docker networks
./docker-manager.sh setup-networks

# 2. Create security policies
./docker-manager.sh setup-security

# 3. Create ingress templates
./docker-manager.sh create-ingress

# 4. Generate service-specific configurations
./docker-manager.sh generate-ingress myapp yourdomain.com 8080

# 5. Validate everything
./docker-manager.sh validate-networks
./docker-manager.sh validate-security
./docker-manager.sh validate-ingress
```

### For Kubernetes environments

```bash
# 1. Create namespaces and network policies
./scripts/network-setup-k8s.sh create

# 2. Apply network policies
./scripts/network-setup-k8s.sh apply

# 3. Run security scan (if available)
./k8s/security/tools/k8s-security-scan.sh all
```

## Troubleshooting

### Common Issues

1. **Network Creation Fails**
   - Check Docker daemon is running
   - Verify subnet conflicts
   - Check iptables rules

2. **Security Policies Not Applied**
   - Verify Kubernetes cluster connectivity
   - Check RBAC permissions
   - Validate YAML syntax

3. **Ingress Not Working**
   - Check ingress controller status
   - Verify DNS configuration
   - Check certificate status

### Validation Commands

```bash
# Docker network validation
./docker-manager.sh validate-networks

# Security configuration validation
./docker-manager.sh validate-security

# Ingress configuration validation
./docker-manager.sh validate-ingress

# Kubernetes security scan (if available)
./k8s/security/tools/k8s-security-scan.sh all
```

## Files Created

### Main Script
- `docker-manager.sh` - Consolidated infrastructure management (includes network, security, and ingress management)

### Kubernetes-Specific Scripts
- `scripts/network-setup-k8s.sh` - Kubernetes network management

### Docker Security
- `docker/security/daemon.json` - Docker daemon security config
- `docker/security/templates/secure-compose-template.yml` - Secure compose template
- `docker/security/scan-images.sh` - Image security scanner

### Kubernetes Security
- `k8s/security/policies/pod-security-policy.yaml` - Pod security policies
- `k8s/security/policies/network-security-policy.yaml` - Network policies
- `k8s/security/templates/rbac-template.yaml` - RBAC templates
- `k8s/security/tools/k8s-security-scan.sh` - Security scanner

### Templates
- `templates/ingress/docker/traefik-template.yml` - Traefik configuration
- `templates/ingress/docker/nginx-template.yml` - Nginx configuration
- `templates/ingress/kubernetes/ingress-template.yaml` - Kubernetes ingress
- `templates/ingress/kubernetes/gateway-api-template.yaml` - Gateway API

### Dynamic Configurations
- `docker/infrastructure/traefik/config/dynamic/middlewares.yml` - Traefik middlewares
- `docker/infrastructure/nginx/conf.d/upstreams.conf` - Nginx upstreams
- `docker/infrastructure/nginx/conf.d/security.conf` - Nginx security

This implementation provides a comprehensive network and security foundation for the infrastructure organization project, addressing all requirements while following security best practices.