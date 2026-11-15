# LSK AWS — dev, staging and production release contract

**Cloud-native branch:** `feature/aws`. **Runtime:** internal HTTPS Application Load Balancer, private ECS Fargate tasks, private RDS PostgreSQL, VPC NAT, Secrets Manager, CloudWatch and ECR. **IaC:** `infra/aws/`. **Profiles:** `environments/aws/{dev,staging,prod}.tfvars`.

## Required protected GitHub environments

Set `aws-dev`, `aws-staging`, `aws-prod` with environment-only IAM roles and human reviewers. Required GitHub variables: `AWS_REGION`, `AWS_GITHUB_DEPLOY_ROLE_ARN`, `AWS_ECR_PUBLISH_ROLE_ARN`, `AWS_ECR_REPOSITORY`, `AWS_TF_STATE_BUCKET`, `AWS_VPC_CIDR`, `AWS_ACM_CERTIFICATE_ARN`, `AWS_ALLOWED_INGRESS_CIDRS_JSON`, `LSK_SERVICE_NAME`, `OIDC_ISSUER`, `OIDC_AUDIENCE`, `OIDC_JWKS_URL`, `TENANT_REGION_POLICY_JSON`, `MIGRATION_VERIFIED_DIGEST`, and for production `STAGING_VERIFIED_DIGEST`. Store `DB_PASSWORD` only in protected GitHub secrets.

**Access/IDP AI variants** additionally require `BEDROCK_MODEL_ID` and `BEDROCK_MODEL_ARN` for an approved, in-region Converse-capable model. Runtime IAM `bedrock:InvokeModel` is scoped to that ARN. IDP read-only operations triage uses CloudWatch bounded error metadata only.

## Release lifecycle

1. Provision an account-scoped encrypted S3 Terraform state bucket with locking, a restricted GitHub AWS OIDC role and approved VPC CIDR. Create ACM certificate and corporate routing/VPN/access to the internal ALB.
2. Bootstrap ECR before the first application build, using protected IaC. ECR tags are immutable.
3. Manually run `AWS container build and provenance` and capture the printed full `@sha256` URI. The build requests image SBOM and provenance.
4. Dispatch `AWS CI and environment release`, `apply=false`, with the same immutable image digest. Review the plan, costs, IAM and network topology in a change-control record.
5. For a **fresh database** create foundational resources first and migrate the schema with `scripts/aws-migrate.sh` from an approved one-off ECS Fargate task. Use `EXECUTE_MIGRATION=true` only after verification; migration output/exit code is checked.
6. Record `MIGRATION_VERIFIED_DIGEST` in the protected environment. Only then run `apply=true`. In production, the workflow additionally enforces `STAGING_VERIFIED_DIGEST` equality.
7. Run `/readyz`, scoped OIDC endpoint tests, resilience/load tests and recovery drills from a private network runner; verify ALB/TLS certificate and region/tenant claims.
8. Roll back to a previously verified task definition/image digest if safe. Schema downgrade is **not automatic**; use reviewed forward-fix and DB recovery procedures.

## Production safeguards and outstanding gates
Terraform requires 2+ ECS tasks, multi-AZ RDS, encryption, private networks, >=7-day backups, RDS deletion protection, TLS ALB. **No public ingress is created.** NAT gateways, RDS, ALB and service replicas incur charges. AWS Terraform currently receives a database password, so encrypted remote Terraform state contains credential material; replacing it with managed rotation and an app-scoped identity pattern is still a production security requirement.

Amazon Bedrock model availability and cost are region dependent. The LSK IDP retains a **request/approval/plan** workflow, not an automatic provisioning engine. AWS deployment plans have **not** been executed against a real account, and no regulatory certification is claimed.
