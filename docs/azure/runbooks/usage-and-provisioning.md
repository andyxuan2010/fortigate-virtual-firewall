# Using and Provisioning the FortiGate Virtual Firewall

This guide explains how to prepare the Terraform environment, select an
environment, review the plan, and provision the Azure resources from the
`CCOE-Azure/fortigate-virtual-firewall` repository.
The command paths below are relative to `platforms/azure/`.

Terraform in this repository is the root composition. The reusable Terraform
modules are downloaded directly from the public `azure-template` repository by
the module sources in `platforms/azure/main.tf`.

## What this repository provisions

The selected environment controls which modules are enabled. The FortiGate
deployment uses an existing hub VNet and can create or manage the dedicated
firewall resource group, subnets, NSG, FortiGate VMs, load balancer resources,
managed identities, and route table described by the environment variable
file.

Terraform provisions the Azure foundation. It does not complete FortiOS
licensing, FortiOS policies, SDN connector configuration, HA cluster formation,
FortiManager integration, or failover validation.

The checked-in profiles are:

| Environment | Variable file | Backend file | Mode | Intended use |
|---|---|---|---|---|
| `dev` | `environments/dev/terraform.tfvars` | `environments/dev/backend.hcl` | `single` | Lower-environment POC with one FortiGate VM and two NICs |
| `prod` | `environments/prod/terraform.tfvars` | `environments/prod/backend.hcl` | `ha` | Production-oriented two-VM active-passive foundation |

Do not change the environment, subscription, VNet, subnet prefixes, or
feature toggles without confirming ownership and approval for the target
Azure resources.

## 1. Prepare the workspace

Install Git, Terraform, Azure CLI, and PowerShell. The root configuration
requires Terraform `>=1.5`; use Terraform `>=1.6` to satisfy the public
FortiGate module and its tests.

From the repository, enter the Azure Terraform root and verify the local tools:

```powershell
Set-Location <path-to>\fortigate-virtual-firewall\platforms\azure

terraform version
az version
```

The module directory must exist before `terraform init`, because the root
composition references many local module paths.

## 2. Configure Azure authentication

Use an approved Azure identity with permission to read the existing hub
resources, access the Terraform state storage account, and create or update
the resources enabled by the selected environment.

For interactive work, sign in with Azure CLI and select the deployment
subscription:

```powershell
az login
az account set --subscription <deployment-subscription-id>
az account show --output table
```

For service-principal authentication, provide the `ARM_*` values through the
current process or an approved secret manager. Do not commit credentials:

```powershell
$env:ARM_CLIENT_ID       = "<client-id>"
$env:ARM_CLIENT_SECRET   = "<client-secret>"
$env:ARM_TENANT_ID       = "<tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
```

`reload-arm-env.ps1 -SkipLogin` can reload existing user or machine-level
`ARM_*` values into the current PowerShell session. `load-dotenv.ps1` can load
a local `.env` file when one is used; keep `.env` untracked and never place it
in a commit.

The FortiGate administrator password or SSH public key must also be supplied
through a protected value when required by the module:

```powershell
$env:TF_VAR_fortigate_admin_password = "<password>"
# Or use the approved public key instead:
$env:TF_VAR_fortigate_admin_ssh_public_key = "<ssh-public-key>"
```

Do not put either private credential in `terraform.tfvars`, the repository, or
a plan artifact that will be distributed beyond the deployment team.

## 3. Select and review an environment

Set the environment once in the session and derive both paths from it. Always
use the matching variable and backend files:

```powershell
$EnvironmentName = "dev" # change to "prod" only with production approval
$VarFile = "environments/$EnvironmentName/terraform.tfvars"
$BackendFile = "environments/$EnvironmentName/backend.hcl"

Get-Content $VarFile
Get-Content $BackendFile
```

Before planning, confirm at least these settings:

- `features.enable_vnet` remains `false` when the hub VNet is platform-owned.
- `features.enable_existing_vnet_subnets`, `enable_nsg`,
  `enable_fortigate`, and `enable_route_table` match the approved scope.
- `vnet_name`, `network_resource_group_name`, and all subnet prefixes identify
  the intended existing network.
- `fortigate_deployment_mode` is `single` for the POC or `ha` for the
  production-oriented profile.
