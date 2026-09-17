# Repository Structure and Layout

## Purpose

This repository contains parallel platform areas for the Azure FortiGate
virtual-firewall deployment and a parallel AWS implementation scaffold. The Azure
Terraform root is under `platforms/azure/`, and the AWS Terraform root is under
`platforms/aws/`. The repository also contains shared
automation, operational guidance, and the static documentation portal.

The Azure root downloads reusable modules directly from the public
`git::https://github.com/andyxuan2010/azure-template.git//modules/*?ref=main`
source. A companion module checkout is not required.

## Current repository tree

```text
net-virtual-firewall-prod/
├── .gitignore
├── .nojekyll
├── .pre-commit-config.yaml
├── .github/
│   └── workflows/
│       ├── pages.yml
│       └── terraform.yml
├── azure-pipelines.yml
├── docs-manifest.json
├── docs/
│   ├── azure/
│   │   ├── architecture.md
│   │   ├── images/
│   │   ├── reference/
│   │   └── runbooks/
│   ├── aws/
│   │   ├── images/
│   │   ├── reference/
│   │   └── runbooks/
│   └── repository-structure.md
├── index.html
├── load-dotenv.ps1
├── platforms/
│   ├── azure/
│   │   ├── backend.tf
│   │   ├── data.tf
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   └── prod/
│   │   ├── fortigate-route-rbac.tf
│   │   ├── locals.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   └── aws/
│       ├── backend.tf
│       ├── environments/
│       │   ├── dev/
│       │   └── prod/
│       ├── locals.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── variables.tf
│       └── versions.tf
├── README.md
├── README.pdf
├── reload-arm-env.ps1
├── scripts/
│   ├── azure/
│   ├── aws/
│   ├── common/
│   ├── create-release-tag.sh
│   ├── generate-docs-manifest.ps1
│   ├── post_init_script.sh
│   ├── Sync-GitHubOrgEnv.ps1
│   ├── Sync-GitHubRepoEnv.ps1
│   ├── Test-TerraformModules.ps1
│   └── ubuntu.sh
├── settings.json
├── templates/
│   ├── shared-runner-hygiene.yml
│   └── terraform-prepare.yml
```

Local-only items such as `.env`, `.terraform/`, state files, credentials, and
provider caches are intentionally excluded from the repository tree above.
They are covered by `.gitignore` and must not be committed.

## Azure Terraform root files

| File | Responsibility |
|---|---|
| `platforms/azure/backend.tf` | Declares an empty AzureRM backend. The actual state settings are selected from the active environment backend file during initialization. |
| `platforms/azure/providers.tf` | Configures Azure providers and the `prod`, `nonprod`, `sbx`, and `hub` aliases used by the Azure root composition. |
| `platforms/azure/versions.tf` | Pins the Azure root Terraform minimum version and provider source/version constraints. |
| `platforms/azure/variables.tf` | Defines Azure root inputs, types, defaults, and validation rules. |
| `platforms/azure/locals.tf` | Normalizes names and locations, resolves feature gates, builds effective tags, and derives FortiGate routes and resource names. |
| `platforms/azure/data.tf` | Contains Azure root-level data lookups, including the active Azure client and optional shared resources. |
| `platforms/azure/main.tf` | Composes the reusable Azure modules from the public `azure-template` Git repository. Each module is guarded by the corresponding feature toggle. |
| `platforms/azure/fortigate-route-rbac.tf` | Creates the custom route-updater role and table-scoped assignments for the FortiGate managed identities. |
| `platforms/azure/outputs.tf` | Exposes resource IDs, private addresses, identity IDs, load-balancer details, and route-table assignment IDs. |

The Azure root configuration is intentionally broader than the enabled production
deployment. Many generic module blocks remain available for the shared IaC
harness, but only modules enabled through the selected environment's
`features` map are planned.

## AWS Terraform root files

| File | Responsibility |
|---|---|
| `platforms/aws/backend.tf` | Declares the S3 backend; environment backend files provide the actual state settings. |
| `platforms/aws/providers.tf` | Configures the AWS provider and common resource tags. |
| `platforms/aws/versions.tf` | Pins the AWS root Terraform minimum version and provider range. |
| `platforms/aws/variables.tf` | Defines AWS region, mode, FortiGate, subnet, security, route, and placeholder inputs. |
| `platforms/aws/locals.tf` | Selects simple/HA nodes and roles and derives subnets, ENIs, security rules, and IAM policy defaults. |
| `platforms/aws/main.tf` | Uses public `aws-template` VPC, security-group, IAM-role, FortiGate, and Gateway Load Balancer modules, with optional static routes. |
| `platforms/aws/outputs.tf` | Exposes VPC, instance, ENI, route, load-balancer placeholder, and implementation-gap details. |

The AWS root uses the dedicated `fortigate` module for multi-NIC instances,
static private IPs, bootstrap, and active-passive HA. The dedicated
`gateway_load_balancer` module provides the optional GENEVE inspection front end.

## Environment separation

Each Azure environment owns two files: one backend file and one variable file. The
files must be used as a matching pair.

