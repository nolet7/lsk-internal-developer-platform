# LSK Azure — dev, staging and production release contract

**Cloud-native branch:** `feature/azure`. **Runtime:** VNet-integrated internal Azure Container Apps and privately delegated PostgreSQL Flexible Server, Azure Container Registry, Key Vault reference, Entra managed identity and Log Analytics. **IaC:** `infra/azure/`. **Profiles:** `environments/azure/{dev,staging,prod}.tfvars`.

## Protected environment variables

Create `azure-dev`, `azure-staging`, `azure-prod` GitHub environments with required reviewers and workload-identity federation to separately scoped subscriptions/resources. Variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_LOCATION`, `AZURE_VNET_CIDR`, `AZURE_STATE_RESOURCE_GROUP`, `AZURE_STATE_STORAGE_ACCOUNT`, `AZURE_STATE_CONTAINER`, `AZURE_KEY_VAULT_NAME`, `AZURE_KEY_VAULT_RESOURCE_GROUP`, `AZURE_DATABASE_URL_SECRET_ID`, `AZURE_ACR_NAME`, `AZURE_ACR_LOGIN_SERVER`, `AZURE_ACR_REPOSITORY`, `LSK_SERVICE_NAME`, `OIDC_ISSUER`, `OIDC_AUDIENCE`, `OIDC_JWKS_URL`, `TENANT_REGION_POLICY_JSON`, `MIGRATION_VERIFIED_DIGEST`, and for production `STAGING_VERIFIED_DIGEST`. Admin password is protected GitHub secret `DB_ADMIN_PASSWORD`.

**Access/IDP AI variants** also require `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT`, and `AZURE_AI_RESOURCE_ID`, with Entra `Cognitive Services OpenAI User` delegated to the runtime managed identity. IDP uses aggregated Azure Monitor logs rather than raw payloads.

## Release lifecycle

1. Prepare subscription/regional landing zone, encrypted Azure Blob Terraform remote state, Key Vault, constrained GitHub federated credential, policy-driven VNet CIDRs and cost guardrails. Private Container Apps ingress must be reachable from the corporate network to smoke-test.
2. Bootstrap ACR, PostgreSQL and a dedicated *nonadmin application database account*. Store its TLS-required `DATABASE_URL` in Key Vault, separate from Terraform. Because the database hostname only exists after provisioning, this is a reviewed **two-phase deployment**.
3. Publish the container with `Azure container build and provenance`; copy the immutable digest.
4. Manually dispatch `Azure CI and environment release` with `apply=false`, inspect the plan, IAM assignments, private DNS, zone availability and costs.
5. Run a one-off Alembic Azure Container Apps Job through `scripts/azure-migrate.sh` with approved credentials; script defines the job and runs it only when `EXECUTE_MIGRATION=true`. Verify job execution logs and final status.
6. Set `MIGRATION_VERIFIED_DIGEST` to the approved exact digest. Only then run `apply=true`. In production also set identical staging-confirmed `STAGING_VERIFIED_DIGEST`.
7. Test TLS ingress from the trusted VNet, regional claims and tenant scope, app health and PostgreSQL DNS, zone-failure response, backups, RPO/RTO, load performance, incident escalation and rollback.
8. Use staged revision/recovery controls for app rollback; schema rollbacks must be reviewed independently.

## Production safeguards and outstanding gates
Production Terraform requires 2+ replicas, a zone-redundant PostgreSQL configuration and a non-burstable DB tier. ACR Premium is used in production, Standard in nonproduction. Database public network access is disabled. Entra managed identity avoids registry and runtime API keys, but Terraform currently requires a PostgreSQL administrator password that enters state; move toward managed database authentication.

Azure OpenAI deployments, quota, and zone availability are subscription/region-specific and have not been live-validated. Regional legal approval, DNS/firewall routing, Key Vault private endpoint, runtime health, live recovery and compliance certification are outstanding.