- `route_table_subnet_ids` contains only approved workload subnet IDs.
- FortiGate group IDs and any management inputs are approved for the target
  environment.

## 4. Initialize and validate Terraform

Run the format check and a backend-disabled validation first. The latter
checks configuration and module loading without changing the remote state:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -reconfigure -input=false
terraform validate
```

Initialize the selected AzureRM backend only after confirming the backend file:

```powershell
terraform init -reconfigure -input=false `
  -backend-config="$BackendFile"
```

The backend file determines the remote state location. Do not initialize with
one environment's backend and plan with another environment's variable file.

## 5. Create and review a plan

Create a saved plan using the same variable file selected above:

```powershell
terraform plan -input=false `
  -var-file="$VarFile" `
  -out=tfplan

terraform show -no-color tfplan | Tee-Object -FilePath tfplan.txt
```

Review resource creation, replacement, and deletion carefully. Pay particular
attention to existing-resource ownership, subnet address ranges, NIC order,
IP forwarding, route-table next hops, NSG rules, managed-identity role
assignments, VM size, marketplace plan, and FortiGate credentials.

If Terraform reports that an existing resource already exists, confirm its
owner. Import it into the correct state only when this repository is intended
to manage it; otherwise adjust the feature inputs or remove the conflicting
resource from the proposed scope.

Example import shape:

```powershell
terraform import -input=false `
  -var-file="$VarFile" `
  '<terraform-address>' `
  '<azure-resource-id>'
```

## 6. Provision the approved resource set

Apply the exact saved plan that was reviewed:

```powershell
terraform apply -input=false tfplan
```

Do not use `-auto-approve` for an unreviewed local plan. In CI, the pipeline
downloads and applies the binary plan artifact produced by its plan stage.

After apply, inspect outputs and Azure state:

```powershell
terraform output
terraform output fortigate_private_ip_addresses
terraform state list
```

Then validate the Azure resource group, VM/NIC placement, load balancer
frontends and probes, route table, NSG, role assignments, and private
management reachability. Complete FortiOS configuration and operational
testing separately.

## 7. CI/CD paths

### GitHub Actions

`.github/workflows/terraform.yml` validates and plans the dev profile by
default, with optional sandbox work. Apply is gated by the workflow inputs and
repository/environment settings, including `ENABLE_GITHUB_APPLY`. The workflow
downloads the public `azure-template` modules during Terraform initialization
and expects the required Azure credentials and FortiGate secrets in the
configured GitHub Environment.

`.github/workflows/pages.yml` publishes the documentation portal after
documentation changes. It regenerates `docs-manifest.json` during publishing.

### Azure DevOps

`azure-pipelines.yml` runs Validate, Plan, and gated Apply stages. The default
service connection is `sc-ccoe-iac-devops-dev`, and the repository variable
group is `fortigate-virtual-firewall`. Configure these values through the
approved variable groups:

| Variable | Purpose |
|---|---|
| `ENVIRONMENT` | Environment name used for the plan and deployment environment |
| `TERRAFORM_VERSION` | Terraform version installed on the runner |
| `ENABLE_ADO_APPLY` | `false` for plan-only; `true` to allow Apply |
| `FORTIGATE_ADMIN_PASSWORD` | Protected password mapped to `TF_VAR_fortigate_admin_password` |
| `FORTIGATE_ADMIN_SSH_PUBLIC_KEY` | Protected key mapped to `TF_VAR_fortigate_admin_ssh_public_key` |

The pipeline derives `TERRAFORM_BACKEND_FILE` and `TERRAFORM_VAR_FILE` from
`ENVIRONMENT` and publishes both binary and text plan artifacts. Terraform
downloads the public `azure-template` modules during initialization.

## 8. Safe cleanup and rollback

Keep `tfplan`, `tfplan.txt`, state files, credentials, and provider caches out
of Git. If a plan is no longer valid, create a new plan rather than reusing it.

There is no automatic rollback for Azure infrastructure. Stop, preserve the
plan and apply output, identify the affected resources, and use a reviewed
Terraform change or an Azure recovery procedure. Never run `terraform destroy`
against a shared hub or production backend without explicit approval and a
resource-by-resource review.