| Environment | Variable file | Backend file | Architecture | Main purpose |
|---|---|---|---|---|
| `prod` | `platforms/azure/environments/prod/terraform.tfvars` | `platforms/azure/environments/prod/backend.hcl` | HA/full | Current two-VM production FortiGate deployment |
| `dev` | `platforms/azure/environments/dev/terraform.tfvars` | `platforms/azure/environments/dev/backend.hcl` | Single/simple | Lower-environment POC/example |

The AWS examples use the same environment pairing under `platforms/aws/`:

| Environment | Variable file | Backend file | Architecture | Main purpose |
|---|---|---|---|---|
| `prod` | `platforms/aws/environments/prod/terraform.tfvars` | `platforms/aws/environments/prod/backend.hcl` | HA | Two-node AWS FortiGate foundation across two AZs |
| `dev` | `platforms/aws/environments/dev/terraform.tfvars` | `platforms/aws/environments/dev/backend.hcl` | Single/simple | One-node AWS FortiGate foundation example |

The production deployment uses:

- Existing hub VNet: `vnet-ba-cc-prod-hub`.
- Network resource group: `rg-ba-cc-prod-hub-network`.
- FortiGate compute resource group: `rg-ba-cc-prod-vfirewall`.
- External subnet: `snet-ba-cc-prod-vfirewall-external`, `10.32.192.0/25`.
- Internal subnet: `snet-ba-cc-prod-vfirewall-internal`, `10.32.193.0/25`.
- HA subnet: `snet-ba-cc-prod-vfirewall-ha`, `10.32.194.0/28`.
- Management subnet: `snet-ba-cc-prod-vfirewall-management`, `10.32.195.0/24`.
- Shared NSG: `nsg-ba-cc-prod-vfirewall`.
- Route table: `rt-ba-cc-prod-vfirewall`.
- Internal load-balancer frontend and route next hop: `10.32.193.5`.

The Terraform state backend is stored in the shared IaC resource group
`rg-ccoe-iac-cc-prod`, using storage account `stccoeiacccprod`, container
`terraform`, and the production state key
`net-virtual-firewall-prod/terraform.tfstate`.

## Terraform execution flow

Run the following Terraform commands from `platforms/azure/`.

The effective CLI arguments may be supplied through environment variables:

```text
TF_CLI_ARGS_init=-backend-config=environments/prod/backend.hcl
TF_CLI_ARGS_plan=-var-file=environments/prod/terraform.tfvars
TF_CLI_ARGS_apply=-var-file=environments/prod/terraform.tfvars
TF_CLI_ARGS_destroy=-var-file=environments/prod/terraform.tfvars
```

PowerShell does not load `.env` automatically. The variables must be exported in
the current process before running Terraform. The repository scripts and Azure
DevOps pipeline pass the backend and variable paths explicitly, which avoids
depending on a developer's local shell state.

A production review sequence is:

```powershell
terraform fmt -check
terraform validate
terraform init -reconfigure -backend-config=environments/prod/backend.hcl
terraform plan -var-file=environments/prod/terraform.tfvars -out=tfplan
terraform show tfplan
```

`terraform apply` must use the reviewed plan. It changes Azure resources and
must only be enabled after reviewing the complete plan and confirming the
deployment approvals and credentials.

## Azure DevOps pipeline layout

`azure-pipelines.yml` is triggered from `main` and has three stages:

1. **Validate** checks required variables and environment files, installs the
   requested Terraform version, runs recursive formatting checks, initializes
   without the remote backend, and runs `terraform validate`.
2. **Plan** initializes the public `azure-template` modules, reads the selected
   backend file, authenticates through the Azure service connection, initializes
   the remote backend, plans with the selected variable file, and publishes a
   binary plan plus text plan summary.
3. **Apply** downloads the plan artifact from the same pipeline run and applies
   that exact plan when `ENABLE_ADO_APPLY` is `true`. Environment approvals are
   controlled by the `useEnvironmentApprovals` parameter.

The pipeline derives these paths from `ENVIRONMENT`:

```text
TERRAFORM_BACKEND_FILE=environments/$(ENVIRONMENT)/backend.hcl
TERRAFORM_VAR_FILE=environments/$(ENVIRONMENT)/terraform.tfvars
```

The variable group must provide the environment name, Terraform version, agent
pool/image settings, apply gate, service-connection permissions, and any
protected FortiGate credentials. `read-backend-config.sh` requires Python 3 on
the agent because it parses the flat HCL backend file and emits Azure DevOps
task variables.

## Pipeline helper scripts

