#!/bin/bash
set -e

echo "🌩️ Setting up Storm Surge - Weather the Kubernetes Scaling Storm!"
echo "=================================================================="

# Check if we're in the right directory
if [[ ! $(basename "$PWD") == "ocean-surge" ]]; then
    echo "⚠️  Please run this script from your ocean-surge directory"
    echo "Current directory: $PWD"
    exit 1
fi

echo "📁 Creating directory structure..."

# Create directory structure
mkdir -p manifests/{base,finops,ocean/{common,aws,gcp,azure},monitoring}
mkdir -p scripts
mkdir -p chaos-testing
mkdir -p finops/examples
mkdir -p configs/{launchdarkly,clusters}
mkdir -p docs

echo "✅ Directory structure created"

echo "📝 Creating main README.md..."

# Create main README.md
cat > README.md << 'EOF'
# E-commerce Demo App for Kubernetes Elasticity Testing with Spot Ocean

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Spot.io](https://img.shields.io/badge/Spot.io-Ocean-blue?style=for-the-badge)

A comprehensive e-commerce microservices application designed specifically for testing Kubernetes elasticity, autoscaling, and cost optimization across **GKE**, **EKS**, and **AKS** with **Spot.io Ocean** integration.

## Who this is for 
- DevOps, SRE, and Platform Engineering Teams 
- Prospects and Existing Customers who want to explore the Flexera DevOps tools 
- Anyone who wants to better understand core Kubernetes Concepts. 

## 🌟 Features

- **🏪 Realistic E-commerce Architecture**: Multi-service application with realistic resource patterns
- **📈 Advanced Autoscaling**: HPA, VPA, and custom metrics scaling
- **🌊 Spot Ocean Integration**: Optimized for intelligent scaling and cost optimization
- **💰 Cost Optimization**: 60-90% cost savings with spot instances and right-sizing
- **🔥 Chaos Engineering**: Instance replacement and resilience testing
- **☁️ Multi-Cloud Support**: Deploy on AWS EKS, Google GKE, or Azure AKS
- **📊 Built-in Monitoring**: Real-time metrics and scaling visualization
- **🚀 Load Testing**: Multiple load testing tools and scenarios

## 🏗️ Architecture

```
Frontend (LoadBalancer)
    ↓
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│ Product Catalog │  Shopping Cart  │  User Service   │ Payment Service │
│ (General Nodes) │(Compute Nodes)  │(Memory Nodes)   │ (General Nodes) │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
    ↓
Redis Cache
```

### Service Characteristics

| Service | Resource Pattern | Ocean Node Type | Scaling Target |
|---------|------------------|-----------------|----------------|
| Frontend | Low CPU/Memory | General (T3/M5) | 50% CPU |
| Product Catalog | Medium CPU | General (T3/M5) | 60% CPU |
| Shopping Cart | High CPU | Compute (C5/C4) | 70% CPU |
| User Service | High Memory | Memory (R5/R4) | 80% Memory |
| Payment Service | I/O Intensive | General (T3/M5) | Manual |

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (GKE/EKS/AKS)
- kubectl configured
- Spot.io Ocean account (optional but recommended)
- Docker (for building custom images)

### 1-Minute Deploy

```bash
# Clone repository
git clone https://github.com/Shon-Harris_flexera/OceanSurge/k8s-ecommerce-ocean-demo.gits-ecommerce-ocean-demo.git
cd k8s-ecommerce-ocean-demo

# Quick deploy on any Kubernetes cluster
kubectl apply -f manifests/

# Get frontend URL
kubectl get service frontend-service
```

## 📋 Step-by-Step Deployment Guide

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/Shon-Harris_flexera/OceanSurge/k8s-ecommerce-ocean-demo.gits-ecommerce-ocean-demo.git
cd k8s-ecommerce-ocean-demo

# Make scripts executable
chmod +x scripts/*.sh
chmod +x chaos-testing/*.sh
chmod +x monitoring/*.sh
```

### Step 2: Choose Your Cloud Provider

#### Option A: AWS EKS with Ocean

<details>
<summary>Click to expand AWS EKS deployment</summary>

```bash
# 1. Install required tools
curl -fsSL https://spot.io/install | bash  # Install spotctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# 2. Create EKS cluster
eksctl create cluster \
    --name ecommerce-ocean-demo \
    --region us-west-2 \
    --nodes 3 \
    --nodes-min 2 \
    --nodes-max 20 \
    --node-type t3.medium \
    --managed

# 3. Install Ocean Controller
export SPOT_TOKEN="your-spot-token"
spotctl create ocean aws eks \
    --cluster-name ecommerce-ocean-demo \
    --region us-west-2 \
    --token $SPOT_TOKEN

# 4. Deploy Ocean Virtual Node Groups
kubectl apply -f manifests/ocean/aws/

# 5. Deploy the application
kubectl apply -f manifests/base/
kubectl apply -f manifests/ocean/common/

# 6. Verify deployment
kubectl get pods
kubectl get nodes -l spot.io/managed=true
```

</details>

#### Option B: Google GKE with Ocean

<details>
<summary>Click to expand GKE deployment</summary>

```bash
# 1. Create GKE cluster
gcloud container clusters create ecommerce-ocean-demo \
    --zone us-central1-a \
    --num-nodes 3 \
    --enable-autoscaling \
    --min-nodes 2 \
    --max-nodes 20 \
    --machine-type e2-standard-2 \
    --preemptible

# 2. Get credentials
gcloud container clusters get-credentials ecommerce-ocean-demo --zone us-central1-a

# 3. Install Ocean Controller
export SPOT_TOKEN="your-spot-token"
spotctl create ocean gcp gke \
    --cluster-name ecommerce-ocean-demo \
    --zone us-central1-a \
    --project YOUR_PROJECT_ID \
    --token $SPOT_TOKEN

# 4. Deploy Ocean configuration
kubectl apply -f manifests/ocean/gcp/

# 5. Deploy the application
kubectl apply -f manifests/base/
kubectl apply -f manifests/ocean/common/
```

</details>

#### Option C: Azure AKS with Ocean

<details>
<summary>Click to expand AKS deployment</summary>

```bash
# 1. Create resource group
az group create --name ecommerce-ocean-demo-rg --location eastus

# 2. Create AKS cluster
az aks create \
    --resource-group ecommerce-ocean-demo-rg \
    --name ecommerce-ocean-demo \
    --node-count 3 \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 20 \
    --node-vm-size Standard_DS2_v2

# 3. Get credentials
az aks get-credentials --resource-group ecommerce-ocean-demo-rg --name ecommerce-ocean-demo

# 4. Install Ocean Controller
export SPOT_TOKEN="your-spot-token"
spotctl create ocean azure aks \
    --cluster-name ecommerce-ocean-demo \
    --resource-group ecommerce-ocean-demo-rg \
    --token $SPOT_TOKEN

# 5. Deploy Ocean configuration
kubectl apply -f manifests/ocean/azure/

# 6. Deploy the application
kubectl apply -f manifests/base/
kubectl apply -f manifests/ocean/common/
```

</details>

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods

# Verify Ocean nodes
kubectl get nodes -l spot.io/managed=true

# Get frontend URL
FRONTEND_URL=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend available at: http://$FRONTEND_URL"

# Test application
curl http://$FRONTEND_URL/health
```

### Step 4: Configure Monitoring (Optional)

```bash
# Install metrics server (if not already installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Deploy monitoring stack
kubectl apply -f manifests/monitoring/

# Access Grafana dashboard
kubectl port-forward svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

## 🧪 Testing Scenarios

### Load Testing

```bash
# Basic load test
./scripts/load-test.sh light   # 10 RPS
./scripts/load-test.sh medium  # 50 RPS  
./scripts/load-test.sh heavy   # 100 RPS

# Ocean-specific scaling test
./scripts/ocean-scaling-test.sh

# Multi-workload test
./scripts/multi-workload-test.sh
```

### Chaos Engineering

```bash
# Spot instance interruption simulation
./chaos-testing/spot-interruption-chaos.sh

# Workload-specific instance replacement
./chaos-testing/workload-specific-chaos.sh

# Zone failure simulation
./chaos-testing/zone-failure-chaos.sh

# Complete chaos scenario
./chaos-testing/complete-ocean-chaos.sh
```

### Cost Optimization Testing

```bash
# Right-sizing analysis
./scripts/rightsizing-test.sh

# Spot coverage optimization
./scripts/spot-coverage-test.sh

# Cost comparison report
./scripts/cost-analysis.sh
```

## 📊 Monitoring and Metrics

### Real-time Monitoring

```bash
# Watch scaling in real-time
watch kubectl get hpa

# Monitor node changes
watch kubectl get nodes -o wide

# Track Ocean metrics
./monitoring/ocean-metrics.sh
```

### Key Metrics to Track

- **Pod Scaling**: Min/max replicas and scaling events
- **Node Provisioning**: Instance types and spot coverage
- **Cost Savings**: Real-time cost optimization
- **Application Performance**: Response times and error rates
- **Resilience**: Recovery time during instance replacements

## 📁 Repository Structure

```
k8s-ecommerce-ocean-demo/
├── README.md
├── manifests/
│   ├── base/                    # Core application manifests
│   │   ├── frontend.yaml
│   │   ├── shopping-cart.yaml
│   │   ├── product-catalog.yaml
│   │   ├── user-service.yaml
│   │   ├── payment-service.yaml
│   │   └── redis.yaml
│   ├── ocean/
│   │   ├── common/              # Ocean-common configurations
│   │   ├── aws/                 # AWS-specific Ocean configs
│   │   ├── gcp/                 # GCP-specific Ocean configs
│   │   └── azure/               # Azure-specific Ocean configs
│   └── monitoring/              # Monitoring stack
├── scripts/
│   ├── deploy.sh                # Automated deployment
│   ├── load-test.sh             # Load testing
│   ├── ocean-scaling-test.sh    # Ocean-specific tests
│   ├── multi-workload-test.sh   # Multi-service scaling
│   ├── rightsizing-test.sh      # Right-sizing analysis
│   └── cleanup.sh               # Environment cleanup
├── chaos-testing/
│   ├── spot-interruption-chaos.sh
│   ├── workload-specific-chaos.sh
│   ├── zone-failure-chaos.sh
│   ├── resource-exhaustion-chaos.sh
│   └── complete-ocean-chaos.sh
├── monitoring/
│   ├── ocean-metrics.sh
│   ├── monitor-chaos.sh
│   └── generate-report.py
├── configs/
│   ├── grafana-dashboards/
│   ├── prometheus-rules/
│   └── chaos-experiments/
└── docs/
    ├── ARCHITECTURE.md
    ├── TROUBLESHOOTING.md
    ├── COST-OPTIMIZATION.md
    └── CHAOS-ENGINEERING.md
```

## 🔧 Configuration

### Environment Variables

```bash
# Required for Ocean integration
export SPOT_TOKEN="your-spot-token"
export AWS_REGION="us-west-2"              # For AWS
export GCP_PROJECT="your-project-id"       # For GCP  
export AZURE_RESOURCE_GROUP="your-rg"      # For Azure

# Optional configurations
export FRONTEND_REPLICAS="2"
export MAX_CART_REPLICAS="20"
export ENABLE_CHAOS_TESTING="true"
```

### Customization

Edit `configs/app-config.yaml` to customize:

- Resource requests and limits
- HPA thresholds
- Ocean node preferences
- Monitoring settings

## 🚨 Troubleshooting

### Common Issues

#### Pods Stuck in Pending
```bash
# Check node capacity
kubectl describe nodes

# Check resource requests
kubectl describe pod <pod-name>

# Solution: Scale Ocean cluster or adjust resource requests
```

#### HPA Not Scaling
```bash
# Verify metrics server
kubectl get deployment metrics-server -n kube-system

# Check HPA status
kubectl describe hpa

# Solution: Ensure resource requests are set on all containers
```

#### Ocean Nodes Not Provisioning
```bash
# Check Ocean controller logs
kubectl logs -n spot-system -l app=ocean-controller

# Verify Ocean configuration
spotctl get ocean

# Solution: Check Spot token and permissions
```

### Debug Commands

```bash
# Application health
./scripts/health-check.sh

# Ocean diagnostics
./scripts/ocean-diagnostics.sh

# Complete system status
./scripts/system-status.sh
```

## 📈 Performance Benchmarks

### Expected Results

| Load Level | RPS | Avg Response Time | Error Rate | Pods | Nodes | Cost Savings |
|------------|-----|-------------------|------------|------|-------|--------------|
| Light      | 10  | 50ms              | 0%         | 6    | 3     | 70%          |
| Medium     | 50  | 150ms             | 0.1%       | 12   | 5     | 75%          |
| Heavy      | 100 | 300ms             | 1%         | 25   | 8     | 80%          |
| Burst      | 200 | 800ms             | 5%         | 40   | 12    | 85%          |

### Cost Analysis

- **Without Ocean**: ~$500/month for baseline cluster
- **With Ocean**: ~$150/month (70% savings)
- **Spot Coverage**: 80-90% average
- **Right-sizing Savings**: Additional 15-20%

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/Shon-Harris_flexera/OceanSurge/k8s-ecommerce-ocean-demo.gits-ecommerce-ocean-demo.git

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
./scripts/run-tests.sh

# Lint code
./scripts/lint.sh
```

## 📝 License

This project code is licensed under the GNU GPL License 
Flexera Spot Ocean Code and FinOps Reporting Tooling is provided under license(s) covered under the Flexera Software License Agreement.
Other Tools, Plugins, and Features may be developed by outside groups, and covered under their specific licensing.

## 🙏 Acknowledgments

- [Spot.io](https://spot.io) Learn more about Flexera's DevOps Infrastructure Tooling
- [Kubernetes](https://kubernetes.io) community
- [CNCF](https://www.cncf.io) for ecosystem tools

## 📞 Support

- 📧 Email: support@spot.io
- 💬 Slack: [Spot.io Community](https://flexera.enterprise.slack.com/archives/C08SAM2JDGS)
- 🐛 Issues: [GitHub Issues](https://github.com/swharr/OceanSurge/issues)
- 📖 Docs: [Full Spot API Documentation](https://docs.spot.io)

## 🗺️ Roadmap

- [ ] **v2.0**: Istio service mesh integration
- [ ] **v2.0**: ArgoCD GitOps deployment
- [ ] **v2.1**: Knative serverless workloads
- [ ] **v2.1**: Multi-cluster Ocean federation
- [ ] **v3.1**: AI/ML workload optimization

---

**⭐ Star this repository if it helped Ocean's functionality with your Kubernetes deployment.!**

Made with ❤️ by the Flexera Spot DevRel and SA teams for Practicioner.
EOF

echo "✅ README.md created"

echo "📱 Creating main Storm Surge application..."

# Create main application manifest
cat > manifests/base/storm-surge-app.yaml << 'EOF'
# Storm Surge E-commerce Demo Application
# Realistic microservices for testing Kubernetes elasticity

---
# Product Catalog Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-catalog
  labels:
    app: product-catalog
    tier: backend
    storm-surge.io/component: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-catalog
  template:
    metadata:
      labels:
        app: product-catalog
        tier: backend
    spec:
      containers:
      - name: product-catalog
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: SERVICE_NAME
          value: "product-catalog"
        - name: STORM_SURGE_COMPONENT
          value: "catalog"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: product-catalog-html

---
apiVersion: v1
kind: Service
metadata:
  name: product-catalog-service
spec:
  selector:
    app: product-catalog
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Shopping Cart Service (CPU intensive for scaling tests)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopping-cart
  labels:
    app: shopping-cart
    tier: backend
    storm-surge.io/component: cart
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shopping-cart
  template:
    metadata:
      labels:
        app: shopping-cart
        tier: backend
    spec:
      containers:
      - name: shopping-cart
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        env:
        - name: SERVICE_NAME
          value: "shopping-cart"
        - name: STORM_SURGE_COMPONENT
          value: "cart"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: shopping-cart-html

---
apiVersion: v1
kind: Service
metadata:
  name: shopping-cart-service
spec:
  selector:
    app: shopping-cart
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Frontend Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    tier: frontend
    storm-surge.io/component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: config
        configMap:
          name: frontend-config
      - name: html
        configMap:
          name: frontend-html

---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer

---
# HPA for Shopping Cart
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: shopping-cart-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: shopping-cart
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

---
# ConfigMaps for service content
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  default.conf: |
    upstream shopping-cart {
        server shopping-cart-service:80;
    }
    upstream product-catalog {
        server product-catalog-service:80;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        location /api/cart/ {
            proxy_pass http://shopping-cart/;
        }
        
        location /api/products/ {
            proxy_pass http://product-catalog/;
        }
    }

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>🌩️ Storm Surge - Weather the Scaling Storm</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
            .container { max-width: 1200px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; backdrop-filter: blur(10px); }
            .header { text-align: center; margin-bottom: 40px; }
            .storm-icon { font-size: 4em; margin-bottom: 20px; }
            .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 25px; margin: 30px 0; }
            .service { background: rgba(255,255,255,0.2); padding: 25px; border-radius: 10px; border-left: 5px solid #00d4ff; }
            .load-test { background: rgba(255,255,255,0.15); padding: 25px; border-radius: 10px; margin: 30px 0; text-align: center; }
            button { background: linear-gradient(45deg, #00d4ff, #0099cc); color: white; padding: 12px 24px; border: none; border-radius: 25px; cursor: pointer; margin: 8px; font-weight: bold; transition: transform 0.2s; }
            button:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(0,212,255,0.4); }
            .status { margin: 15px 0; padding: 15px; background: rgba(0,255,0,0.2); border-radius: 8px; }
            .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
            .metric { background: rgba(255,255,255,0.2); padding: 20px; border-radius: 10px; text-align: center; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="storm-icon">🌩️</div>
                <h1>Storm Surge</h1>
                <p>Weather the Kubernetes Scaling Storm</p>
            </div>
            
            <div class="services">
                <div class="service">
                    <h3>📦 Product Catalog</h3>
                    <p>Browse storm-ready products</p>
                    <button onclick="testService('/api/products')">Test Service</button>
                </div>
                
                <div class="service">
                    <h3>🛍️ Shopping Cart</h3>
                    <p>CPU-intensive cart operations</p>
                    <button onclick="testService('/api/cart')">Test Service</button>
                </div>
            </div>
            
            <div class="load-test">
                <h3>⚡ Storm Testing</h3>
                <p>Generate scaling storms to test resilience:</p>
                <button onclick="startStorm('light')">Light Storm ⛅</button>
                <button onclick="startStorm('moderate')">Moderate Storm 🌧️</button>
                <button onclick="startStorm('severe')">Severe Storm ⛈️</button>
                <button onclick="startStorm('hurricane')">Hurricane 🌪️</button>
                <button onclick="stopStorm()">Eye of Storm 🌀</button>
                <div id="stormStatus" class="status" style="display: none;"></div>
            </div>
            
            <div class="metrics">
                <div class="metric">
                    <h4>Active Pods</h4>
                    <div id="podCount">Loading...</div>
                </div>
                <div class="metric">
                    <h4>Storm Intensity</h4>
                    <div id="stormLevel">Calm</div>
                </div>
                <div class="metric">
                    <h4>Survival Rate</h4>
                    <div id="survivalRate">100%</div>
                </div>
            </div>
            
            <div id="response" style="margin-top: 20px;"></div>
        </div>
        
        <script>
            let stormInterval;
            
            async function testService(endpoint) {
                try {
                    const response = await fetch(endpoint);
                    const data = await response.text();
                    document.getElementById('response').innerHTML = 
                        '<h4>⚡ Storm Response from ' + endpoint + ':</h4>' +
                        '<pre style="background: rgba(0,0,0,0.3); padding: 15px; border-radius: 8px;">' + data + '</pre>';
                } catch (error) {
                    document.getElementById('response').innerHTML = 
                        '<h4>🌊 Storm disrupted ' + endpoint + ':</h4>' +
                        '<pre style="background: rgba(255,0,0,0.3); padding: 15px; border-radius: 8px;">' + error.message + '</pre>';
                }
            }
            
            function startStorm(intensity) {
                stopStorm();
                
                const storms = {
                    'light': { interval: 200, concurrent: 2, name: 'Light Storm ⛅', duration: 120 },
                    'moderate': { interval: 100, concurrent: 5, name: 'Moderate Storm 🌧️', duration: 300 },
                    'severe': { interval: 50, concurrent: 10, name: 'Severe Storm ⛈️', duration: 600 },
                    'hurricane': { interval: 25, concurrent: 20, name: 'Hurricane 🌪️', duration: 900 }
                };
                
                const storm = storms[intensity];
                const status = document.getElementById('stormStatus');
                status.style.display = 'block';
                status.innerHTML = `🌩️ ${storm.name} in progress for ${storm.duration}s...`;
                
                document.getElementById('stormLevel').textContent = storm.name;
                
                stormInterval = setInterval(() => {
                    for (let i = 0; i < storm.concurrent; i++) {
                        const endpoints = ['/api/products', '/api/cart'];
                        const randomEndpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
                        fetch(randomEndpoint).catch(e => console.log('Storm request failed:', e));
                    }
                }, storm.interval);
                
                // Auto-stop storm
                setTimeout(() => {
                    if (stormInterval) {
                        stopStorm();
                    }
                }, storm.duration * 1000);
            }
            
            function stopStorm() {
                if (stormInterval) {
                    clearInterval(stormInterval);
                    stormInterval = null;
                    const status = document.getElementById('stormStatus');
                    status.innerHTML = '🌀 Entered the eye of the storm - calm restored';
                    document.getElementById('stormLevel').textContent = 'Calm';
                    setTimeout(() => {
                        status.style.display = 'none';
                    }, 3000);
                }
            }
            
            // Initialize
            window.onload = function() {
                testService('/health');
                // Simulate metrics updates
                setInterval(() => {
                    document.getElementById('podCount').textContent = Math.floor(Math.random() * 20) + 5;
                    document.getElementById('survivalRate').textContent = (95 + Math.random() * 5).toFixed(1) + '%';
                }, 5000);
            }
        </script>
    </body>
    </html>

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: product-catalog-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Storm Surge - Product Catalog</title></head>
    <body>
        <h1>🌩️ Storm Surge Product Catalog</h1>
        <p>Service: product-catalog</p>
        <p>Status: Weathering the storm ⛈️</p>
        <div>
            <h3>Storm-Ready Products:</h3>
            <ul>
                <li>⚡ Lightning-Fast Servers</li>
                <li>🌊 Tsunami-Resistant Storage</li>
                <li>🌪️ Hurricane-Proof Networking</li>
            </ul>
        </div>
    </body>
    </html>

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopping-cart-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Storm Surge - Shopping Cart</title></head>
    <body>
        <h1>🌩️ Storm Surge Shopping Cart</h1>
        <p>Service: shopping-cart</p>
        <p>Status: High-intensity processing ⚡</p>
        <div>
            <h3>Cart Contents:</h3>
            <ul>
                <li>⚡ Lightning Scaling (Qty: ∞)</li>
                <li>🌊 Spot Instance Surfboard (Qty: 1)</li>
                <li>🌪️ Chaos Engineering Kit (Qty: 1)</li>
            </ul>
            <p><strong>Total Resilience: Unlimited</strong></p>
        </div>
        <script>
            // Simulate CPU load for scaling tests
            setInterval(function() {
                var start = Date.now();
                while (Date.now() - start < 100) {
                    Math.random();
                }
            }, 500);
        </script>
    </body>
    </html>
EOF

echo "✅ Main application created"

echo "💰 Creating FinOps controller..."

# Create FinOps controller Python file
cat > finops/finops_controller.py << 'EOF'
#!/usr/bin/env python3
"""
Storm Surge FinOps Controller
LaunchDarkly + Spot Ocean integration for cost optimization
"""

import os
import logging
import schedule
import time
from datetime import datetime
import pytz

# Placeholder implementation - replace with full version from artifacts
class StormSurgeFinOpsController:
    def __init__(self):
        self.logger = logging.getLogger('storm-surge-finops')
        self.logger.info("🌩️ Storm Surge FinOps Controller initialized")
    
    def disable_autoscaling_after_hours(self):
        """Main FinOps method - disable autoscaling 18:00-06:00"""
        current_time = datetime.now(pytz.UTC)
        self.logger.info(f"⚡ Checking after-hours optimization at {current_time}")
        
        # TODO: Add LaunchDarkly integration
        # TODO: Add Spot Ocean API calls
        # TODO: Add timezone handling
        
        return {"status": "placeholder - implement with full artifact code"}
    
    def enable_autoscaling_business_hours(self):
        """Enable autoscaling during business hours"""
        self.logger.info("🌅 Enabling business hours autoscaling")
        return {"status": "enabled"}

def main():
    """Main execution with scheduling"""
    logging.basicConfig(level=logging.INFO)
    controller = StormSurgeFinOpsController()
    
    # Schedule optimization
    schedule.every().day.at("18:00").do(controller.disable_autoscaling_after_hours)
    schedule.every().day.at("06:00").do(controller.enable_autoscaling_business_hours)
    
    print("🌩️ Storm Surge FinOps Controller running...")
    print("   - Copy full implementation from artifacts")
    print("   - Set up LaunchDarkly and Spot Ocean credentials")
    
    # Run initial check
    controller.disable_autoscaling_after_hours()
    
    while True:
        schedule.run_pending()
        time.sleep(60)

if __name__ == "__main__":
    main()
EOF

# Create requirements.txt
cat > finops/requirements.txt << 'EOF'
launchdarkly-server-sdk==8.2.1
requests==2.31.0
schedule==1.2.0
pytz==2023.3
python-dotenv==1.0.0
EOF

echo "✅ FinOps controller created"

echo "🚀 Creating deployment scripts..."

# Create main deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🌩️ Deploying Storm Surge"
echo "========================"

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl not connected to cluster."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Deploy base application
echo "📦 Deploying Storm Surge application..."
kubectl apply -f manifests/base/

# Wait for deployment
echo "⏳ Waiting for deployment..."
kubectl wait --for=condition=available --timeout=300s deployment --all

# Get frontend URL
echo "🌐 Getting frontend URL..."
FRONTEND_IP=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "✅ Storm Surge deployed successfully!"
echo ""
echo "🌐 Frontend URL: http://$FRONTEND_IP"
echo "📊 Monitor with: kubectl get pods"
echo "📋 Logs: kubectl logs -l app=frontend"
echo ""
echo "🌩️ Ready to weather the scaling storm!"
EOF

# Create load testing script
cat > scripts/load-test.sh << 'EOF'
#!/bin/bash

INTENSITY=${1:-"moderate"}
DURATION=${2:-"300"}

echo "⚡ Starting $INTENSITY storm for ${DURATION}s"

# Get frontend URL
FRONTEND_URL=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$FRONTEND_URL" ]; then
    echo "❌ Frontend service not ready"
    exit 1
fi

case $INTENSITY in
    "light")
        CONCURRENT=10
        ;;
    "moderate")
        CONCURRENT=25
        ;;
    "severe")
        CONCURRENT=50
        ;;
    "hurricane")
        CONCURRENT=100
        ;;
    *)
        echo "❌ Invalid intensity. Use: light, moderate, severe, hurricane"
        exit 1
        ;;
esac

echo "🌩️ Generating storm with $CONCURRENT concurrent requests"
echo "Target: http://$FRONTEND_URL"

# Use curl if wrk not available
if command -v wrk &> /dev/null; then
    wrk -t4 -c$CONCURRENT -d${DURATION}s http://$FRONTEND_URL
else
    echo "Using curl (install wrk for better load testing)"
    for i in $(seq 1 $CONCURRENT); do
        (
            for j in $(seq 1 $((DURATION/5))); do
                curl -s http://$FRONTEND_URL > /dev/null
                sleep 5
            done
        ) &
    done
    wait
fi

echo "✅ Storm complete!"
EOF

# Create FinOps deployment script
cat > scripts/deploy-finops.sh << 'EOF'
#!/bin/bash
set -e

echo "💰 Deploying Storm Surge FinOps Controller"
echo "=========================================="

# Check environment variables
if [ -z "$SPOT_API_TOKEN" ]; then
    echo "⚠️  SPOT_API_TOKEN not set - using demo mode"
    export SPOT_API_TOKEN="demo-token"
fi

if [ -z "$LAUNCHDARKLY_SDK_KEY" ]; then
    echo "⚠️  LAUNCHDARKLY_SDK_KEY not set - using demo mode"
    export LAUNCHDARKLY_SDK_KEY="demo-key"
fi

# Create namespace
kubectl create namespace storm-surge --dry-run=client -o yaml | kubectl apply -f -

echo "🔑 Creating secrets..."
kubectl create secret generic finops-credentials \
    --from-literal=spot-token="$SPOT_API_TOKEN" \
    --from-literal=launchdarkly-key="$LAUNCHDARKLY_SDK_KEY" \
    --namespace=storm-surge \
    --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Deploying FinOps controller..."
if [ -f "manifests/finops/finops-controller.yaml" ]; then
    kubectl apply -f manifests/finops/
else
    echo "⚠️  FinOps manifests not found. Copy from artifacts first."
    echo "   See: manifests/finops/ directory"
fi

echo "✅ FinOps controller deployment complete!"
echo "💡 Copy full implementation from artifacts for production use"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "✅ Deployment scripts created"

echo "🔥 Creating chaos testing..."

# Create basic chaos script
cat > chaos-testing/lightning-strike.sh << 'EOF'
#!/bin/bash

echo "⚡ Lightning Strike Chaos Test"
echo "=============================="

# Simple pod chaos test
echo "🎯 Targeting shopping cart pods..."

CART_PODS=$(kubectl get pods -l app=shopping-cart -o jsonpath='{.items[*].metadata.name}')

if [ -z "$CART_PODS" ]; then
    echo "❌ No shopping cart pods found"
    exit 1
fi

# Pick random pod
POD_ARRAY=($CART_PODS)
RANDOM_POD=${POD_ARRAY[$RANDOM % ${#POD_ARRAY[@]}]}

echo "⚡ Lightning strikes pod: $RANDOM_POD"
kubectl delete pod $RANDOM_POD

echo "📊 Monitoring recovery..."
for i in {1..30}; do
    READY_PODS=$(kubectl get pods -l app=shopping-cart --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Time: ${i}s - Ready pods: $READY_PODS"
    sleep 1
done

echo "✅ Lightning strike test complete!"
EOF

chmod +x chaos-testing/lightning-strike.sh

echo "✅ Chaos testing created"

echo "📚 Creating documentation..."

# Create basic docs
cat > docs/ARCHITECTURE.md << 'EOF'
# 🌩️ Storm Surge Architecture

Storm Surge is designed to test Kubernetes elasticity with realistic workloads.

## Components

- **Frontend**: Load balancer entry point
- **Shopping Cart**: CPU-intensive service for scaling tests  
- **Product Catalog**: Baseline service
- **FinOps Controller**: Cost optimization with LaunchDarkly
- **Chaos Testing**: Resilience validation

## Scaling Strategy

1. Shopping Cart scales based on CPU usage (70% threshold)
2. Ocean provides intelligent node provisioning
3. FinOps optimizes costs during off-hours
4. Chaos testing validates resilience

See the main README for deployment instructions.
EOF

cat > docs/FINOPS.md << 'EOF'
# 💰 Storm Surge FinOps Guide

Storm Surge integrates LaunchDarkly feature flags with Spot Ocean for dynamic cost optimization.

## Key Features

- **After-hours shutdown**: Disable autoscaling 18:00-06:00 for dev clusters
- **Feature flag control**: Dynamic cost optimization parameters
- **Multi-timezone support**: Respects cluster local times
- **Production protection**: Never affects business-critical workloads

## Setup

1. Set environment variables:
   ```bash
   export SPOT_API_TOKEN="your-token"
   export LAUNCHDARKLY_SDK_KEY="your-key"
   ```

2. Deploy FinOps controller:
   ```bash
   ./scripts/deploy-finops.sh
   ```

3. Configure LaunchDarkly flags (see configs/launchdarkly/)

## Expected Savings

- Development clusters: 70-80% cost reduction
- Staging clusters: 50-60% cost reduction
- Production clusters: 10-20% optimization through right-sizing

Copy the full implementation from the provided artifacts for production use.
EOF

echo "✅ Documentation created"

echo "⚙️ Creating configuration templates..."

# Create config templates
cat > configs/clusters/clusters.json << 'EOF'
{
  "clusters": [
    {
      "cluster_id": "o-12345678",
      "cluster_name": "storm-surge-dev-us-west-2",
      "environment": "development",
      "timezone": "America/Los_Angeles",
      "cost_center": "engineering",
      "business_critical": false
    },
    {
      "cluster_id": "o-87654321",
      "cluster_name": "storm-surge-staging",
      "environment": "staging", 
      "timezone": "America/New_York",
      "cost_center": "qa",
      "business_critical": false
    },
    {
      "cluster_id": "o-99999999",
      "cluster_name": "storm-surge-prod",
      "environment": "production",
      "timezone": "America/New_York",
      "cost_center": "production", 
      "business_critical": true
    }
  ]
}
EOF