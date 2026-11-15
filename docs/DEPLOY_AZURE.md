# LSK Azure environment-specific release architecture

**Host:** Azure Container Apps in a private, VNet-integrated internal environment with a managed identity, ACR and Key Vault secret reference. **Database:** PostgreSQL Flexible Server in a delegated private subnet, private DNS, separate database; `prod` requires zone redundancy and 2+ replicas.

## Before deployment
1. Choose separate Azure subscriptions or controlled landing-zone resource groups for dev, staging and prod. Define compliant `location`, VNet CIDR, data classification and budgets.
2. Set up a distinct encrypted Azure Storage Terraform state container and GitHub OIDC Federated Credential limited to the repository environment, with minimum-scoped RBAC.
3. Pre-create a protected Azure Key Vault and DB connection-string secret; configure its access permissions for the managed identity. The **app** must use a dedicated restricted database user, not the server admin user. The DB hostname is only known after creating the flexible server. Bootstrap database and restricted user in a reviewed two-phase operation; then set Key Vault secret. The first app plan cannot succeed without its image/secret.
4. Bootstrap ACR, build/push Docker image by immutable digest, and pass its address into a reviewed plan.
5. For `prod`, select `GP_Standard_D2s_v3` or another valid zone-redundant region-supported SKU with at least 2 replicas, not `B_Standard_B1ms`.
6. Run `terraform -chdir=infra/azure init` with private `azurerm` backend storage/account/container/key, then plan using `-var-file=../../environments/azure/<env>.tfvars`. Apply only after platform security approval.
7. Run Alembic through a **separate Azure Container Apps Job** in the same VNet environment and runtime identity, with the DB Key Vault secret, before routing traffic.
8. Test from trusted VNet access (the Container Apps environment's LB is internal). Validate regional claims, 403 cross-region, 401 bad JWT, private DNS reachability, backups, rollout/rollback and SLOs.

## Security boundaries and gaps
- A Key Vault secret *reference* avoids storing the database URL plaintext in Terraform code, but the **admin password used to create PostgreSQL still enters Terraform state**. Use a secured, scoped remote state and plan for Entra passwordless auth.
- The Container App managed identity has ACR pull and Key Vault Secrets User at the vault scope. For strict isolation use a dedicated vault per service/environment.
- Corporate gateway, private endpoint choices, egress firewall rules, WAF, OIDC federation for Terraform actions, secret rotation, disaster-recovery proof and compliance approval remain organization-specific.
- The GCP-specific Gemini/Cloud Logging advisory endpoints are **not** Azure-native. They remain disabled unless explicitly configured, and do not demonstrate Azure Monitor agents.
- No Azure resources were deployed or verified by these commits. Run plan/apply and network tests before calling the stack production ready.
