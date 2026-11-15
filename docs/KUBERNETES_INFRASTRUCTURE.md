# Reusable LSK Azure Kubernetes Service module

The `modules/aks` Terraform module creates a dedicated regional resource group, private VNet/subnet, NAT outbound egress, managed user-assigned cluster identity, Entra Azure RBAC with **no local admin credentials**, private AKS API, OIDC Workload Identity, Azure Policy, Cilium network policy/overlay, Azure Monitor workspace and autoscaling node pool.

It is distinct from `infra/azure`, which hosts the existing Container Apps application. Use **independent** state, deployment approvals and cloud resources. The module does not deploy workloads, Helm releases, ingress controller, Secret Store CSI, Argo CD, service mesh, distributed tracing, or database backups.

## Environment profiles

`environments/kubernetes/dev.tfvars`, `staging.tfvars`, `prod.tfvars` use different CIDRs, node capacities and AZs. Change location and availability zones together; not every Azure region supports three zones or all VM sizes. Production has Standard cluster management and >=3 initial nodes.

## Validation
```bash
terraform -chdir=infra/kubernetes fmt -recursive
terraform -chdir=infra/kubernetes init -backend=false -input=false
terraform -chdir=infra/kubernetes validate
```

## Deployment

1. Have a platform owner create the subscription, an encrypted Azure Blob remote state account/container with GitHub federated identity and an approved Entra administrator group.
2. From an approved Azure identity:
```bash
terraform -chdir=infra/kubernetes init -backend-config="resource_group_name=$STATE_RG" -backend-config="storage_account_name=$STATE_ACCOUNT" -backend-config="container_name=$STATE_CONTAINER" -backend-config="key=lsk-billing/aks/dev.tfstate" -backend-config="use_azuread_auth=true"
terraform -chdir=infra/kubernetes plan -var-file="../../environments/kubernetes/dev.tfvars" -var="subscription_id=$AZURE_SUBSCRIPTION_ID" -var="service_name=billing" -var='admin_group_object_ids=["YOUR-APPROVED-ENTRA-GROUP-GUID"]' -out=reviewed.tfplan
```
3. Inspect subnets, DNS, NAT egress, cluster private API, Entra permissions, availability-zone support and costs. Apply only with protected approver consent.
4. Use a VNet-connected runner or VPN to obtain credentials: `az aks get-credentials -g RESOURCE_GROUP -n CLUSTER`. Configure RBAC and policy, storage, external secrets, workload identity bindings, GitOps, ingress gateway and monitoring before application rollout.
5. Demonstrate region-isolation tests, pod disruption behavior, cluster upgrade and restore exercises before production claims.

**Security note:** NAT provides egress, not firewalling or DLP. This is a private API cluster, not a guarantee of private application ingress. Regional data-retention and sovereign cloud restrictions require independent review. No Azure resource was created by source commits.
