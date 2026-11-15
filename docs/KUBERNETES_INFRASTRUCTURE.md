# Reusable GKE Kubernetes platform module

`modules/gke` provisions an isolated regional **private-control-plane GKE Standard cluster** with dedicated VPC, subnet, pod/service secondary IP ranges, NAT, private nodes, Workload Identity Federation for GKE, least-privilege node identity, Shielded Nodes, managed upgrades, and zonal node pool autoscaling.

The root `infra/kubernetes` is independent of the application's existing `infra/` Cloud Run stack. It has its **own Terraform state, project boundaries, costs and lifecycle**. Do not apply both by accident. The cluster module does NOT automatically deploy the business application, configure a GKE ingress gateway, external secrets, GitOps/Argo CD or SLO dashboards.

## Environments

| Setting | dev | staging | prod |
|---|---|---|---|
| GKE | Regional control plane; 1 node zone | Regional; 2 node zones | Regional; 3 node zones |
| Capacity | e2-standard-2 | e2-standard-4 | e2-standard-4 |
| Autoscale per zone | 1–2 | 1–3 | 2–5 |
| Delete protection | No | No | Yes |
| Kubernetes API | Private | Private | Private |

All three profiles are samples targeting `us-central1`, with **distinct, non-overlapping CIDRs**. Change `node_zones`, project, regions, CIDRs and approved regional identity mappings for your actual enterprise. Do not reuse one region's IP allocation blindly in another region.

## Validation

```bash
terraform -chdir=infra/kubernetes fmt -check -recursive
terraform -chdir=infra/kubernetes init -backend=false
terraform -chdir=infra/kubernetes validate
```

## Deploy in an approved GCP project

1. Create the project and approved encrypted/versioned GCS Terraform state bucket with a **separate state prefix** from Cloud Run. Turn on budget alerts and quotas.
2. Use GitHub OIDC federation and least-privilege identity authorized to manage only this platform stack. Protected environment reviewers are configured in GitHub, not by Terraform.
3. Choose a profile and explicit project ID, region, service name. Example:
```bash
terraform -chdir=infra/kubernetes init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="prefix=lsk-billing/gke/dev"
terraform -chdir=infra/kubernetes plan -var-file="../../environments/kubernetes/dev.tfvars" -var="project_id=$PROJECT_ID" -var="service_name=billing" -out=reviewed.tfplan
```
4. Review IAM, CIDRs, network egress, zones, cluster version support and cost. Only then apply from an authorized network. Run `gcloud container clusters get-credentials CLUSTER --region REGION --project PROJECT --internal-ip` on a private runner with a valid route to the control-plane endpoint.
5. Deploy application workloads using a separate GitOps/Helm pipeline with external secrets, policy admission, NetworkPolicy, PodDisruptionBudget, resource requests/limits and workload identity. Validate deployment, HPA, ingress, database and DR/rollback separately.

**Important:** Terraform validate does not create a GKE cluster or prove supported quotas, private DNS, backup restore, data residency, secure workload deploys or regulatory compliance. A regional GKE control plane is billable. No Kubernetes deployment was executed.
