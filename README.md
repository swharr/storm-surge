# 🌩️ Storm Surge: Kubernetes Elasticity + FinOps Testing with Spot Ocean + LaunchDarkly

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![LaunchDarkly](https://img.shields.io/badge/LaunchDarkly-Feature--Flags-blue?style=for-the-badge)
![Flexera Spot](https://img.shields.io/badge/Flexera--Spot-Ocean-blue?style=for-the-badge)

A FinOps-focused microservices demo app for testing real-time scaling, feature flag toggling, and infrastructure cost optimization — designed to run on **GKE**, **EKS**, or **AKS** with **Spot Ocean** and **LaunchDarkly**.

---

## 🚀 Highlights

- ⚙️ Integrated with [LaunchDarkly](https://launchdarkly.com) to simulate cost-aware infrastructure control
- 🌊 Works with [Spot Ocean](https://spot.io) for dynamic right-sizing and node pool optimization
- 🛠️ Deployable to GCP, AWS, or Azure via a unified CLI wrapper
- 📈 Tracks infrastructure impact of feature flag changes
- 💥 Supports chaos testing, right-sizing, load bursts, and monitoring

---

## 🧪 How It Works

You use LaunchDarkly feature flags (like `enable-cost-optimizer`) to toggle infrastructure behavior, which is reflected in your app and metrics.

This repo ties application behavior directly to cost outcomes.

---

## 🧰 Quickstart

```bash
git clone https://github.com/swharr/storm-surge.git
cd ocean-surge
./scripts/deploy.sh --provider=gke   # or eks | aks | all
```

You’ll be prompted to enter your LaunchDarkly credentials if not already set in a `.env` file.

---

## ⚙️ LaunchDarkly Setup

1. Create a boolean flag: `enable-cost-optimizer`
2. Get your **Client-side ID** from LaunchDarkly (under your environment)
3. Provide it to the deploy script or save it to `.env`:

```bash
export LAUNCHDARKLY_CLIENT_ID="your-client-id"
```

4. Toggle the flag → see UI and infra behavior update in real time

---

## ☁️ Cloud Provider Support

| Provider | Script                              | Requirements          |
|----------|-------------------------------------|------------------------|
| GKE      | `scripts/providers/gke.sh`          | `gcloud`, enabled APIs |
| EKS      | `scripts/providers/eks.sh`          | `aws`, `eksctl`        |
| AKS      | `scripts/providers/aks.sh`          | `az`, login session    |

---

## 🗃️ Project Structure

```
ocean-surge/
├── scripts/
│   ├── deploy.sh
│   └── providers/
│       ├── gke.sh
│       ├── eks.sh
│       └── aks.sh
├── manifests/
├── frontend/
├── logs/
├── .env
└── README.md
```

---

## 🧠 Future Features

- [ ] OpenFeature + flagd support
- [ ] Dynamic Spot Ocean reconfiguration via Spot API
- [ ] GitOps flow via ArgoCD
- [ ] FinOps Dashboard plugin

---

## 📞 Support

- 📖 [Flexera Docs](https://docs.spot.io)
- 💬 [Spot Slack](https://community.spot.io)
- 🐛 GitHub Issues

---

Made with ❤️ for the FinOps Developer Community