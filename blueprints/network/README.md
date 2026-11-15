# LSK network golden path (separate Terraform lab)

**Goal:** demonstrate corporate IT network design for an AI-forward platform engineering interview, without introducing extra network resources into the existing IDP application deployment.

## What is implemented
- Custom-mode VPC (no default auto-created subnetworks).
- Regional subnet with configurable CIDR and private access to supported Google APIs.
- Optional Cloud Router and Cloud NAT with explicit cost implications.
- Optional Service Networking Private Service Access peering and reserved address range (for Cloud SQL private IP network, where appropriate).
- Terraform inputs and outputs; CI validates syntax/provider configuration.

## Real request path and manual application
1. An IDP user selects `private-service-connectivity` in the service catalog, submits a request and gets a separate approver's authorization.
2. The IDP exports a JSON **GitOps plan only**. It does not invoke this network blueprint.
3. A platform engineer (manually) reviews the plan, chooses non-overlapping CIDR, private services peering allocation and whether NAT is needed.
4. The engineer runs `terraform plan` for this module with a controlled state backend and authorization.
5. After independent change review, Terraform applies VPC/subnet and optional peering/NAT. The engineer verifies route tables, egress behavior, private service reachability, flow logs and cost.
6. The engineer records actual outputs in the service catalog by a future callback integration (not implemented).

**Security:** Cloud NAT is an egress translation mechanism, **not** a firewall. This lab does not automatically enforce application-specific ingress/egress policy. Network firewall policies, private DNS, VPN/interconnect, Private Service Connect endpoints, VPC Service Controls and full network observability are *additional* work. Private Service Access peering is distinct from Private Service Connect.

**Cost:** Creating and enabling Cloud NAT may incur ongoing fees; set `enable_cloud_nat=false` unless necessary. Private Service Access can complicate cleanup. A billing budget is an alert, not a hard cap.

## Local validation
```bash
terraform -chdir=blueprints/network init -backend=false
terraform -chdir=blueprints/network validate
```
No resources are created by validation. For an actual deployment, use controlled remote Terraform state and perform a reviewed `plan` before applying.
