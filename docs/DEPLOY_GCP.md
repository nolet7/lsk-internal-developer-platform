# GCP lab deployment — LSK IDP

## Boundaries
This is an independent fictional portfolio lab, not a real company deployment. Use synthetic data. Creating cloud resources may consume credits; Cloud SQL is billable while provisioned. Set a GCP Billing budget first (alerts **do not cap** spending). The Terraform defaults include deletion protection; review plans before applying or destroying.

## 1 — Environment
Choose a dedicated GCP project for this lab, and install gcloud, Terraform >=1.6 and Docker. Never commit credentials.

```bash
export PROJECT_ID="YOUR_GCP_PROJECT_ID"
export REGION="us-central1"
export TF_STATE_BUCKET="YOUR_UNIQUE_STATE_BUCKET"
gcloud config set project "$PROJECT_ID"
gcloud services enable storage.googleapis.com artifactregistry.googleapis.com
```

## 2 — Terraform state
Create a GCS state bucket with uniform access and versioning, and grant access only to the deployer identity. **Terraform state contains secrets in cleartext**, despite sensitive variable masking.

```bash
gcloud storage buckets create "gs://$TF_STATE_BUCKET" --project "$PROJECT_ID" --location "$REGION" --uniform-bucket-level-access
gcloud storage buckets update "gs://$TF_STATE_BUCKET" --versioning
cd infra
terraform init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="prefix=lsk-idp/lab"
```

## 3 — Bootstrap registry and publish image
The initial image must exist before a Cloud Run service can be created. Configure all required non-secret Terraform variables and `TF_VAR_db_password` from a secure source. Bootstrap only the Artifact Registry repository, then use normal full plans.

```bash
terraform plan -target=google_artifact_registry_repository.images -out=registry.tfplan
terraform apply registry.tfplan
```

Create a dedicated GitHub deployer service account with narrow Artifact Registry write access. Configure GitHub Workload Identity Federation constrained to this exact repository and allowed branch/environment. In GitHub environment `gcp-lab`, configure:
`GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_DEPLOYER_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`, `GCP_REGION`, `GCP_ARTIFACT_REPOSITORY`.
Trigger `Publish Image (Manual)`. Obtain its immutable digest and set Terraform's `image` variable. Do not use personal service-account keys.

## 4 — Provision approved infrastructure
After a human reviews the complete plan:

```bash
terraform plan -out=deploy.tfplan
terraform apply deploy.tfplan
terraform output service_uri
```

No public invoker binding is created by Terraform. Grant Cloud Run invoker only to intended testers or a trusted gateway; a separate OIDC access token with `tenant_id` and API scopes is required. The Cloud SQL public IP setting supports a lab Auth Proxy connection, but **this is not a private-IP-only architecture**. Restrict ingress and move to a private networking pattern before a production deployment.

## 5 — Database schema and smoke test
The API does not create tables at web startup. Define a one-off Cloud Run Job using `scripts/deploy-migration-job.sh`, the same runtime identity, Cloud SQL instance, and Secret Manager secret; run it only after reviewing its configuration. `create_all` is initial lab bootstrap, not versioned production migrations.

Use `/healthz`, `/readyz`, `/v1/catalog`, and the request/approval/plan workflow with a real signed OIDC JWT. Confirm expired tokens, missing scopes, separate tenants, self-approval rejection and prod-specific authorization.

## 6 — Tear down
Verify that generated records are synthetic and no shared infrastructure depends on the stack. Disable deletion protection with a reviewed Terraform apply, destroy the stack and inspect remaining Cloud SQL, Secret Manager, Artifact Registry, and GCS state objects. Remove remote-state resources separately when appropriate.

## Further hardening
Production requires migrations, private connectivity, disaster recovery drills, immutable attestation, API rate limits, OIDC security tests, authorization threat model, policy-as-code, GitOps PR integration, platform cost quotas, audit integrity and SLO dashboards.
