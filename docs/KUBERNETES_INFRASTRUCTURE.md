# Reusable LSK Amazon EKS private Kubernetes module

`modules/eks` creates an isolated VPC, two-AZ private nodes, private EKS control plane, NAT egress, IAM control-plane/node roles, audit/control-plane logging, EKS API-based access for a preapproved administrator IAM role, and a managed node group. All resources use provider-managed Kubernetes version support. No public Kubernetes endpoint is enabled.

This stack is independent of the existing ECS application hosting under `infra/aws/`. Use separate AWS account or carefully isolated state/VPC per environment. The EKS module is only Kubernetes **infrastructure**; application release and runtime identity/IRSA, metrics, GitOps, RBAC policies, ingress, secret CSI and backup are separate deployment phases.

## Cost and environments
`environments/kubernetes/{dev,staging,prod}.tfvars` define 2, 2 and 3 desired worker nodes respectively, cluster versions and VPC ranges. Production includes 2 NAT gateways (one per AZ), whereas dev/staging use one NAT for cost reduction. The **EKS managed control plane incurs recurring costs**, alongside workers, NAT and logs. Budget alerts do not impose spending caps.

## Validation
```bash
terraform -chdir=infra/kubernetes fmt -recursive
terraform -chdir=infra/kubernetes init -backend=false -input=false
terraform -chdir=infra/kubernetes validate
```

## Deployment procedure
1. Before provisioning, create an S3 state bucket with versioning and encryption, restrict the GitHub OIDC deploy role to the exact repository and protected environment, and approve a cluster-admin principal ARN. Keep EKS Terraform state separate from ECS infrastructure state.
2. Choose the account, region and profile. From a privileged environment:
```bash
terraform -chdir=infra/kubernetes init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="key=lsk-billing/eks/dev.tfstate" -backend-config="region=$AWS_REGION" -backend-config="use_lockfile=true"
terraform -chdir=infra/kubernetes plan -var-file="../../environments/kubernetes/dev.tfvars" -var="service_name=billing" -var="cluster_admin_role_arn=$ADMIN_ROLE_ARN" -out=reviewed.tfplan
```
3. Review the plan, account context, IAM, CIDR overlaps, availability zones, Amazon EKS version, worker instance SKU, NAT and network egress. Only an approved apply from a trusted platform identity may create the cluster.
4. Because the control plane is **private**, a VPN/bastion/private GitHub runner with EKS API DNS and VPC access is required for `kubectl`, Helm and GitOps. Use `aws eks update-kubeconfig --region REGION --name CLUSTER_NAME` from that private runner.
5. Install EKS add-ons, Pod Identity/IRSA for workloads, cluster policy controls, Secrets Store CSI, metrics, ingress controller, network policies, regional backup and evidence of an AZ failure before deploying a real application.

**Important:** The bootstrap EKS CNI policy is on the node role; for production, migrate to a dedicated CNI identity before tightening node IAM. Enable account-level EBS encryption by default and explicit KMS policies before provisioning. No clusters were provisioned and no live disaster recovery tests were conducted.
