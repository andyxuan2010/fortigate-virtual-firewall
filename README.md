# FortiGate Virtual Firewall

This repository deploys switchable FortiGate virtual firewall architectures
for Azure and AWS. Azure targets the existing hub VNet; the AWS root provides
parallel single-node and two-node HA provisioning through the dedicated
FortiGate and Gateway Load Balancer modules from [andyxuan2010/aws-template](https://github.com/andyxuan2010/aws-template).
Terraform commands use the Azure Terraform root at `platforms/azure/`.
Paths such as `environments/dev/terraform.tfvars` are relative to that root.

## Start here

| Document | Purpose |
|---|---|
| [Architecture](docs/azure/architecture.md) | Simple and HA topology, subnets, NICs, load balancers, identities, and route behavior. |
| [Deployment runbook](docs/azure/runbooks/deployment.md) | Terraform initialization, GitHub Actions, Azure DevOps, prerequisites, and apply sequence. |
| [Operations reference](docs/azure/reference/operations.md) | Port mapping, RBAC, network controls, troubleshooting, validation, and production-readiness checks. |
| [AWS architecture](docs/aws/architecture.md) | AWS simple/HA topology and implementation boundaries. |
| [AWS runbook](docs/aws/runbooks/usage-and-provisioning.md) | AWS initialization, planning, applying, and required substitutions. |

## Current dev mode

The checked-in dev environment uses the `single` architecture switch:

```hcl
fortigate_deployment_mode = "single" # change to "ha" for the HA profile
```

Single mode provisions one BYOL FortiGate VM with two NICs:

- External subnet: `10.32.192.0/25`
- Internal subnet: `10.32.193.0/25`
- VM size: `Standard_F4s_v2`
- No HA NIC, management NIC, load balancer, or public IP
- Azure IP forwarding enabled on both interfaces
- Shared NSG and route-table integration retained for the POC

The smallest supported candidate is `Standard_F2s_v2`; changing the existing
VM to that SKU is a separate resize/replacement decision.

## Architecture images

![Simple FortiGate architecture](docs/azure/images/fortigate-simple-architecture.png)

![Full FortiGate HA architecture](docs/azure/images/fortigate-full-architecture.png)

## Important boundaries

- The hub VNet and dedicated firewall subnets are existing platform resources.
- Azure infrastructure does not configure FortiOS licensing, policies, or HA
  clustering.
- No public administration path is created.
- Workload route-table associations remain pending until approved subnet IDs are
  supplied.
- Existing Azure resources and role assignments must be imported into state or
  removed before Terraform apply.

## Useful commands

Run Terraform commands from the Azure platform root:

```powershell
Set-Location platforms/azure

terraform init -reconfigure -input=false `
  -backend-config="environments/dev/backend.hcl"

terraform plan -input=false `
  -var-file="environments/dev/terraform.tfvars"
```

Use the deployment runbook for backend configuration, credentials, imports,
and the automated pipeline behavior.

## AWS implementation

The AWS root is `platforms/aws/`. It supports `single` mode in the dev example
and `ha` mode in the prod example. The [AWS module gap analysis](docs/aws/reference/module-gap-analysis.md)
lists the remaining FortiGate AMI, bootstrap, GWLB endpoint, and HA route-failover
inputs that must be supplied before a real apply.

## Repository layout

```text
platforms/azure/                         Azure Terraform root and environments
platforms/aws/                           AWS Terraform root and environments
docs/azure/architecture.md               Architecture and mode design
docs/azure/runbooks/deployment.md        Deployment and pipeline runbook
docs/azure/reference/operations.md       Operations and troubleshooting reference
docs/repository-structure.md             Repository structure and layout
docs/azure/images/                       Simple and full architecture diagrams
docs/aws/                                AWS architecture, gap analysis, and runbook
.github/workflows/terraform.yml          Validate, plan, and configured dev apply
.github/workflows/pages.yml              Publish the public documentation portal
```
