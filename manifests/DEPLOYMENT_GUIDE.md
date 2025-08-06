# Storm Surge Multi-Cloud Deployment Guide

## Overview

This guide provides deployment instructions for Storm Surge on AWS EKS, Google GKE, and Azure AKS with production-ready security configurations.

## Architecture Components

### Core Infrastructure
- **Kubernetes Clusters**: Production-ready managed clusters (EKS/GKE/AKS)
- **Load Balancers**: Cloud-native load balancers with SSL termination
- **SSL/TLS**: Managed certificates with automatic renewal
- **Identity Management**: IRSA (AWS), Workload Identity (GCP), Managed Identity (Azure)
- **Security**: WAF/Cloud Armor, network policies, pod security standards
- **Monitoring**: Prometheus, Grafana, structured logging
- **Backup**: Velero with cloud-specific storage

### Security Features
- JWT authentication with secure token handling
- Rate limiting and DDoS protection
- SQL injection prevention with parameterized queries
- XSS protection with proper output encoding
- HTTPS-only communication with security headers
- Network segmentation and pod security contexts
- Secrets management with cloud KMS/Key Vault
- Audit logging for compliance

## Quick Start

### Prerequisites
- Cloud CLI tools installed (aws/gcloud/az)
- kubectl and helm installed
- Terraform (optional, for infrastructure as code)

### 1. AWS EKS Deployment

```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Deploy cluster
eksctl create cluster -f manifests/cloud-infrastructure/aws-infrastructure.yaml

# Install AWS Load Balancer Controller
kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.0/v2_7_0_full.yaml

# Deploy application
kubectl apply -f manifests/security/production-security-hardening.yaml
kubectl apply -f manifests/dev/services.yaml
```

### 2. Google GKE Deployment

```bash
# Enable APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Apply Terraform configuration
cd manifests/cloud-infrastructure
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Get cluster credentials
gcloud container clusters get-credentials storm-surge-prod --region us-central1

# Deploy application
kubectl apply -f ../security/production-security-hardening.yaml
kubectl apply -f ../dev/services.yaml
```

### 3. Azure AKS Deployment

```bash
# Create resource group
az group create --name storm-surge-prod-rg --location eastus

# Apply Terraform configuration
cd manifests/cloud-infrastructure
terraform init
terraform apply

# Get cluster credentials
az aks get-credentials --resource-group storm-surge-prod-rg --name storm-surge-prod

# Install Application Gateway Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml

# Deploy application
kubectl apply -f ../security/production-security-hardening.yaml
kubectl apply -f ../dev/services.yaml
```

## Configuration Details

### Environment Variables Required

Create these secrets in your cluster:

```bash
# Database credentials
kubectl create secret generic db-credentials \
  --from-literal=DATABASE_PASSWORD=your-secure-password \
  --from-literal=DATABASE_USER=app_user \
  --from-literal=DATABASE_NAME=stormsurge

# Redis credentials
kubectl create secret generic redis-credentials \
  --from-literal=REDIS_PASSWORD=your-redis-password

# JWT secret
kubectl create secret generic app-secrets \
  --from-literal=JWT_SECRET=$(openssl rand -base64 32) \
  --from-literal=ADMIN_PASSWORD=$(openssl rand -base64 16)

# LaunchDarkly (optional)
kubectl create secret generic launchdarkly \
  --from-literal=LAUNCHDARKLY_SDK_KEY=your-sdk-key \
  --from-literal=LAUNCHDARKLY_API_KEY=your-api-key
```

### SSL Certificate Setup

#### AWS (ACM)
```bash
# Request certificate
aws acm request-certificate \
  --domain-name api.stormsurge.example.com \
  --subject-alternative-names "*.stormsurge.example.com" \
  --validation-method DNS
```

#### GCP (Google Managed SSL)
```bash
# Certificate is automatically provisioned via Terraform
# Verify in Google Cloud Console > Network Security > SSL Certificates
```

