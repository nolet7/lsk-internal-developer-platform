# LSK AWS deployment — ECS Fargate / private RDS

## Environment separation
Use distinct AWS accounts (or explicitly approved boundaries) for dev/staging/prod, dedicated S3 state keys and DynamoDB/S3 native locking, GitHub environment approval rules, and OIDC-assumed deploy roles restricted by repository and environment. Each environment has an immutable ECR image digest and approved `tenant_region_policy` matching the chosen AWS region.

Environment profiles: `environments/aws/dev.tfvars`, `staging.tfvars`, `prod.tfvars`. Use `terraform -chdir=infra/aws init -backend-config=...` with your approved S3 bucket and key `lsk/<repo>/<env>.tfstate`. Account IDs, region, VPC CIDR, ACM certificate ARN, secrets, and image digest come from protected GitHub environments, never checked into Git.

## Bootstrap and deployment ordering
1. Pre-create the encrypted S3 state bucket, appropriate KMS and narrowly scoped GitHub OIDC deploy role. Set an AWS Budget (alerts do not enforce hard limits).
2. ECR repository must exist before pushing the first image. Bootstrap that repository separately via reviewed Terraform target and then switch to full plans.
3. Build the Dockerfile, push image by immutable digest and validate `/healthz` locally.
4. Confirm non-overlapping VPC CIDR, approved company inbound CIDRs, a validated ACM certificate, two available AZs and database credentials. Do not enable unrestricted `0.0.0.0/0` inbound to the internal ALB.
5. Run `terraform plan -var-file=../../environments/aws/<env>.tfvars`; apply only via protected deployment environment and approved artifact.
6. Run Alembic migrations in a **separate one-off ECS Fargate task**, using the same task definition, private subnets, runtime secret and migration command override. Run before directing traffic and record the database schema revision. Never auto-migrate from every web replica.
7. Smoke-test through your corporate network/VPN/private access gateway (the load balancer is internal). Prove regional/tenant isolation, IAM deny, rollback, backups and p95 SLOs.

**Production safeguards:** private RDS, database encryption, 2 AZ private subnets, optional multi-AZ RDS, SSL on ALB, runtime IAM, secret injection, CloudWatch, immutable image. Production precondition requires multiple tasks, Multi-AZ DB, DB deletion protection, backups and dedicated instance class.

**Unimplemented:** AWS-native Gemini advisory replacement, real AWS IAM/CloudWatch diagnostic agent (GCP-dependent endpoints remain scoped to GCP), RDS password rotation, audit immutability, formal DR drills, WAF/private ingress organization design, complete regulatory review. Production infrastructure must not use the synthetic password/state pattern as-is.
