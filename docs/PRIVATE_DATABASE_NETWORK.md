# LSK private Cloud SQL deployment — multinational regional lab

## Implemented network design

An **opt-in** `enable_private_sql=true` Terraform setting provisions a dedicated custom-mode regional VPC/subnet, Private Service Access IP range and service networking connection. It sets Cloud SQL public IPv4 off and assigns a private network, and configures Cloud Run Direct VPC egress to private ranges via the subnet. The DB remains accessible through the Cloud SQL connector mount at `/cloudsql`, with the runtime service identity granted `cloudsql.client`.

Official references:
- https://docs.cloud.google.com/sql/docs/postgres/configure-private-services-access
- https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc

These changes are validated through GitHub Terraform CI but have **not been applied to a live GCP project or subjected to a network penetration test**.

## Choose a regional project and review costs

Production-like lab example using synthetic data:

```hcl
environment = "prod"
region = "us-central1"
enable_private_sql = true
private_subnet_cidr = "10.90.0.0/24"
db_availability_type = "REGIONAL"
db_tier = "db-custom-2-7680"
tenant_region_policy = {
  "synthetic-tenant-us" = ["us-central1"]
}
```

`prod` now has a Terraform precondition: **private SQL + REGIONAL availability + non-micro tier**. For cheaper testing, keep `environment="lab"` and review costs before enabling advanced options. Cloud SQL HA and reserved private network ranges can increase charges and complicate teardown. Budget alerts are not spending caps. Use a separate state bucket and credentials per region.

The SQL subnet must be non-overlapping with all connected corporate networks; use at least /26 for Direct VPC egress. Private Service Access is peering; it is *not* Private Service Connect.

## Migrate schema over the same VPC

The one-off migration Job accepts two optional environment variables:

```bash
export PRIVATE_VPC_NETWORK="$(terraform -chdir=infra output -raw private_vpc_name)"
export PRIVATE_VPC_SUBNET="$(terraform -chdir=infra output -raw private_subnet_name)"
```

Also set the required `PROJECT_ID`, `REGION`, immutable `IMAGE`, `SERVICE_ACCOUNT`, `SQL_CONNECTION`, `DATABASE_SECRET` and `JOB_NAME` described in `scripts/deploy-migration-job.sh`. Then run:

```bash
bash scripts/deploy-migration-job.sh
```

This only **defines** the job. Inspect it in GCP and independently execute it when approved. It runs Alembic, not `create_all`. Use the [schema migration checklist](SCHEMA_MIGRATION.md) before migrating any pre-existing tables.

## Network and data-residency risks to review

- A public Cloud Run URL may still exist; Cloud Run invoker IAM is restricted but the enterprise edge gateway, private ingress, WAF, rate limiting and firewall rules are not configured by this module.
- The allowed-region app gate validates a signed `data_region` and tenant allowlist, but does not regulate storage in backups, analytics, model prompts, or logs. Those require separate governance and configuration.
- Cloud Run Direct VPC egress can affect cold starts and subnet IP capacity; perform smoke, load and failure testing.
- Separate projects/VPCs per jurisdiction are a *reference pattern*; enterprises using Shared VPC must adapt IAM, subnet permissions and address reservations.
- Failover, point-in-time restore, regional replication, audit retention, key rotation, security testing and compliance signoff are still outstanding operational acceptance gates.

No cloud resources were provisioned by committing this code.
