# LSK IDP — Enterprise-style architecture
## Business intent
Fictional enterprise corporate IT division serving Finance, Customer Operations and engineering teams. No manufacturing focus. Reduce ticket queues for standard Cloud Run APIs, managed databases, and reviewed network connectivity requests.

## System design
```mermaid
flowchart LR
  Dev[Application developer] --> IAM[Cloud Run invoker IAM]
  IAM --> API[FastAPI IDP API]
  API --> OIDC[OIDC claim validation]
  API --> DB[(Cloud SQL PostgreSQL)]
  API --> Catalog[Versioned golden paths]
  API --> Plan[Approved JSON GitOps plan]
  Reviewer[Independent reviewer] --> API
  Plan --> PR[Protected infrastructure repo PR]
  PR --> Policy[Policy and Terraform plan gates]
  Policy --> Approval[Human review]
  Approval --> Apply[Workload Identity Federation deployer]
```

## Trust and authorization
Cloud Run IAM determines who can invoke the service. The app separately validates RS256-signed OIDC JWTs (issuer, audience, expiry, tenant_id, scopes). Tenant-bound database queries prevent cross-tenant API access. Reviewers cannot approve their own requests. Production requires a stronger approval scope. Structured audit events record changes. **A passing test is not a full security assessment.**

## Decision records
- Cloud Run instead of permanent GKE: cheaper idle footprint for portfolio labs, but does not demonstrate Kubernetes platform operations directly.
- Cloud SQL vs SQLite: transactional persistence and row-level locking; use PostgreSQL production behavior, not SQLite, for final concurrency tests.
- API produces reviewed GitOps plans rather than creating resources directly. The real infrastructure provisioning step is a separately governed integration.
- Golden paths are versioned catalog entries. The next release should move these into schema-validated repository templates, with security policy tests and protected PR generation.
- An optional read-only Gemini catalog advisory is implemented; it is not an operations agent and cannot approve, change IAM, or apply Terraform.

## Production gaps
Alembic migrations, provisioning adapter, OPA/Conftest, richer audit log integrity, cost controls, network policy validation, DB HA/restore drills, full OIDC end-to-end tests, multi-region failover, SLO telemetry, realistic load and concurrency testing, fine-grained service ownership and rate limiting.

## Optional AI catalog advisory

`GET /v1/ai/catalog-advisory/{template_key}` uses the Google Gen AI SDK against Vertex AI with the Cloud Run service identity. Only allowlisted, catalog-owned text is sent to the model; user requests and confidential records are never passed. The output is advisory only, bounded, and never executes changes. Costs depend on model and tokens; configure `genai_model` explicitly and test with a small quota. Vertex AI is not required for normal request/approval functionality. Approvals remain deterministic and human controlled.
