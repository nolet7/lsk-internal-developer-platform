# LSK GCP environment-specific deployment

The protected environment names are `gcp-dev`, `gcp-staging`, `gcp-prod`. Use distinct GCP projects, state buckets/prefixes, service identities, budgets, IAM and OIDC audiences as appropriate. Region is an explicit **environment variable** in GitHub, not guessed from geography.

## Gates
1. `main` is the GCP source of truth. Run CI (API, lint, dependency audit, PostgreSQL migrations, Terraform validate) and publish an image by immutable digest.
2. Configure GitHub environment protection: reviewers and branch restrictions, particularly for `gcp-prod`. Each environment needs vars `GCP_PROJECT_ID`, `GCP_REGION`, `GCP_TF_STATE_BUCKET`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_TERRAFORM_SERVICE_ACCOUNT`, `OIDC_ISSUER`, `OIDC_AUDIENCE`, `OIDC_JWKS_URL`, `TENANT_REGION_POLICY_JSON`. Set secret `DB_PASSWORD`. The access/IDP projects additionally need a real `GENAI_MODEL` variable; IDP can set `OPS_ALLOWED_SERVICES`.
3. Bootstrap Artifact Registry and the state bucket using a **separate approved identity** before the first image/plan, per `docs/DEPLOY_GCP.md`.
4. Dispatch `GCP environment plan and controlled deploy` with `apply=false` first; **inspect the plan in the job log only for metadata**. Plans can contain secrets; never publish unredacted `tfplan` artifacts.
5. Review the digest and rerun with `apply=true` under the protected environment approval. Because the workflow replans, this is a **new plan**, not automatically the earlier reviewed plan; only use for lab, or replace with a signed plan artifact/approval workflow before regulated production.
6. Run the approved, separate Alembic Cloud Run migration job from the same image digest and private network. Verify readiness, signed region claims, unauthorized tenant rejection, p95 latency and backups, then route traffic.

## Environment profiles
| | dev | staging | prod |
|---|---|---|---|
| Database | ZONAL, smaller tier | REGIONAL, custom tier | REGIONAL, custom tier |
| VPC/database | Private IP | Private IP | Private IP |
| Deletion protection | false | true | true |
| Promoting | CI + manual | Tested release | Change approval and disaster-recovery evidence |

**Country/region rules:** Use a separate project and state per jurisdiction, with explicit region-mapped signed claims. No automatic cross-border replication or failover.

**Important:** GitHub Actions environments are not automatically configured or protected by files in this repo. Cloud resources have not been provisioned. Apply requires live organization-controlled secrets/identities, cloud quota and billing approval. The existing Terraform contains the IDP/application hosting stack, not arbitrary requested golden-path resources. Never call this production certified without live security assessment and restore/incident tests.
