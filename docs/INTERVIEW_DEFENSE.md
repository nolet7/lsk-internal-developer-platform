# Senior AI Platform Engineer interview defense
## Demo (15 minutes)
1. Describe tickets-to-self-service problem and team ownership boundaries.
2. Show `GET /v1/catalog` with approved golden paths.
3. Submit a service request with an Idempotency-Key. Replay it and demonstrate conflict detection.
4. Attempt self approval (403); approve with independent reviewer. Show extra prod scope requirement.
5. Export approved GitOps plan and explain protected PR, policy, Terraform plan and manual apply.
6. Show tenant-isolation tests and Cloud Run/Cloud SQL/IAM architecture.
7. Discuss which actions an AI agent can safely advise on vs actions that require deterministic policy and explicit approval.

## Honest answers
- **Did you deploy this at Chromalloy?** No. It is an independently built fictional corporate IT portfolio scenario.
- **Does the API provision Cloud Run services?** No. It outputs a constrained handoff artifact; the provisioning pipeline is a planned integration.
- **Why does this qualify as a platform engineering demonstration?** It demonstrates a discoverable catalog, secure requests, auditability, golden paths, team ownership and separation of control-plane operations.
- **What remains for enterprise production?** More policy enforcement, migrations, compliance controls, operational testing, real GitOps PR integration and a hardening review.
