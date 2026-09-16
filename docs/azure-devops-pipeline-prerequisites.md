# Azure DevOps Pipeline Prerequisites

This checklist describes the external Azure DevOps and Azure configuration
required by `azure-pipelines.yml`. The repository can validate Terraform
locally, but it cannot determine whether these objects and permissions already
exist in Azure DevOps or Azure.

The consolidated [README](../README.md#deployment-and-pipeline) also includes
this checklist, backend details, pipeline stage behavior, and the deployment
sequence. Keep both documents aligned with the YAML and helper scripts.

## Required Pipeline Variables

The pipeline imports two variable groups:

- `iac-shared-vars` for shared runner configuration.
- `fortigate-virtual-firewall` for repository-specific deployment values.

Azure DevOps resolves variable groups before runtime macro expansion, so the
YAML uses the repository name explicitly. Authorize both groups for this
pipeline.

The shared variable group must provide the required runner inputs. Values below
are previously documented examples, not values enforced or verified by this repo:

| Variable | Value | Purpose |
|---|---|---|
| `ADO_AGENT_POOL` | `IaCRunner` | Agent pool used by all jobs |
| `ADO_AGENT_VM_IMAGE` | `ubuntu-latest` | Agent image value used by the pipeline |
| `ADO_PACKAGE_PYTHON_VERSION` | `3.11` | Shared Python version; currently not consumed by this pipeline |

The repository-specific variable group must provide:

| Variable | Status | Purpose |
|---|---:|---|
| `ENVIRONMENT` | Required | Plan artifact suffix and Azure DevOps Environment name |
| `TERRAFORM_VAR_FILE` | Required | Terraform variable file path, normally `environments/$(ENVIRONMENT)/terraform.tfvars` |
| `TERRAFORM_VERSION` | Required | Terraform version downloaded by the pipeline |
| `ENABLE_ADO_APPLY` | Required | Required even for validation; set `false` for plan-only, `true` to permit Apply |

This value is defined in the YAML:

| Variable | Default |
|---|---|
| `TERRAFORM_BACKEND_FILE` | `environments/$(ENVIRONMENT)/backend.hcl` |

Keep `ENABLE_ADO_APPLY` in the repository-specific variable group. The YAML
does not override it. Leaving it undefined fails the initial required-variable
check; an unset value is not a supported plan-only mode.

The Azure Resource Manager service connection is a compile-time pipeline
parameter rather than a Library variable:

| Parameter | Default |
|---|---|
| `azureServiceConnection` | `sc-ccoe-iac-devops-dev` |
| `useEnvironmentApprovals` | `false` |
| `deploymentEnvironmentName` | `$(ENVIRONMENT)` |

Azure DevOps validates service-connection references while compiling the
pipeline. A runtime macro such as `$(AZURE_SERVICE_CONNECTION)` can remain
unresolved at that point and be interpreted as the literal service-connection
name. Override the parameter when queuing the pipeline if another authorized
service connection is required.

The current pool declaration supplies both `name` and `vmImage`. Confirm this
matches the selected agent-pool type. A self-hosted pool normally selects an
agent through the pool name and capabilities; a Microsoft-hosted pool normally
selects an image.

## Conditional FortiGate Secrets

When `features.enable_fortigate = true`, you may provide either of these as a
secret variable:

| Azure DevOps secret | Terraform input |
|---|---|
| `FORTIGATE_ADMIN_PASSWORD` | `fortigate_admin_password` |
| `FORTIGATE_ADMIN_SSH_PUBLIC_KEY` | `fortigate_admin_ssh_public_key` |

The module evaluates Key Vault fallback separately for each credential. A missing
password input reads `fortigate-admin-password`; a missing SSH-key input reads
`fortigate-admin-pubkey`, from `kv-ccoe-cc-dev` in the shared IaC RG.
Providing one input does not suppress the other lookup. With current nonempty
secret names, each missing input needs a readable fallback; to deliberately use
only password authentication, set the unused SSH-key fallback secret-name input
empty and supply the password.
This deployment explicitly sets `disable_password_authentication = false` for
both VMs, so an effective admin password is required. A configured SSH key is
retained alongside password authentication. FortiOS `admin-ssh-password` must
also allow password login; the Azure provisioning setting does not verify
the live FortiOS configuration.
Changing this Azure VM setting forces VM replacement in the AzureRM provider.
Review the plan and arrange a safe maintenance/migration procedure before apply.
FortiGate-disabled runs do not need these
module credentials. The plan script removes unresolved optional secret macros.

Do not store these values in an environment tfvars file. The generated binary plan can
contain sensitive values and its artifact permissions and retention must be
restricted accordingly.

## Azure Service Connection

Create or reuse the service connection selected by the
`azureServiceConnection` parameter, authorize it for this pipeline, and
preferably use workload identity federation.

It requires:

- Permission to read and write Terraform state in:
  - subscription `1ec5edd4-5654-4246-8027-b29ef63b3393`
  - resource group `rg-ccoe-iac-cc-dev`
  - storage account `stccoeiacccdev`
  - container `terraform`
- Backend authentication permissions for the selected environment. For Entra
  blob access, a role such as `Storage Blob Data Contributor` is appropriate.
  This repo does not explicitly select `use_azuread_auth`; verify the actual
  backend authentication path and any required account-key lookup permissions.
- Permission to read secrets from the shared IaC Key Vault
  `kv-ccoe-cc-dev`, such as the `Key Vault Secrets User` role.
- Permission to read `vnet-hub-platform-dev`.
- Permission to manage subnets, NSGs, and subnet associations in
  `rg-platform-dev`.
- Permission to create `rg-ba-cc-dev-vfirewall` when absent and manage its
  VMs, NICs, disks, internal LB, route table, and role assignments.
- Marketplace agreement permissions when the module accepts image terms.
- Permission to read the target subscription and resource group.
- Microsoft Graph group-read permission when `app_admin_group` or
  `app_user_group` contains display names. Use Entra object IDs if the
  deployment identity should not perform group-name lookups.

Plan/apply derive the deployment subscription from the service connection's
Azure CLI context; the backend subscription does not independently select the
provider deployment subscription. Confirm the target before planning.

If the backend and deployment resources use different subscriptions, the same
service principal or workload identity must be authorized in both.

## Landingzone and VNet prerequisites

The landingzone repository owns the shared hub VNet address space. This
repository owns the FortiGate subnets and dependent resources inside the
existing `vnet-hub-platform-dev`. Configure the landingzone dev environment to
include the FortiGate address space:

```hcl
hub_address_space = [
  "10.167.32.0/20",
  "10.32.192.0/19",
]
```

Use the following landingzone reservations when Azure Firewall remains enabled
and FortiGate is deployed by this repository:

```hcl
firewall_subnet_prefixes                     = ["10.167.33.64/26"]
fortigate_external_subnet_prefixes           = ["10.32.192.0/25"]
fortigate_internal_subnet_prefixes           = ["10.32.193.0/25"]
fortigate_create_dedicated_vnet              = false
fortigate_virtual_network_name               = ""
fortigate_virtual_network_address_space      = ["10.32.224.0/22"]
fortigate_dedicated_external_subnet_prefixes = ["10.32.224.0/24"]
fortigate_dedicated_internal_subnet_prefixes = ["10.32.225.0/24"]
fortigate_admin_ssh_source_address_prefixes  = ["107.171.157.217/32"]
```

Keep `enable_fortigate = false` in the landingzone to avoid two Terraform
states managing the same FortiGate subnets. The dedicated-VNet values are
future fallback values and are ignored while
`fortigate_create_dedicated_vnet = false`. If Azure Firewall is not required,
remove its subnet reservation from the landingzone configuration.

The FortiGate repository currently uses these prefixes within the dedicated
`10.32.192.0/19` space:

| Purpose | Prefix |
|---|---|
| External | `10.32.192.0/25` |
| Internal | `10.32.193.0/25` |
| HA/heartbeat | `10.32.194.0/28` |
| Management | `10.32.195.0/24` |

Before plan/apply, verify that `vnet-hub-platform-dev` contains
`10.32.192.0/19`, the prefixes do not overlap existing subnets, and only this
repository manages the FortiGate subnet resources. If the prefixes change,
update the corresponding NSG rules, fixed NIC addresses, internal load-balancer
frontend, and route-table next hop in the same change.

## Azure DevOps Repository Access

The pipeline checks out:

- the current repository; and
- the `template` repository at `refs/heads/main`.

The pipeline's Build Service identity needs Read permission on the `template`
repository. If that repository is in another Azure DevOps project, use the
project-qualified repository name and grant the source project's Build Service
identity access to the target project and repository.

The pipeline maps `System.AccessToken` for Terraform initialization. Ensure the
job authorization scope and repository permissions allow any authenticated Git
operations required by the checked-out modules.

## Environment and Approvals

The default `useEnvironmentApprovals = false` uses a normal job and does not
require an Azure DevOps Environment. Set it to `true` to create a deployment
job targeting the Environment named by `ENVIRONMENT`.

With `useEnvironmentApprovals = false`, a normal Apply job requires no Azure
DevOps Environment. When choosing environment approvals:

1. Create the effective `deploymentEnvironmentName` (defaults to `ENVIRONMENT`).
2. Authorize the pipeline to use it.
3. Configure the required approval and branch-control checks on that environment.
4. Set `useEnvironmentApprovals = true` and enable Apply after those controls exist.

The parameter chooses the job type; it does not create approval policies.

## FortiGate Deployment Prerequisites

Azure DevOps variables alone are not sufficient. Before applying or operating the VM:

- Accept the selected Fortinet Marketplace image terms for the deployment
  subscription.
- Confirm the BYOL image and `Standard_F8s_v2` size are available in
  `canadacentral`.
- Obtain a valid FortiGate BYOL license. The current pipeline does not upload
  or install the license.
- Provide either a secure pipeline credential or confirm that the shared IaC
  Key Vault contains `fortigate-admin-password` and `fortigate-admin-pubkey`.
- Confirm the configured subnet CIDRs do not overlap other subnets in the hub VNet:
  `10.32.192.0/25`, `10.32.193.0/25`, `10.32.194.0/28`, and
  `10.32.195.0/24`.
- The frontend/untrust and backend/trust configurations change from `/24` to
  `/25`. Their NIC IPs (`.4` and `.6`) and the internal load-balancer IP
  (`10.32.193.5`) remain unchanged. The external web NSG destination is
  `10.32.192.0/25`.
- For existing subnets, inspect active allocations before resizing and review a
  fresh Terraform plan. The reported HA/heartbeat resize from `/24` to the
  configured `/28` failed with `InUsePrefixCannotBeDeleted`; resolve its active
  allocation dependency or retain the existing prefix before retrying.
  Management remains configured as `/24`, with resizing deferred.
- The current configuration keeps the external load balancer and public IP
  disabled. Do not enable public ingress until explicit listener rules are
  approved; Azure does not permit an all-port HA Ports rule on a public load
  balancer.
- Review the generated NSG rules and private management path.
- Preserve the Azure-verified NIC order `external, ha, internal, management`.
  Complete the [FortiOS port/MAC check](fortigate-port-mapping.md) on both VMs
  before reordering attachments; the current change only pins existing order.
- IP forwarding is enabled on all four interfaces per VM. The shared NSG's
  priority-110 VirtualNetwork allow is broad: dedicated HA/management subnets
  do not imply source isolation. Approve management/transit source ranges and
  review default rules before tightening access; current rules remain unchanged.
- Confirm the shared `nsg-ba-cc-dev-vfirewall` is associated with all four
  firewall subnets, and verify private management connectivity to both
  `10.32.195.4` and `10.32.195.5` through the approved external management service.
- Workload routing is pending: `route_table_subnet_ids` is empty. Identify the
  approved workload subnet IDs before enabling associations to
  `rt-ba-cc-dev-vfirewall` (`0.0.0.0/0` to `10.32.193.5`), then validate
  forwarding and return-path symmetry.
- Validate the internal LB frontend `10.32.193.5`, backends `10.32.193.4` and
  `10.32.193.6`, TCP probe `8008`, HA Ports, floating IP, and frontend zones 1/2.
- Configure and validate FortiOS HA, licensing, policies, and failover separately;
  empty `fortigate_custom_data` does not bootstrap these settings.
- Verify FortiManager/Bastion access and FortiAnalyzer/Log Analytics forwarding
  separately. The current diagram marks these as external, unverified integrations.
- Verify a system-assigned managed identity on each VM and one custom route-updater
  assignment per identity, scoped to `rt-ba-cc-dev-vfirewall`. The role permits
  table reads and child-route reads/writes only; no deletion or whole-table writes.
- Use the Azure RBAC panel in the [full architecture diagram](images/fortigate-full-architecture.png)
  and the [README permission summary](../README.md#vm-identity-route-permissions)
  when reviewing the two assignments. After apply, check the
  `fortigate_managed_identity_principal_ids` and `fortigate_route_role_assignment_ids`
  outputs against Azure IAM; the diagram itself is not deployment evidence.
- The deployment principal needs `Microsoft.Authorization/roleDefinitions/write`
  over the custom role's assignable resource-group scope and
  `Microsoft.Authorization/roleAssignments/write` at the route-table scope
  (or inherited permissions). Include the companion FortiGate module output update.
- Before enabling FortiOS route automation, verify managed-identity authentication,
  connector API permissions, and ownership of Terraform-managed routes. These
  RBAC grants do not configure the SDN connector or workload subnet associations.

## What Cannot Be Verified from This Repository

The following must be checked in Azure DevOps and Azure:

- Whether `iac-shared-vars` and `fortigate-virtual-firewall` exist, contain the
  documented values, and are authorized.
- Whether either FortiGate secret is configured, or the shared IaC Key Vault
  fallback secrets are present and readable.
- Whether the named agent pool and image are valid together.
- Whether the service connection exists, is authorized, and has the required
  backend and deployment permissions.
- Whether the `template` repository checkout is authorized.
- Whether the Azure DevOps Environment exists and has approvals configured.
- Whether Marketplace terms are accepted and the BYOL license is available.
