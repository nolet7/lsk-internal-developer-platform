# LSK GCP — dev, staging and production release contract

## Deployment source and environment matrix
Branch `main`; `environments/gcp/dev.tfvars`, `staging.tfvars`, `prod.tfvars`. Dedicated environment name `gcp-dev`, `gcp-staging`, `gcp-prod`. The infrastructure is **Cloud Run + private Cloud SQL + Direct VPC egress**, controlled from `infra/`.

| Gate | dev | staging | prod |
|---|---|---|---|
| Database | Zonal, limited-cost | Regional HA | Regional HA |
| Region mapping | Mandatory signed tenant policy | Mandatory | Mandatory |
| Image | Registry sha256 digest | **Same immutable candidate** | Exactly staging-verified digest |
| Deployment | Protected environment | Approval and smoke | Independent approver, migration verification and DR evidence |
| Terraform | Separate GCS state | Separate GCS state | Separate GCS state and deletion protection |

## How to execute
1. Pre-provision a dedicated project, GCS remote state, constrained GitHub WIF provider and Artifact Registry. Configure protected GitHub environment variables and DB secret (see `docs/ENVIRONMENT_DEPLOYMENT.md`).
2. Run the existing image-publishing workflow using an approved commit. Record the **immutable digest**.
3. Run unit tests, dependency audit, PostgreSQL integration and Terraform validation. Dispatch `GCP environment plan and controlled deploy` with `apply=false`.
4. Prepare a Cloud Run migration job using the same image digest with the approved DB identity and private network. Test on an isolated DB snapshot and record migration success.
5. A reviewer updates `MIGRATION_VERIFIED_DIGEST` in that GitHub environment to match the reviewed image. Only then invoke `apply=true`.
6. After staging smoke, load, restore and rollback tests, record `STAGING_VERIFIED_DIGEST` in the protected `gcp-prod` environment. `prod` rejects an image not approved in staging.
7. Run live SLO monitoring, tenant/region rejection checks and real recovery tests before allowing business traffic.

**Limitations:** The workflow does not create or enforce GitHub environment reviewer rules; admin must configure them. Initial deployment needs registry/DB bootstrap, and app rollout vs schema migration sequencing still requires the controlled two-phase release. A CI pass does not verify cloud quota, private DNS, IAM access, backup restore or compliance status. No cloud resources were deployed by code commits.

## Container publishing identity and image promotion

The GCP `build-image.yml` workflow now uses the protected `gcp-<environment>` GitHub environment, OIDC federation and dedicated `GCP_PUBLISH_SERVICE_ACCOUNT` variable to push an immutable `api:<commit-sha>` image with requested SBOM/provenance attestations. Configure `GCP_ARTIFACT_REPOSITORY` and `GCP_PROJECT_ID` alongside this identity. The workflow prints the `@sha256` digest for the exact deployable image. Use that same digest for staging and production promotion; do not use `:latest` or mutable tags. Runtime access, deployment permission and registry publishing should use separate least-privilege identities.
