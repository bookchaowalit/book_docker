# Book Stack Kubernetes Deployment

This directory contains Kubernetes manifests for deploying a comprehensive stack of applications including databases, monitoring, and various business applications.

## 🚀 Quick Start

```bash
# Deploy everything
./deploy.sh

# Or deploy manually step by step
kubectl apply -f namespace/
kubectl apply -f storage/
kubectl apply -f databases/
kubectl apply -f monitoring/
kubectl apply -f applications/
kubectl apply -f ingress/

# Cleanup everything
./deploy.sh cleanup
```

## 📁 Directory Structure

```
k8s/
├── namespace/          # Kubernetes namespaces
├── storage/           # Storage classes and PVCs
├── databases/         # Database services (PostgreSQL, MySQL, Redis)
├── monitoring/        # Monitoring stack (Prometheus, Grafana)
├── applications/      # Application services
├── ingress/          # Ingress controllers and rules
├── deploy.sh         # Automated deployment script
└── README.md         # This file
```

## 🗄️ Services Included

### Databases (book-databases namespace)
- **PostgreSQL**: Main relational database
- **MySQL**: Alternative database for specific applications
- **Redis**: In-memory data store and cache

### Monitoring (book-monitoring namespace)
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards

### Applications (book-stack namespace)
- **BaseRow**: No-code database and collaboration platform
- **NocoDB**: Turns any database into smart spreadsheet
- **Open WebUI**: AI chat interface

## 🔧 Prerequisites

1. **Kubernetes Cluster**: Running Kubernetes cluster (local or cloud)
2. **kubectl**: Configured to connect to your cluster
3. **Storage**: Persistent volume support in your cluster
4. **Ingress Controller**: NGINX Ingress Controller (deployed automatically)

## 📋 Deployment Steps

### 1. Update Configuration

Before deploying, update the following:

1. **Domain Names**: Edit `ingress/applications-ingress.yaml` and replace `yourdomain.com` with your actual domain
2. **Secrets**: Update base64 encoded passwords in database manifests
3. **Storage**: Adjust storage sizes in PVC specifications as needed

### 2. Deploy Services

Use the automated deployment script:

```bash
# Make script executable (if not already)
chmod +x deploy.sh

# Deploy all services
./deploy.sh deploy

# Check deployment status
kubectl get pods --all-namespaces

# View specific service logs
kubectl logs -n book-stack deployment/baserow
```

### 3. Access Services

Once deployed, services are accessible via:

- **Grafana**: `http://grafana.yourdomain.com`
  - Default credentials: `admin/grafana` (change in `monitoring/grafana.yaml`)
- **Prometheus**: `http://prometheus.yourdomain.com`
- **BaseRow**: `http://baserow.yourdomain.com`
- **NocoDB**: `http://nocodb.yourdomain.com`
- **Open WebUI**: `http://openwebui.yourdomain.com`

## 🔐 Security Best Practices

### 1. Update Default Passwords

All services use default passwords that MUST be changed:

```bash
# Generate base64 encoded passwords
echo -n "your-secure-password" | base64

# Update the following files with new passwords:
# - databases/postgres.yaml
# - databases/mysql.yaml
# - monitoring/grafana.yaml
```

### 2. Enable TLS/SSL

The ingress manifests include TLS configuration. To enable:

1. Install cert-manager in your cluster
2. Create a ClusterIssuer for Let's Encrypt
3. Update domain names in ingress manifests

### 3. Network Policies

Consider implementing Kubernetes Network Policies to restrict inter-pod communication.

### 4. Resource Limits

All manifests include resource requests and limits. Adjust based on your cluster capacity.

## 📊 Monitoring and Observability

### Prometheus Metrics

The deployment includes comprehensive monitoring:
- Application health checks
- Resource utilization metrics
- Custom application metrics (where supported)

### Grafana Dashboards

Pre-configured datasource for Prometheus. Import community dashboards for:
- Kubernetes cluster monitoring
- PostgreSQL metrics
- NGINX Ingress metrics

### Health Checks

All services include:
- **Liveness Probes**: Restart unhealthy containers
- **Readiness Probes**: Remove unhealthy pods from service load balancing

## 🔧 Maintenance

### Scaling Services

Scale deployments as needed:

```bash
# Scale BaseRow to 3 replicas
kubectl scale deployment baserow --replicas=3 -n book-stack

# Scale monitoring
kubectl scale deployment grafana --replicas=2 -n book-monitoring
```

### Updating Services

Update service images:

```bash
# Update BaseRow image
kubectl set image deployment/baserow baserow=baserow/baserow:latest -n book-stack

# Check rollout status
kubectl rollout status deployment/baserow -n book-stack
```

### Backup and Recovery

#### Database Backups

```bash
# PostgreSQL backup
kubectl exec -n book-databases postgres-0 -- pg_dump -U postgres postgres > backup.sql

# MySQL backup
kubectl exec -n book-databases mysql-0 -- mysqldump -u root -p defaultdb > mysql-backup.sql
```

#### Persistent Volume Backups

Use your cloud provider's volume snapshot features or tools like Velero.

## 🐛 Troubleshooting

### Common Issues

1. **Pods stuck in Pending**: Check PVC provisioning and node resources
2. **Database connection failed**: Verify service names and network policies
3. **Ingress not working**: Check ingress controller installation and DNS

### Debugging Commands

```bash
# Check pod status
kubectl get pods --all-namespaces

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check service endpoints
kubectl get endpoints -n <namespace>

# Test service connectivity
kubectl run debug --image=busybox -it --rm -- sh
# Inside the pod: nslookup <service-name>.<namespace>.svc.cluster.local
```

### Port Forwarding for Testing

```bash
# Access services locally for testing
kubectl port-forward -n book-stack svc/baserow 8080:80
kubectl port-forward -n book-monitoring svc/grafana 3000:3000
kubectl port-forward -n book-databases svc/postgres 5432:5432
```

## 🔄 CI/CD Integration

The manifests are GitOps-ready and can be integrated with:
- **ArgoCD**: For GitOps-based deployments
- **Flux**: For automated deployments from Git
- **Helm**: Convert manifests to Helm charts for templating

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [cert-manager](https://cert-manager.io/)

## 🤝 Contributing

To add new services:

1. Create manifest files in appropriate directory
2. Update the deployment script
3. Add service documentation
4. Test thoroughly

## 📄 License

This deployment configuration is provided as-is for educational and development purposes.