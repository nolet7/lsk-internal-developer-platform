# LSK Internal Developer Platform

**Independent, fictional corporate IT lab built for Senior AI Platform Engineer interviews.** This is not evidence of an ASR Group or Chromalloy production deployment.

[![CI](https://github.com/nolet7/lsk-internal-developer-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/nolet7/lsk-internal-developer-platform/actions/workflows/ci.yml)

## Goal

Replace ticket-driven developer infrastructure requests with a governed, reusable platform catalog. Application teams can request Cloud Run API blueprints, managed PostgreSQL, and private-network connectivity. Platform reviewers control approvals and application teams receive a structured plan for a separately reviewed GitOps pipeline.

## Implemented

- Versioned golden paths: `cloud-run-api`, `managed-postgres`, `private-service-connectivity`
- Tenant-aware OIDC authentication and scopes: `catalog:read`, `platform:request`, `platform:read`, `platform:approve`, `platform:approve:prod`, `platform:plan`, `platform:audit`
- Idempotent request submission and PostgreSQL-backed requests, approvals and audit events
- Independent approval, explicit production-scope requirement, approval/rejection state machine
- Deterministic GitOps JSON plan export; **no direct cloud provisioning**
- Terraform for Cloud Run, Cloud SQL, Secret Manager, Artifact Registry and runtime IAM
- Docker Compose PostgreSQL, tests, lint, dependency audit and Terraform validation

## Local development

Create `.env` from `.env.example` and replace every placeholder with your own synthetic lab credentials / trusted OIDC provider. Passwords containing URL-special characters must be URL-encoded if embedded in `DATABASE_URL`; use an encoded DSN.

```bash
git clone https://github.com/nolet7/lsk-internal-developer-platform.git
cd lsk-internal-developer-platform
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
DATABASE_URL=sqlite+pysqlite:///./ci.db python -m pytest -q
```

To run the API with PostgreSQL:

```bash
docker compose --env-file .env up -d postgres
docker compose --env-file .env run --rm api python scripts/migrate.py
docker compose --env-file .env up -d api
```

Open the OpenAPI documentation at `http://localhost:8080/docs`. Use a valid access JWT issued by your configured OIDC provider. The API does not implement a fake authentication bypass outside tests.

## Service workflow

1. `GET /v1/catalog` — discover available golden paths.
2. `POST /v1/requests` — submit a typed request with `Idempotency-Key`.
3. `GET /v1/requests` — inspect tenant requests.
4. `POST /v1/requests/{id}/approve` — independent review, extra production scope.
5. `GET /v1/requests/{id}/gitops-plan` — export an approved, versioned plan for a protected GitOps repository.
6. `GET /v1/requests/{id}/audit` — inspect request events.

## Deploy to GCP

Follow **[docs/DEPLOY_GCP.md](docs/DEPLOY_GCP.md)** for a controlled GCP deployment. Set a budget before provisioning and remember that alerts do not cap spending. Cloud SQL incurs costs even when Cloud Run has zero instances. Terraform state and plans may contain sensitive credentials.

## Architecture and interview defense

- [Architecture and design decisions](docs/ARCHITECTURE.md)
- [GCP deployment guide](docs/DEPLOY_GCP.md)
- [Interview walkthrough](docs/INTERVIEW_DEFENSE.md)

## Boundaries and next work

This is an enterprise-style **lab foundation**, not a finished production portal. It does not yet create infrastructure PRs, deploy templates, integrate an LLM, or perform automatic cloud provisioning. Before a regulated production use case, add reviewed migrations, private networking, durable audit integrity, policy-as-code, service ownership, backoff/concurrency/load tests, HA/DR, cost quotas, security assessment and observability SLOs.

Synthetic data only. No real customer or employer credentials.
