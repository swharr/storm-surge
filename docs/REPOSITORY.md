# OceanSurge Repository Guide

## Repository Information

- **Repository Name**: OceanSurge
- **Repository URL**: https://github.com/swharr/storm-surge
- **Product Name**: Storm Surge
- **Namespace**: oceansurge

## Naming Convention

We use a dual naming strategy:

### Repository Level
- **GitHub Repository**: `OceanSurge`
- **Kubernetes Namespace**: `oceansurge`
- **Docker Images**: `oceansurge/service-name`

### Product Level
- **Product Name**: Storm Surge
- **Version Tags**: `v1.0-storm-surge`
- **Documentation**: References "Storm Surge"
- **UI/Frontend**: Displays "Storm Surge"

## Quick Commands

```bash
# Clone repository
git clone https://github.com/swharr/storm-surge.git

# Deploy Storm Surge
cd OceanSurge
./scripts/deploy.sh

# Monitor in oceansurge namespace
kubectl get pods -n oceansurge

# Access frontend
kubectl get svc frontend-service -n oceansurge
```

## Repository Structure

```
OceanSurge/                    # Repository root
├── manifests/
│   ├── base/                  # Core Storm Surge app
│   ├── finops/               # FinOps controller
│   └── ocean/                # Spot Ocean configs
├── scripts/                   # Deployment scripts
├── chaos-testing/             # Chaos engineering
├── finops/                    # Python FinOps code
└── docs/                      # Documentation
```

This structure maintains clarity between the repository name (OceanSurge) and the product name (Storm Surge).
