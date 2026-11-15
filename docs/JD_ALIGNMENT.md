# LSK Internal Developer Platform — Senior AI Platform Engineer JD alignment

## Implemented now
- Service catalog for Cloud Run API, PostgreSQL and private connectivity **requests**, versioned golden-path metadata.
- Tenant-scoped FastAPI/OIDC permissions, request idempotency, approval/rejection workflow, additional prod approval scope, SQL audit trail.
- JSON GitOps plan export for approved templates (no automatic PR or deploy).
- Read-only Gemini explanation of allowlisted catalog entries, without authorizing changes.
- Terraform for hosting IDP on Cloud Run + Cloud SQL/Secret Manager, GitHub Actions build/CI.

## Mapping to Brixton role
- **Self-service platform:** strongest match. Developers discover standardized blueprints and submit governed requests. Real provisioning and service status callbacks are still missing.
- **Security/IAM:** JWT-scoped roles and separation of duties implemented. External identity group provisioning, ABAC, cross-project IAM review not yet done.
- **Networking:** a connectivity catalog **request type**, a separately validated VPC/subnet/optional NAT/Private Service Access Terraform blueprint now exists under `blueprints/network/`, but no IDP-to-blueprint automation, PSC endpoint, firewall hardening or running GCP deployment is implemented.
- **Databases:** managed PostgreSQL catalog is a request description, not an automatic Cloud SQL instance per developer.
- **AI/agents:** Gemini explains templates, but does not gather incident evidence, call infrastructure tools, or automate troubleshooting.
- **Autonomous application teams:** the platform illustrates the interface but is not yet an autonomous golden-path provisioner.

## Priority work to become a compelling end-to-end interview lab
1. Build a **GitHub App or workload-identity-controlled PR generator** for approved plans, with OPA/Conftest policy-as-code, schema validation and protected approvals.
2. Wire Terraform apply via trusted GitHub/GCP WIF only after policy and human approval; persist request/apply statuses and return ownership/outputs to developer.
3. Validate the new VPC/subnet/optional NAT/Private Service Access blueprint in CI; then extend it with dedicated Private Service Connect endpoints, firewall policies, private Cloud SQL and GCP plan/apply evidence. Wire it into a governed IDP provisioner only after approvals.
4. Build a bounded AI-assisted platform troubleshooting workflow with read-only tools for Cloud Logging, Monitoring, IAM policy and Cloud SQL health; structured evidence and evaluations. No autonomous destructive actions.
5. Add multi-tenant abuse tests, concurrency load tests, production-like PostgreSQL transaction behavior, migration/versioning and disaster recovery.
6. Implement SLO dashboards, alert policies, golden signals, budget gates, SRE runbooks and release rollback drills.

## Honest interview position
This is a working **request and approval control-plane prototype**, not an infrastructure provisioning product. The Terraform inside infra/ creates the IDP itself, not instances requested by catalog users. No deployed GCP system or saved operational performance evidence is established by source and CI alone.
