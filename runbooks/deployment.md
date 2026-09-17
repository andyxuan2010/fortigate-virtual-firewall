# Deployment Runbook

This runbook covers local Terraform use and the automated GitHub Actions/Azure
DevOps deployment paths.

## Prerequisites

- Azure subscription access to the target subscription and resource groups.
- Terraform version defined by the workflow.
- The public template repository `andyxuan2010/azure-template`, or another
  compatible public template configured through `GH_TF_TEMPLATE_REPO`.
- Existing resources identified in the operations reference either imported or
  intentionally removed before apply.
- A protected FortiGate administrator password or SSH public key supplied as a
  pipeline secret when required by the selected image/module configuration.

## Backend initialization

`TF_CLI_ARGS_init` is not a substitute for a backend configuration file unless
the value is correctly quoted as a single environment-variable value. The
reliable command is:

```powershell
terraform init -reconfigure -input=false `
  -backend-config="environments/dev/backend.hcl"
```

The dev plan must load its variable file explicitly:

```powershell
terraform plan -input=false `
  -var-file="environments/dev/terraform.tfvars"
```

Without that file, values such as `vnet_name`, `fortigate_deployment_mode`,
and feature flags fall back to defaults and import targets may not exist.

## Existing-resource imports

For a resource already present in Azure, first initialize the correct backend,
then use the dev variable file on the import command. Example:

```powershell
terraform import -input=false `
  -var-file="environments/dev/terraform.tfvars" `
  'module.rg[0].azurerm_role_assignment.app_user_group["id:<group-object-id>"]' `
  '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Authorization/roleAssignments/<assignment-id>'
```

Do not delete or import a shared platform resource without confirming its owner
and scope.

## GitHub Actions behavior

`.github/workflows/terraform.yml` runs automatically for qualifying pushes to
`main` or `dev` and for pull requests. It performs:

1. Static formatting, Terraform validation, and security scanning.
2. Dev validation and plan by default.
3. Optional sandbox validation and plan when `DEPLOY_SANDBOX=true`.
4. Dev apply on a `main` push when repository variable
   `ENABLE_GITHUB_APPLY=true`, or on manual dispatch with the apply input
   enabled.

The current workflow intentionally does not auto-apply sandbox. The dev Azure
Environment must contain `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
`ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID`, unless OIDC is explicitly enabled
and configured.

The workflow uses the public template repository and does not require
`GH_TF_TEMPLATE_REPO_TOKEN`.

## Documentation publishing

`.github/workflows/pages.yml` runs on documentation changes to `main`,
generates `docs-manifest.json`, and publishes a clean snapshot to the public
stage repository. It requires the repository secret `STAGE_REPO_TOKEN`; the
target defaults to `andyxuan2010/fortigate-virtual-firewall` and can be changed
with `STAGE_REPOSITORY`.

The public repository has GitHub Pages enabled at:

<https://andyxuan.ca/fortigate-virtual-firewall/>

## Azure DevOps pipeline

The Azure DevOps path requires the repository-specific variable group and its
shared runner group. At minimum, configure:

| Variable | Purpose |
|---|---|
| `ENVIRONMENT` | Environment name, normally `dev` |
| `TERRAFORM_VAR_FILE` | Normally `environments/$(ENVIRONMENT)/terraform.tfvars` |
| `TERRAFORM_VERSION` | Terraform version used by the pipeline |
| `ENABLE_ADO_APPLY` | `false` for plan-only, `true` to permit apply |

The Azure DevOps service connection must be authorized for the target
subscription. Pipeline secrets must contain either the FortiGate admin password
or the approved SSH public key when the module requires it.

## Safe deployment sequence

1. Confirm the selected mode and existing-resource ownership.
2. Initialize with the environment backend file.
3. Run formatting, validation, and a refresh-aware plan.
4. Import or remove conflicting Azure resources and role assignments.
5. Review route next hops, NIC order, NSG scope, and VM sizing.
6. Apply only after the plan is understood.
7. Configure and validate FortiOS separately from Azure provisioning.
