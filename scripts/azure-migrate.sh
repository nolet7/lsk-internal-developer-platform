#!/usr/bin/env bash
set -euo pipefail
# Define a separate Azure Container Apps migration job; no execution by default.
for name in RESOURCE_GROUP APP_ENVIRONMENT JOB_NAME IMAGE ACR_SERVER MANAGED_IDENTITY_ID DATABASE_URL_SECRET_ID; do
  [[ -n "${!name:-}" ]] || { echo "Missing $name" >&2; exit 1; }
done
: "${EXECUTE_MIGRATION:=false}"
command -v az >/dev/null || { echo "Azure CLI required" >&2; exit 1; }
az containerapp job create   --name "$JOB_NAME" --resource-group "$RESOURCE_GROUP"   --environment "$APP_ENVIRONMENT" --trigger-type Manual   --replica-timeout 1800 --replica-retry-limit 0   --replica-completion-count 1 --parallelism 1   --cpu 0.5 --memory 1Gi   --image "$IMAGE" --container-name api   --mi-user-assigned "$MANAGED_IDENTITY_ID"   --registry-server "$ACR_SERVER" --registry-identity "$MANAGED_IDENTITY_ID"   --secrets "database-url=keyvaultref:$DATABASE_URL_SECRET_ID,identityref:$MANAGED_IDENTITY_ID"   --env-vars "DATABASE_URL=secretref:database-url"   --command python --args scripts/migrate.py
echo "Created migration job $JOB_NAME; no migration was executed."
if [[ "$EXECUTE_MIGRATION" == "true" ]]; then
  echo "Starting explicitly approved Alembic migration..."
  az containerapp job start --name "$JOB_NAME" --resource-group "$RESOURCE_GROUP"
  echo "Monitor execution state and exit code in Azure before admitting traffic."
fi