| Script | Purpose |
|---|---|
| `scripts/azure/install-terraform.sh` | Downloads or installs the requested Terraform version. |
| `scripts/azure/terraform-common.sh` | Sets CI-safe Terraform behavior, Git authentication, and Azure service-principal/OIDC variables. |
| `scripts/azure/terraform-validate.sh` | Runs format checks, backend-disabled initialization, and configuration validation. |
| `scripts/azure/read-backend-config.sh` | Reads backend values and publishes them as Azure DevOps variables. |
| `scripts/azure/terraform-plan.sh` | Initializes the selected backend, checks credential fallback behavior, creates the plan, and writes a text summary. |
| `scripts/azure/terraform-apply.sh` | Initializes the selected backend and applies the downloaded, reviewed plan artifact. |
| `scripts/common/terraform-change-summary.sh` | Produces a concise resource-change summary from a Terraform plan. |
| `scripts/azure/module-harness-targets.sh` | Defines the module file targets used by the validation harness. |
| `Test-TerraformModules.ps1` | Runs the public `azure-template` module tests and reports results on Windows. |
| `generate-docs-manifest.ps1` | Scans tracked Markdown files and writes `docs-manifest.json`. |
| `create-release-tag.sh` | Creates release tags according to the repository's release convention. |
| `Sync-GitHubOrgEnv.ps1` | Synchronizes organization-level environment settings. |
| `Sync-GitHubRepoEnv.ps1` | Synchronizes repository-level environment settings. |
| `post_init_script.sh` | Performs post-initialization setup used by the workspace/bootstrap flow. |
| `ubuntu.sh` | Provides Ubuntu-oriented local/bootstrap helpers. |

## Documentation and portal layout

| Path | Responsibility |
|---|---|
| `README.md` | Main repository overview, current architecture, deployment guidance, security model, and readiness notes. |
| `docs/azure/architecture.md` | Architecture profiles, shared Azure controls, environment mapping, and HA/simple behavior. |
| `docs/azure/reference/operations.md` | Operational evidence, interface mapping, RBAC, network controls, and verification checks. |
| `docs/repository-structure.md` | Repository layout, Terraform composition, automation, and documentation portal structure. |
| `docs/azure/runbooks/deployment.md` | Repeatable initialization, plan, apply, pipeline, and rollback procedures. |
| `docs/azure/runbooks/usage-and-provisioning.md` | Local Terraform setup, environment selection, planning, provisioning, and CI/CD usage. |
| `docs/aws/architecture.md` | AWS simple/HA topology and implementation boundaries. |
| `docs/aws/reference/module-gap-analysis.md` | Available AWS-template modules, missing capabilities, and required inputs. |
| `docs/aws/runbooks/usage-and-provisioning.md` | AWS initialization, planning, applying, and placeholder substitution. |
| `README.pdf` | PDF snapshot of the README for offline or controlled distribution. |
| `docs/azure/images/fortigate-simple-architecture.png` | Simplified production architecture illustration. |
| `docs/azure/images/fortigate-full-architecture.png` | Detailed production HA architecture illustration. |
| `docs-manifest.json` | Portal document index consumed at runtime. |
| `index.html` | Static documentation portal. It fetches the manifest, lists documents by category, loads Markdown, resolves relative images/links, and provides search/theme/navigation behavior. |

The portal categorizes platform architecture Markdown files as architecture/design
guides, platform `runbooks/` files as deployment runbooks, and platform
`reference/` files as operations and reference material. Adding a Markdown file requires adding it to
`docs-manifest.json` (or regenerating the manifest after the file is tracked).

## Templates and workspace configuration

| Path | Purpose |
|---|---|
| `templates/shared-runner-hygiene.yml` | Reusable Azure DevOps runner setup and cleanup steps. |
| `templates/terraform-prepare.yml` | Reusable Terraform preparation template. |
| `.pre-commit-config.yaml` | Local pre-commit hooks and repository checks. |
| `.vscode/` | Workspace/editor settings and local task integration. |
| `settings.json` | Project/site settings used by the documentation or workspace tooling. |
| `load-dotenv.ps1` | Loads local `.env` values into a PowerShell process when explicitly invoked. |
| `reload-arm-env.ps1` | Reloads Azure Resource Manager environment values for local work. |
| `.nojekyll` | Prevents GitHub Pages Jekyll processing of the static portal. |

## Important operational boundaries

- The hub VNet and shared hub resources are existing resources. The production
  configuration creates or manages only the resources enabled in its feature
  map and the selected FortiGate foundation.
- Azure infrastructure configuration does not configure FortiOS licensing,
  HA clustering, policies, routing, or failover behavior inside the appliances.
- External ingress is disabled until explicit listener rules are approved.
- The production plan must be reviewed for route-table ownership, subnet
  prefixes, NIC order, IP forwarding, RBAC scope, and management access before
  apply.
- The current route-table composition passes `var.tags` in addition to inherited
  resource-group tags. Because the default `var.tags` map contains
  `Environment = "dev"`, a production plan can show `PROD -> dev` tag drift.
  Resolve that drift before enabling Apply.

## Local-only and generated content

The following are intentionally not part of the checked-in deployment contract:

- `.env` and credential material: local secrets and service-principal values.
- `.terraform/` and provider cache content: local Terraform working data.
- `*.tfstate` and `*.tfplan`: state and plan artifacts.
- `credentials` and local override files: machine-specific authentication or
  overrides.

Keep generated plans and credentials outside commits, and use the published
Azure DevOps plan artifact for an approved Azure deployment. The AWS runbook
documents the corresponding local commands; an AWS CI/CD workflow remains a
follow-up once the account, backend, AMI, bootstrap, and HA routing design are
approved.
