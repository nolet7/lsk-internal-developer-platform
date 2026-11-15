#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_ID:?Set PROJECT_ID}"
: "${REGION:?Set REGION}"
: "${IMAGE:?Set IMAGE digest}"
: "${SERVICE_ACCOUNT:?Set runtime service account email}"
: "${SQL_CONNECTION:?Set SQL instance connection name}"
: "${DATABASE_SECRET:?Set database Secret Manager ID}"
: "${JOB_NAME:?Set Cloud Run job name}"
# Optional Direct VPC egress for a private-only Cloud SQL instance.
# Both values must be set together, typically using Terraform outputs.
NETWORK_FLAGS=()
if [[ -n "${PRIVATE_VPC_NETWORK:-}" || -n "${PRIVATE_VPC_SUBNET:-}" ]]; then
  : "${PRIVATE_VPC_NETWORK:?Set PRIVATE_VPC_NETWORK for private SQL}"
  : "${PRIVATE_VPC_SUBNET:?Set PRIVATE_VPC_SUBNET for private SQL}"
  NETWORK_FLAGS=(--network "$PRIVATE_VPC_NETWORK" --subnet "$PRIVATE_VPC_SUBNET" --vpc-egress "private-ranges-only")
fi
gcloud run jobs deploy "$JOB_NAME" "${NETWORK_FLAGS[@]}" \
  --project "$PROJECT_ID" --region "$REGION" \
  --image "$IMAGE" \
  --service-account "$SERVICE_ACCOUNT" \
  --set-cloudsql-instances "$SQL_CONNECTION" \
  --set-secrets "DATABASE_URL=$DATABASE_SECRET:latest" \
  --command python --args scripts/migrate.py \
  --max-retries 0 --task-timeout 600s
echo "Migration job defined but NOT executed; inspect then execute explicitly."
echo "gcloud run jobs execute $JOB_NAME --project $PROJECT_ID --region $REGION --wait"
