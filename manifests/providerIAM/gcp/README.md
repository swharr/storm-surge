# GCP IAM Policies for Storm Surge

This directory contains IAM roles and policies required for managing GKE clusters and associated resources.

## Files

### gke-admin-role.yaml
Custom IAM role definition that grants comprehensive permissions for GKE cluster administration, including:
- Full GKE cluster and node pool management
- Compute Engine resources (instances, networks, load balancers)
- IAM service account management
- Cloud KMS for encryption
- Logging and monitoring
- Storage for backups

## Usage

### Create Custom Role

```bash
# Create the custom role at project level
gcloud iam roles create stormSurgeGKEAdmin \
  --project=PROJECT_ID \
  --file=gke-admin-role.yaml

# Or create at organization level
gcloud iam roles create stormSurgeGKEAdmin \
  --organization=ORGANIZATION_ID \
  --file=gke-admin-role.yaml
```

### Create Service Account with Role

```bash
# Set your project ID
export PROJECT_ID=your-project-id

# Create service account
gcloud iam service-accounts create storm-surge-gke-admin \
  --display-name="Storm Surge GKE Admin" \
  --project=$PROJECT_ID

# Grant the custom role to the service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="projects/$PROJECT_ID/roles/stormSurgeGKEAdmin"

# Create and download key
gcloud iam service-accounts keys create storm-surge-gke-key.json \
  --iam-account=storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com
```

### Grant to User Account

```bash
# Grant custom role to a user
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:admin@example.com" \
  --role="projects/$PROJECT_ID/roles/stormSurgeGKEAdmin"
```

### Using Predefined Roles (Alternative)

If you prefer using predefined roles instead of custom role:

```bash
# Required predefined roles for full GKE administration
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

## Authentication

### Using Service Account Key

```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="path/to/storm-surge-gke-key.json"

# Or configure gcloud
gcloud auth activate-service-account --key-file=storm-surge-gke-key.json
```

### Using Workload Identity (Recommended for Production)

```bash
# Enable Workload Identity on cluster
gcloud container clusters update CLUSTER_NAME \
  --workload-pool=$PROJECT_ID.svc.id.goog

# Create Kubernetes service account
kubectl create serviceaccount storm-surge-sa \
  --namespace default

# Bind Kubernetes SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[default/storm-surge-sa]"

# Annotate Kubernetes SA
kubectl annotate serviceaccount storm-surge-sa \
  iam.gke.io/gcp-service-account=storm-surge-gke-admin@$PROJECT_ID.iam.gserviceaccount.com
```

## Security Best Practices

1. **Service Account Keys**: Rotate keys regularly and use Workload Identity when possible
2. **Least Privilege**: Review permissions and remove any that aren't needed
3. **Resource Constraints**: Consider adding condition-based access for specific resources
4. **Audit Logging**: Enable Cloud Audit Logs for all admin activities
5. **Organization Policies**: Apply organization-level constraints for additional security

## Required APIs

Ensure these APIs are enabled in your project:

```bash
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudkms.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com
```