#### Azure (Key Vault)
```bash
# Certificate is managed through Key Vault
# Update the domain names in the Terraform configuration
```

## Production Checklist

### Security
- [ ] Enable pod security standards (baseline/restricted)
- [ ] Configure network policies for traffic segmentation
- [ ] Set up RBAC with least privilege access
- [ ] Enable audit logging
- [ ] Configure secrets encryption at rest
- [ ] Set up vulnerability scanning
- [ ] Enable container image scanning

### Monitoring
- [ ] Deploy Prometheus and Grafana
- [ ] Configure alerting rules
- [ ] Set up log aggregation (ELK/Loki)
- [ ] Enable distributed tracing
- [ ] Configure uptime monitoring
- [ ] Set up SLO/SLA dashboards

### Backup & Recovery
- [ ] Install and configure Velero
- [ ] Test backup and restore procedures
- [ ] Set up cross-region backup replication
- [ ] Document disaster recovery procedures

### Performance
- [ ] Configure horizontal pod autoscaling
- [ ] Set up cluster autoscaling
- [ ] Tune resource requests and limits
- [ ] Enable CDN for static assets
- [ ] Configure connection pooling

## Scaling Configurations

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: storm-surge-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: storm-surge-api
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Cluster Autoscaler
Each cloud provider has built-in cluster autoscaling configured in the infrastructure templates.

## Troubleshooting

### Common Issues

1. **Certificate not provisioning**
   - Verify DNS records are correctly configured
   - Check certificate status in cloud console
   - Ensure ingress annotations are correct

2. **Pods not scheduling**
   - Check node capacity and resource requests
   - Verify taints and tolerations
   - Check pod security context restrictions

3. **Database connection issues**
   - Verify network policies allow traffic
   - Check security group rules
   - Validate credentials in secrets

4. **High latency**
   - Review resource limits and requests
   - Check database connection pooling
   - Verify cache hit rates

### Monitoring and Alerting

Access monitoring dashboards:
- **AWS**: CloudWatch + Prometheus/Grafana
- **GCP**: Cloud Monitoring + Prometheus/Grafana  
- **Azure**: Azure Monitor + Prometheus/Grafana

Key metrics to monitor:
- Request rate and latency (p95, p99)
- Error rate (4xx, 5xx responses)
- Resource utilization (CPU, memory, disk)
- Database performance (connections, query time)
- Cache hit ratio
- Certificate expiration dates

## Security Hardening

The deployed configuration includes:

### Application Level
- JWT authentication with RS256 signing
- Rate limiting per user and endpoint
- Input validation and sanitization
- SQL injection prevention
- XSS protection
- HTTPS-only communication

### Infrastructure Level
- Network policies for traffic control
- Pod security contexts (non-root, read-only filesystem)
- Secrets encryption at rest
- RBAC with minimal permissions
- Regular security updates via managed node pools

### Cloud Security
- **AWS**: WAF rules, Security Groups, IAM roles
- **GCP**: Cloud Armor, VPC firewall rules, Workload Identity
- **Azure**: Application Gateway WAF, NSGs, Managed Identity

## Cost Optimization

### Spot/Preemptible Instances
All configurations include spot instance usage:
- **AWS**: Spot instances in node groups
- **GCP**: Preemptible VMs (can be configured)
- **Azure**: Spot VMs for worker nodes

### Resource Management
- Requests and limits set appropriately
- Horizontal Pod Autoscaling to match demand
- Cluster autoscaling to optimize node usage
- Monitoring to identify optimization opportunities

## Support and Maintenance

### Updates
- Kubernetes version upgrades via managed services
- Application updates via rolling deployments
- Security patches applied automatically to managed nodes

### Backup Strategy
- Daily automated backups via Velero
- Cross-region backup storage
- Tested restore procedures
- RTO/RPO defined and measured

This deployment provides a production-ready, secure, and scalable foundation for the Storm Surge application across multiple cloud providers.