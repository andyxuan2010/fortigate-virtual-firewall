# FortiGate Virtual Firewall (Staged Ingress)

This repository configures a switchable FortiGate architecture in the existing
Azure hub network. The `single` mode is a minimal one-node POC/demo deployment;
the `ha` mode is a two-node active-passive foundation. FortiGate administration
remains private. External load-balanced ingress is disabled until explicit
public listener rules are approved and configured.

This README consolidates all three repository Markdown files and distinguishes
checked-in configuration, dated Azure observations, and pending operational
work. Configuration is not evidence that the latest changes are applied.

Environment-specific Terraform inputs live under `environments/<environment>/`.
The checked-in deployment target is currently `dev`; add another environment
directory with its own `terraform.tfvars` and `backend.hcl` when needed.

## Contents

- [Design summary](#design-summary)
- [Architecture](#architecture)
- [Resource ownership](#resource-ownership)
- [Landingzone integration and address ownership](#landingzone-integration-and-address-ownership)
- [Interface mapping](#interface-mapping)
- [Security model](#security-model)
- [Feature controls](#feature-controls)
- [Deployment and pipeline](#deployment-and-pipeline)
- [Advanced options](#advanced-options)
- [Production readiness](#production-readiness)
- [Outputs](#outputs)
- [Key files](#key-files)

## Design Summary

The architecture is controlled by one input:

```hcl
fortigate_deployment_mode = "single" # or "ha"
```

The current dev deployment is `single` mode:

- One FortiGate BYOL VM: `fgt-ba-cc-dev-vfirewall-a`.
- `Standard_F4s_v2` VM size, with two NICs: external and internal.
- External and internal `/25` subnets only.
- No HA/heartbeat NIC, management NIC, or load balancer.
- No public IP; administration remains through the approved private path.
- A route table whose virtual-appliance next hop is the single internal NIC (`10.32.193.4`).
- One NSG associated with the two deployed FortiGate subnets.

When the mode is changed to `ha`, the preserved HA inputs enable two VMs,
external/internal/HA/management interfaces, the HA subnets, and the configured
load-balancer architecture. The mode switch does not configure FortiOS HA;
licensing, cluster configuration, policies, and operational validation remain
separate.

The FortiGate module provisions Azure infrastructure. FortiOS licensing,
active-passive cluster configuration, security policies, and operational
validation remain required before production traffic is enabled.

## Architecture

### Simple Architecture (single mode)

![Simple FortiGate architecture](docs/images/fortigate-simple-architecture.png)

The image above is a conceptual view of the deployed single-node POC. It now
also shows the shared resource-group ownership, route table and pending workload
associations, system identity/route RBAC, shared NSG, private administration
boundary, and external management/telemetry dependencies. Dashed external boxes
are dependencies that are not deployed or integration-verified by this repository.
Use the detailed configuration below for authoritative IPs, ownership, and status.

The simplified implementation provides one FortiGate VM with two NICs, external
and internal `/25` subnets, no HA or load balancers, and no public management
path. The shared NSG is an Azure control around the subnets; FortiOS policies
remain separate and must be configured on the appliance. Terraform resolves the
existing `vnet-hub-platform-dev` through an `azurerm_virtual_network` data source
and filters the full subnet/interface catalog to the resources required by the
selected mode. The diagram shows the currently deployed `Standard_F4s_v2` POC.

The HA design remains available by changing only
`fortigate_deployment_mode` to `"ha"`; the HA subnet, interface, and load-balancer
inputs are intentionally retained in the environment file.

### Architecture modes and VM sizing

| Mode | VMs | Enabled interfaces | Load balancers | Default VM size |
|---|---:|---|---|---|
| `single` | 1 | External, internal | None | `Standard_F4s_v2` currently; `Standard_F2s_v2` is the smallest supported candidate |
| `ha` | 2 | External, internal, HA, management | Configured HA load-balancer inputs | `Standard_F8s_v2` |

`fortigate_vm_size` is an optional override. Leave it empty to use the mode
default, or set an explicit Azure SKU. For the simplified two-NIC topology,
`Standard_F2s_v2` is smaller than `Standard_F4s_v2` and provides 2 vCPUs, 4 GiB
of memory, and up to 2 NICs. Fortinet lists `Standard_F2s_v2` as supported for
FortiGate-VM with the `FG-VM02`/`FG-VM02v` BYOL license class. Confirm the
marketplace image version and BYOL entitlement before resizing; sustained
inspection, UTM, proxy, or other production workloads should not use the POC
minimum without a capacity test.

The dev VM was provisioned as `Standard_F4s_v2`, so changing to `Standard_F2s_v2`
will be a separate resize/replacement decision and is not performed by this
documentation update.

### Shared implementation across both modes

The following full-architecture elements are intentionally shared with the
simple mode and are already implemented there:

| Shared element | Single mode behavior | HA mode behavior |
|---|---|---|
| Existing hub VNet | Uses `vnet-hub-platform-dev` | Uses the same existing VNet |
| External/internal subnets | Creates and uses the two required `/25` subnets | Uses the same external/internal subnets |
| Azure NSG | Shared NSG associated with the two active subnets | Shared NSG associated with all four active subnets |
| Route table | `0.0.0.0/0` points to `10.32.193.4` | `0.0.0.0/0` points to the internal LB at `10.32.193.5` |
| Managed identity and route RBAC | One VM identity and table-scoped route updater role | One identity and assignment per VM |
| NIC controls | Static private IPs and Azure IP forwarding | Same controls on every enabled NIC |
| VM provisioning | BYOL Marketplace image, Key Vault credentials, Premium SSD, standard tags | Same provisioning controls per VM |
| Application RBAC | Group access on the VM and its NICs | Group access on both VMs and all their NICs |
| Public administration | No public IP | No public IP |

The full diagram also shows FortiManager/Azure Bastion and FortiAnalyzer/Log
Analytics, but those are external dependencies and are not deployed by either
mode. Workload route-table associations are also intentionally empty until
approved workload subnet IDs are supplied.

### Full Architecture (HA mode)

![Full FortiGate infrastructure with VM and LB IPs, managed identities, and route-table-scoped Azure RBAC](docs/images/fortigate-full-architecture.png)

The current simplified deployment has one system-assigned identity and one
route-table-scoped assignment. In HA mode, the same pattern produces one
identity and assignment per FortiGate VM. See [VM identity route permissions](#vm-identity-route-permissions)
for the exact actions and deployment requirements. The diagram's RBAC panel
describes the HA configuration, not confirmation that the grants are applied in
Azure.

The diagram shows the configured external subnet `10.32.192.0/25` and internal
subnet `10.32.193.0/25` in the current implementation. The previously reported
HA subnet resize issue is described under Subnet Sizing below.

The HA diagram labels all four private interfaces on each VM and the internal
load-balancer frontend. In the current single-mode deployment, the active
interfaces are external `10.32.192.4` and internal `10.32.193.4`; the route-table
next hop is the internal address. These values and Azure IP forwarding were
verified through the 2026-09-16 Terraform deployment. The checks do not verify
FortiOS port mapping, licensing, or operational HA.

The HA implementation remains available with two FortiGate appliances distributed
across availability zones and dedicated external, internal, HA/heartbeat, and
management networks.

The configured attachments and pending traffic paths are:

1. In HA mode, FortiGate A and B have separate zone placement and four NICs each.
   The repository does not establish an operational FortiOS HA cluster:
   `fortigate_custom_data` is empty; licensing, clustering, policies, and
   failover tests remain external configuration and validation steps.
2. In HA mode, HA/heartbeat interfaces are prepared for synchronization. The configured
   `/28` prefix has a reported resize failure; verify the live prefix before
   treating the subnet change as complete.
3. In HA mode, the internal Standard Load Balancer has frontend `10.32.193.5` in the
   internal subnet, backends `10.32.193.4` and `10.32.193.6`, HA Ports,
   floating IP enabled, TCP probe `8008`, and frontend zones `1` and `2`.
4. `rt-ba-cc-dev-vfirewall` contains `0.0.0.0/0` with a virtual-appliance next hop:
   `10.32.193.4` in single mode or `10.32.193.5` in HA mode. `route_table_subnet_ids = []`, so this repository configures
   zero workload subnet associations. Workload routing and flow symmetry are
   not established or verified. Workloads belong in separate hub/spoke subnets,
   not in the dedicated firewall internal subnet.
5. In HA mode, both A (`10.32.195.4`) and B (`10.32.195.5`) connect to the management subnet.
   FortiManager/Azure Bastion are external dependencies; their deployment and
   integration are not verified here. No public management frontend is configured.
6. FortiAnalyzer/Log Analytics are external telemetry dependencies. The current
   configuration does not establish log forwarding or confirm receipt of telemetry.

Diagram legend: solid lines represent configured attachments; dashed lines
represent pending paths or external integrations, not validated traffic flow.
The telemetry connector represents the appliances' proposed logging integration;
it does not imply that only FortiGate B requires logging configuration.

Deployment region is `canadacentral` (Canada Central). The existing VNet
`vnet-hub-platform-dev`, its mode-selected firewall subnets, and the shared NSG
`nsg-ba-cc-dev-vfirewall` are in `rg-platform-dev`. The VMs, NICs,
optional internal LB, and route table are in `rg-ba-cc-dev-vfirewall`.
Resource-group ownership is separate from network/subnet membership.

The one shared NSG is associated with the two single-mode or four HA firewall
subnets, as applicable. Each VM has a system-assigned managed identity enabled
in configuration, with a custom route-updater role scoped only to
`rt-ba-cc-dev-vfirewall` for each identity.
Existing admin/user group RBAC is separate from VM identity permissions.

External ingress is unavailable while the external load balancer is disabled.
When re-enabled, the public Standard Load Balancer must use explicit listener
rules rather than an all-port HA Ports rule, which Azure does not permit on a
public load balancer.

Before adopting this design, validate the selected Fortinet-supported Azure HA
pattern, image/SKU requirements, load-balancer probes and rules, route failover
behavior, and whether public ingress is required. If Internet ingress is
approved, the external load balancer may have a controlled public frontend;
FortiGate administrative interfaces must remain private.

The infrastructure supports both the single-node POC and the two-node
load-balancer architecture. FortiOS unicast FGCP, health-probe responses, and
operational failover are not configured by the current empty bootstrap. The
external LB is disabled; the HA diagram must not be read as a fully operational
dual-LB deployment.

| Capability | Configured now | Operational target |
|---|---|---|
| FortiGate instances | One VM in single; two VMs in HA | Validated active-passive cluster in HA |
| Availability | Single VM; HA uses availability zones | Availability-zone separation in HA |
| External traffic endpoint | Disabled during staged rollout | Standard Load Balancer with explicit rules |
| Internal next hop | Single NIC IP in single; internal LB in HA | Stable HA load-balancer next hop |
| Management | No dedicated NIC in single; dedicated subnet in HA | Dedicated management subnet in HA |
| HA synchronization | HA-only NICs; prefix and cluster validation pending | Validated HA synchronization |
| Routing | UDR prepared; workload association pending | UDRs with symmetric routing |
| Operations | External integrations not verified | FortiManager and FortiAnalyzer/Log Analytics |
| VM managed identities | System-assigned per VM; route-updater role on the managed route table | Validate the FortiOS connector before enabling route automation |
| Public administration | Not allowed | Not allowed |

## Resource Ownership

| Resource | Managed by this repository | Notes |
|---|---:|---|
| Existing hub VNet | No | Looked up by name; it is not created or modified as a VNet resource |
| FortiGate subnets | Yes | Created inside the existing hub VNet |
| FortiGate NSG | Yes | Associated with the dedicated subnets |
| FortiGate NICs | Yes, through the FortiGate module | Private IP configuration only |
| FortiGate VM | Yes, through the FortiGate module | Controlled by `features.enable_fortigate`; enabled |
| VM managed identities | Yes, through the FortiGate module | Separate identity per VM; route-table-scoped custom RBAC in the root deployment |
| FortiManager / Azure Bastion | No | External management dependency; integration unverified |
| FortiAnalyzer / Log Analytics | Not enabled by this deployment | External telemetry dependency; integration unverified |
| Hub/spoke workloads | No | Separate workload subnets; route-table associations pending |
| FortiGate RBAC | Yes, through the FortiGate module | Admin groups receive Contributor on VMs/NICs; user groups receive Reader on VMs |
| Public IP | No | Add only with approved external listener rules |
| Route tables and UDRs | Yes, prepared by this repository | Workload subnet associations remain an explicit input |
| FortiOS policies and routing | No | Configure manually, with custom data, or through FortiManager |
| FortiGate license | No | A valid BYOL license is required by the current defaults |

## Landingzone integration and address ownership

The landingzone repository owns the shared hub VNet address space. This
repository owns the FortiGate subnets, private IP assignments, NSG, NICs, VMs,
load balancer, and route table inside that VNet. Only one repository should
manage the FortiGate subnet resources.

The dev hub VNet should include the dedicated FortiGate address space:

```hcl
hub_address_space = [
  "10.167.32.0/20",
  "10.32.192.0/19",
]
```

Recommended landingzone values for `environments/dev/terraform.tfvars` are:

```hcl
# Azure Firewall subnet; keep only when Azure Firewall remains enabled.
firewall_subnet_prefixes = ["10.167.33.64/26"]

# Reserved for this standalone FortiGate repository.
fortigate_external_subnet_prefixes = ["10.32.192.0/25"]
fortigate_internal_subnet_prefixes = ["10.32.193.0/25"]

# The standalone FortiGate repository deploys into the existing hub VNet.
fortigate_create_dedicated_vnet         = false
fortigate_virtual_network_name          = ""
fortigate_virtual_network_address_space = ["10.32.224.0/22"]

# Future dedicated-VNet fallback; ignored while the setting above is false.
fortigate_dedicated_external_subnet_prefixes = ["10.32.224.0/24"]
fortigate_dedicated_internal_subnet_prefixes = ["10.32.225.0/24"]

fortigate_admin_ssh_source_address_prefixes = [
  "107.171.157.217/32",
]
```

The landingzone must keep `enable_fortigate = false` when this repository is
the FortiGate deployment owner. The `firewall_subnet_prefixes` value is for
Azure Firewall and is separate from the FortiGate external and internal
subnets. If Azure Firewall is disabled, remove that reservation from the
landingzone configuration rather than assigning it to FortiGate.

The standalone repository currently allocates the remaining FortiGate ranges
from `10.32.192.0/19` as follows:

| Purpose | Prefix |
|---|---|
| External | `10.32.192.0/25` |
| Internal | `10.32.193.0/25` |
| HA/heartbeat | `10.32.194.0/28` |
| Management | `10.32.195.0/24` |

Before applying either repository, confirm that the hub VNet contains
`10.32.192.0/19`, these subnet names and prefixes are not already managed by
another Terraform state, and the candidate ranges do not overlap existing
subnets. Any future CIDR change must also update the NSG rules, fixed NIC IPs,
internal load-balancer frontend, route-table next hop, and documentation in
this repository together.

## Interface Mapping

In single mode, the deployed VM has the attachment sequence `external → internal`
and IP forwarding enabled on both NICs. In HA mode, the preserved target
sequence is `external → ha → internal → management` on each VM. The definition-list
order does not determine attachment order. FortiOS port names have not been
verified on the appliances: complete the [port mapping check](docs/fortigate-port-mapping.md)
before changing attachment order or applying port-specific FortiOS configuration.

| Interface | Subnet | FortiGate A (zone 1) | FortiGate B (zone 2) | Purpose |
|---|---|---|---|---|
| External | `10.32.192.0/25` | `10.32.192.4` | `10.32.192.6` | External-facing interfaces |
| Internal | `10.32.193.0/25` | `10.32.193.4` | `10.32.193.6` | Trusted hub/spoke side |
| HA/heartbeat | `10.32.194.0/28` | `10.32.194.4` | `10.32.194.5` | Dedicated interfaces for planned FGCP synchronization |
| Management | `10.32.195.0/24` | `10.32.195.4` | `10.32.195.5` | Private FortiManager/Bastion access; resize pending active allocations |

Only the external and internal rows are deployed in the current single-mode
POC. The HA and management rows are retained for the `ha` mode.

### Azure NIC evidence and FortiOS verification

| Position | Role | A IP | A Azure MAC | B IP | B Azure MAC |
|---|---|---|---|---|---|
| 1 (primary) | External | 10.32.192.4 | 7C-ED-8D-36-01-1C | 10.32.192.6 | 7C-ED-8D-35-02-E0 |
| 2 | HA | 10.32.194.4 | 7C-ED-8D-36-01-4C | 10.32.194.5 | 7C-ED-8D-35-0B-03 |
| 3 | Internal | 10.32.193.4 | 7C-ED-8D-36-05-C4 | 10.32.193.6 | 7C-ED-8D-35-0D-D3 |
| 4 | Management | 10.32.195.4 | 7C-ED-8D-36-00-06 | 10.32.195.5 | 7C-ED-8D-35-03-F9 |

Position is **not a verified FortiOS port number**. Appliance-side mapping remains
pending because no authenticated FortiOS session was used for this check.

Before any attachment reorder:

1. Refresh the Azure VM network-interface list and NIC IP/MAC addresses; the
   snapshot above may change if NICs are replaced.
2. On each appliance through the approved private management path, inspect
   physical interface names/IPs with `get system interface physical`.
3. Inspect each actual interface using `diagnose hardware deviceinfo nic <name>`.
   Compare the permanent hardware MAC with Azure, not just an HA virtual MAC.
   See [Fortinet MAC inspection guidance](https://community.fortinet.com/fortigate-3/technical-tip-how-to-find-the-interface-s-mac-address-96896).
4. Record the confirmed port-to-role mapping for A and B. Review existing HA,
   management, routing, and policy references to those ports before any change.
5. Review a fresh Terraform plan. This preservation change should show no NIC
   sequence change. If it does, stop and reconcile drift; do not apply blindly.

The shared module validates complete, unique interface names and a primary-first
enabled order. Disabled interfaces are filtered for single-VM mode. Module callers
that omit `interface_order` retain legacy behavior for backward compatibility.


### Load balancer and UDR behavior

In HA mode, the internal load balancer, `lb-ba-cc-dev-vfirewall-internal`, uses the static
frontend IP `10.32.193.5`, also configured as the UDR next hop. Its internal
VM interface addresses are `10.32.193.4` and `10.32.193.6`. The external load
balancer remains disabled and has no provisioned public frontend IP in this
configuration. Probe defaults in the companion module are a five-second interval
and two probes. The UDR route name is `default_to_fortigate`; BGP propagation
retains the route module's enabled default.

In single mode, no load balancer is created and the UDR next hop is the single
FortiGate internal IP `10.32.193.4`.

The stable LB next hop does not require UDR switching to an individual VM IP
for normal LB-based failover. Neither live probe health nor failover has been
verified by the recorded NIC inventory.

The frontend/untrust and backend/trust subnet configurations have changed from
`/24` to `/25`. Management remains `/24`. HA/heartbeat is configured as `/28`,
but the reported Azure update failed because the existing `/24` has active
allocations. These configured sizes do not confirm successful deployment.

The first four and last IP addresses in each Azure subnet are reserved. The
configured `.4` addresses are the first assignable addresses.

### Subnet Sizing

Configured sizing for all four FortiGate subnets:

| Subnet | CIDR | Current status |
|---|---|---|
| Frontend / External / Untrust | `10.32.192.0/25` | Configured; verify active allocations before resizing |
| Backend / Internal / Trust | `10.32.193.0/25` | Configured; verify active allocations before resizing |
| HA / Heartbeat | `10.32.194.0/28` | Configured target; reported resize from `/24` blocked by active allocations |
| Management | `10.32.195.0/24` | Remains `/24` pending allocation migration |

Before applying the frontend and backend subnet reductions, verify Azure's active
allocations permit resizing. Configured NIC and load-balancer IPs remain within
the target `/25` ranges.

The frontend range is `10.32.192.0`–`10.32.192.127`; its configured NIC
addresses remain `10.32.192.4` and `10.32.192.6`. The backend range is
`10.32.193.0`–`10.32.193.127`; its NIC addresses remain `10.32.193.4` and
`10.32.193.6`, and the internal load-balancer/route next hop remains
`10.32.193.5`. The external web NSG rule now targets `10.32.192.0/25`.

Generate and review a fresh Terraform plan before applying these changes.
If Azure reports `InUsePrefixCannotBeDeleted`, inspect the subnet's active
allocations and resolve the resize dependency before retrying, or retain the
existing prefix in configuration until migration is ready.

## Security Model

### VM identity route permissions

| RBAC detail | Current configuration |
|---|---|
| Principals | FortiGate A and B system-assigned managed identities |
| Assignments | Two in HA mode, one per VM identity |
| Assignment scope | Only `rt-ba-cc-dev-vfirewall` |
| Allowed by this role | Read route table; read, create, and update child routes |
| Not granted by this role | Route/table deletion, whole-table writes, other network changes, or RBAC management |
| Automation status | Authorization configured; FortiOS SDN connector setup and live validation remain separate |

`fortigate-route-rbac.tf` defines `FortiGate Route Updater - rg-ba-cc-dev-vfirewall`
and assigns that custom role to
both VM system-assigned identities at the resource ID of
`rt-ba-cc-dev-vfirewall`. No other route tables are included. The role definition
is available within the firewall resource group, but the assignments grant access
only at the route-table scope. Permissions are explicitly limited to:

- `Microsoft.Network/routeTables/read`
- `Microsoft.Network/routeTables/routes/read`
- `Microsoft.Network/routeTables/routes/write`

These actions allow reading the table and creating/updating child routes; they
do not grant route/table deletion, whole-table writes, subnet associations, NIC
changes, or permission management. Azure RBAC cannot limit a route write to just
the next-hop property. Other existing role assignments may grant additional access.
See [Azure route-table permissions](https://learn.microsoft.com/en-us/azure/virtual-network/manage-route-table).

Both FortiGate and route-table features must be enabled for these grants to be
created. Outputs expose identity principal IDs and role-assignment IDs. Apply
must include the companion `template` module update that exports principal IDs.

This configures authorization only, not the FortiOS SDN connector. Validate the
connector's exact API calls before use: whole-table PUT operations require
`Microsoft.Network/routeTables/write`, which is intentionally not granted here.
The stable LB next hop remains `10.32.193.5`. Terraform still manages the inline
routes and may revert firewall changes on a later apply; agree route ownership
before enabling runtime updates. No lifecycle ignore rule is added.

### Network and administrative access

In `single` mode, the shared `nsg-ba-cc-dev-vfirewall` currently has one
configured inbound allow rule:

| Priority | Source | Destination | Protocol / ports |
|---|---|---|---|
| 110 | `VirtualNetwork` | Any | All |

In `ha` mode, the preserved configuration additionally enables the LB probe,
HA heartbeat, management, and approved external-web rules:

| Priority | Source | Destination | Protocol / ports |
|---|---|---|---|
| 100 | `AzureLoadBalancer` | Any | TCP 8008 |
| 110 | `VirtualNetwork` | Any | All |
| 120 | `10.32.194.0/28` | `10.32.194.0/28` | All |
| 130 | `VirtualNetwork` | `10.32.195.0/24` | TCP 22, 443 |
| 140 | `Internet` | `10.32.192.0/25` | TCP 80, 443 |

The external web allow exists in the preserved HA inputs even while external
LB/public IP creation is disabled. Single mode filters these HA-only and
management-specific rules from the deployed NSG.

The subnets are dedicated by purpose, not isolated by the current NSG rules.
Priority 110 (`allow_private_forwarding`) allows all protocols and ports from
the `VirtualNetwork` service tag to every firewall subnet. Later allow rules
for HA (120) and SSH/HTTPS management (130) do not narrow that allowance.
No source-specific management isolation is established by these rules.

The intended restricted boundaries, pending approved source ranges, are:

| Interface | Intended access boundary | Current enforcement |
|---|---|---|
| External/internal | Approved transit traffic and LB probes | Broad VirtualNetwork forwarding; external web allow rule also present |
| HA | Peer HA interfaces for synchronization | Broader VirtualNetwork access remains allowed |
| Management | Approved private administration sources on required ports | Broader VirtualNetwork access remains allowed |

This update documents the gap without tightening live connectivity. Before
enforcement, inventory management and transit sources, approve the required
ports, and review both custom and Azure default rules; removing one broad allow
alone does not establish isolation. FortiOS policy is a separate control.
Azure NIC IP forwarding permits forwarding at the Azure NIC layer; it neither
enables FortiOS policies nor bypasses NSG rules.

- No `azurerm_public_ip` resource is currently created or associated with a FortiGate NIC.
- Management must originate from an approved private path.
- Admin credentials must be supplied securely through the pipeline or the
  existing shared IaC Key Vault fallback; do not commit them to
  `environments/dev/terraform.tfvars`.
- `app_admin_group` accepts Entra group names or object IDs and grants
  Contributor on each FortiGate VM and NIC. `app_user_group` grants Reader on
  each FortiGate VM. Current tfvars uses the same object ID for both groups,
  so the Reader assignment does not reduce its Contributor privileges.
  Group display names require the deployment identity to
  read groups through Microsoft Graph; object IDs avoid that lookup.
- The VM cannot be enabled unless either an admin password or SSH public key is
  supplied directly or resolved from the shared IaC Key Vault fallback.
- NSG rules should be limited to approved source ranges and required ports.
- FortiOS firewall policies are separate from Azure NSG controls and must be
  configured before forwarding workload traffic.
- Traffic must not be routed through the staged deployment until return routes, health
  checks, rollback, and failure behavior have been tested.

### VM access

The FortiGate VMs are accessed through the approved private management path. No
public IP is assigned to the VM or to the external load balancer. In single mode
there is no dedicated management NIC; use the approved management path to the
external/internal interfaces. HA mode adds management addresses `10.32.195.4`
and `10.32.195.5`. The configured management model is `fortimanager`; this is
an operational label only and does not deploy FortiManager or Azure Bastion.

Use the local administrator account `azureadmin`:

- SSH key access uses the private key corresponding to the public key supplied
  through `TF_VAR_FORTIGATE_ADMIN_SSH_PUBLIC_KEY` or the Key Vault secret
  `fortigate-admin-pubkey`. The private key is not stored in this repository.
- The repository configuration sets `disable_password_authentication = false`
  for the VM(s), so password authentication is enabled at the Azure VM layer.
  The password must come from `TF_VAR_FORTIGATE_ADMIN_PASSWORD` or the Key Vault
  secret `fortigate-admin-password`; do not place it in an environment tfvars file.
- SSH keys and passwords are intentionally supported together. FortiOS must also
  have its `admin-ssh-password` setting enabled for password login to the
  FortiOS CLI. Azure VM password authentication does not by itself change or
  verify the live FortiOS setting.

The intended connection is to the management IP through the approved private
path, for example `ssh -i <private-key> azureadmin@10.32.195.4`. After login,
the FortiGate image presents the FortiOS CLI; commands such as `pwd`, `ls`, and
`cd` are Linux shell commands and return `Unknown action 0` at that prompt.
Use FortiOS commands or enter the shell only when explicitly required and
authorized.

The setting change is present in code but requires deployment. Because the
AzureRM provider treats changing `disable_password_authentication` as a VM
replacement, review the Terraform plan and arrange a maintenance or migration
procedure before applying it. Until that deployment completes, the existing
VMs retain their previously provisioned authentication state.

## Feature Controls

The principal controls are in `environments/dev/terraform.tfvars`:

```hcl
features = {
  enable_vnet                  = false
  enable_existing_vnet_subnets = true
  enable_nsg                   = true
  enable_fortigate             = true
  enable_route_table           = true
  enable_resource_group        = true
  enable_keyvault              = false
  enable_storageaccount        = false
}
```

`enable_vnet` must remain `false` because `vnet-hub-platform-dev` already exists.
The selected configuration sets `enable_fortigate = true`. Verify credentials,
Key Vault fallback behavior, image availability, Marketplace terms, and the plan
before applying. Public ingress approval applies only to a later ingress change.
The existing-VNet path creates the shared NSG directly; other generic modules
present in `main.tf` are not enabled merely because their blocks exist.

Selected values in `environments/dev/terraform.tfvars` are shown below; these are not necessarily
the generic defaults in `variables.tf`:

| Setting | Default |
|---|---|
| Deployment mode | `single` / one-node POC |
| License | `byol` |
| VM size | `Standard_F4s_v2` currently; blank selects mode-specific defaults |
| VM names | Single: `fgt-ba-cc-dev-vfirewall-a`; HA adds `fgt-ba-cc-dev-vfirewall-b` |
| Image | `fortinet / fortinet_fortigate-vm_v5 / fortinet_fg-vm / latest` |
| Marketplace plan | Publisher `fortinet`; product `fortinet_fortigate-vm_v5`; name `fortinet_fg-vm` |
| OS disk | `Premium_LRS`, caching `ReadWrite` |
| Admin username | `azureadmin` |
| VM authentication | SSH key plus password authentication (`disable_password_authentication = false`) |
| Azure NIC IP forwarding | Enabled on all enabled interfaces |
| Explicit NIC order | Single: `external, internal`; HA: `external, ha, internal, management` |
| Management model | `fortimanager` input; no FortiManager deployment or integration configured |
| Availability zones | HA places FortiGate A in zone 1 and B in zone 2; single uses one VM |
| External frontend | Disabled pending explicit listener approval |
| Internal next hop | Single VM at `10.32.193.4`; HA load balancer at `10.32.193.5` |
| Accelerated networking | Disabled |
| Managed identity | System-assigned per VM; custom route-update permissions scoped to the managed route table |
| Bootstrap/custom data | Disabled |
| Dedicated management NIC | Disabled in single; enabled in HA |
| HA interface | Disabled in single; enabled on the dedicated heartbeat subnet in HA |

## Deployment and Pipeline

### Backend and module compatibility

The backend type is defined in `backend.tf`; the active backend settings are in
`environments/dev/backend.hcl`:

| Field | Value |
|---|---|
| Subscription | `1ec5edd4-5654-4246-8027-b29ef63b3393` |
| Tenant | `d5b038fb-4b39-41cc-8a10-fba75212180b` |
| Resource group | `rg-ccoe-iac-cc-dev` |
| Storage account / container | `stccoeiacccdev` / `terraform` |
| State key | `fortigate-virtual-firewall/terraform.tfstate` |

Keep the companion `template` repository checked out beside this repository as
`azure-template` for local sources under `../azure-template/modules/`. The pipeline
uses the same `azure-template` checkout path. The pipeline must receive the companion module's
identity support, explicit ordering, and principal/order outputs on its checked-out
`main` branch. Local edits in that separate repository are not automatically
available to Azure DevOps.

Root `versions.tf` specifies Terraform >=1.0, but the FortiGate module requires
>=1.6. Choose a version satisfying all checked-out modules and provider constraints,
not just the root minimum. The image uses `latest`; the exact FortiOS version is
not pinned or verified. Module branch and image selection are not immutable release pins.

### Pipeline behavior

The pipeline triggers batched builds on `main` and declares `pr: none`.
It checks out self and `template` into sibling directories with clean checkouts.
Shared runner preparation/cache/cleanup comes from
`templates/shared-runner-hygiene.yml`.

| Stage | Implemented behavior |
|---|---|
| Validate | Check required variables/files, install Terraform, recursive fmt check, backend-disabled init, validate with a ten-minute timeout |
| Plan | Authenticate via the service connection, read backend settings, initialize, plan using the selected var file, publish binary/text artifacts and change summary |
| Apply | After success and only when `ENABLE_ADO_APPLY=true`, download and apply the saved plan with auto-approve |

Artifacts are `terraform-plan-$(ENVIRONMENT)` and
`terraform-plan-$(ENVIRONMENT)-text`; the binary filename is `terraform.tfplan`.
Apply does not create a new plan. The helper supports service-connection client
secret or OIDC authentication; VM identity RBAC does not authorize the pipeline.
The current YAML validation script does not run the mocked module tests.

### Required Pipeline Variables

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

### Conditional FortiGate Secrets

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

### Azure Service Connection

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

### Azure DevOps Repository Access

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

### Environment and Approvals

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

### FortiGate Deployment Prerequisites

Azure DevOps variables alone are not sufficient. Before applying or operating the VM:

Accept the Fortinet Marketplace image terms in the deployment subscription:

```powershell
az vm image terms accept `
  --subscription 1ec5edd4-5654-4246-8027-b29ef63b3393 `
  --publisher fortinet `
  --offer fortinet_fortigate-vm_v5 `
  --plan fortinet_fg-vm
```

Marketplace terms are accepted once per subscription for this image. Verify the
terms before running Terraform:

```powershell
az vm image terms show `
  --subscription 1ec5edd4-5654-4246-8027-b29ef63b3393 `
  --publisher fortinet `
  --offer fortinet_fortigate-vm_v5 `
  --plan fortinet_fg-vm `
  --query accepted -o tsv
```

The command must return `true`. The root configuration manages the Marketplace
agreement before creating the FortiGate VMs, so Terraform planning/apply will
fail if the terms cannot be accepted by the deployment identity.

- Accept the selected Fortinet Marketplace image terms for the deployment
  subscription.
- Confirm the BYOL image and selected VM size are available in `canadacentral`.
  The current single-mode POC uses `Standard_F4s_v2`; `Standard_F2s_v2` is the
  smallest supported two-NIC candidate and requires the matching `FG-VM02` or
  `FG-VM02v` BYOL entitlement.
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
- Preserve the mode-specific NIC order: single `external, internal`; HA
  `external, ha, internal, management`. Complete the [FortiOS port/MAC check](docs/fortigate-port-mapping.md)
  before reordering attachments.
- IP forwarding is enabled on all enabled interfaces. The shared NSG's
  priority-110 VirtualNetwork allow is broad; approve management/transit source
  ranges and review default rules before tightening access.
- Confirm the shared `nsg-ba-cc-dev-vfirewall` is associated with the two
  single-mode or four HA firewall subnets, as applicable.
- Workload routing is pending: `route_table_subnet_ids` is empty. Identify the
  approved workload subnet IDs before enabling associations to
  `rt-ba-cc-dev-vfirewall` (`0.0.0.0/0` to `10.32.193.4` in single mode or
  `10.32.193.5` in HA), then validate
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
- Use the Azure RBAC panel in the [full architecture diagram](docs/images/fortigate-full-architecture.png)
  and the [README permission summary](#vm-identity-route-permissions)
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

### What Cannot Be Verified from This Repository

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


### Local review and deployment sequence

From this repository with the companion module checkout and credentials ready:

```powershell
terraform init -reconfigure -backend-config="environments/dev/backend.hcl"
terraform fmt -check
terraform validate
terraform plan -var-file=environments/dev/terraform.tfvars -out=tfplan
terraform show tfplan
```

1. Resolve authentication, required variables, module checkout, and credentials
   before planning or applying. Do not apply infrastructure first and supply
   required VM credentials afterward.
2. Select the architecture in `environments/dev/terraform.tfvars`:
   `fortigate_deployment_mode = "single"` or `"ha"`.
3. Review live prefixes/allocations, NIC order, role scopes, and the complete plan.
   Resolve the reported HA resize failure or preserve the existing prefix.
4. Apply only the reviewed change set through the chosen deployment workflow.
5. Verify subnet NSG associations, preserved NIC order, IP forwarding, identities,
   and the two table-scoped assignments against Azure. Validate the internal LB
   frontend/backends, TCP 8008 probe, HA Ports, floating IP, and zones when in HA mode.
6. Install licensing and configure FortiOS HA when in HA mode, plus policies,
   routing, and management separately. Test failover, recovery, return paths,
   rollback, and controlled traffic.
7. Populate approved workload subnet IDs only after those tests; current
   configuration has no associations. Separately validate logging/management services.
8. Resolve Terraform-versus-appliance route ownership before enabling SDN updates.
   Add public listener support only as a separate reviewed ingress change; the
   disabled external-LB input still selects HA Ports and is not ready for a
   simple public-enable toggle.

Companion module tests, separately from the pipeline, on Windows:

```powershell
terraform '-chdir=../azure-template/modules/fortigate' test '-filter=tests\unit.tftest.hcl'
```

Use `tests/unit.tftest.hcl` as the filter on Linux. Confirm tests actually execute;
a zero-test result is not coverage. During the 2026-09-15 work, Terraform
validation and 11 mocked module tests passed. No deployment or operational HA
claim follows from those checks.

## Advanced Options

The Terraform model also preserves advanced settings:

- `fortigate_deployment_mode = "single"` can be used for lower environments.
- Additional interface definitions can add other private NICs; include them in
  the explicit order and verify VM NIC limits.
- `enabled_in_modes = ["ha"]` limits an interface to HA deployments.
- `fortigate_zone` can pin an instance to an availability zone.
- `accelerated_networking_enabled = true` enables it per supported NIC/VM.
- `fortigate_custom_data` can provide FortiOS bootstrap configuration.
- `fortigate_license_type`, image, plan, version, and VM size remain variable.
- The management access model is an input label for the supported private,
  Azure Bastion, or FortiManager paths; it does not deploy those services.

The module creates the Azure HA topology and probes, but FortiOS heartbeat
configuration, synchronization, policy, licensing, and operational testing
must still be completed and validated with Fortinet.

## Production Readiness

Before enabling production traffic, complete the remaining operational review
covering:

- UDR ownership, symmetric routing, return paths, and failover behavior.
- FortiManager/FortiAnalyzer integration, logging, monitoring, and alerting.
- Backup, upgrade, rollback, license, and break-glass procedures.
- Capacity, throughput, session limits, and supported VM/image combinations.
- NSG and FortiOS policy approval.

## Outputs

| Output | Meaning |
|---|---|
| `fortigate_private_ip_addresses` | NIC IPs keyed by instance/interface |
| `fortigate_virtual_machine_ids`, `fortigate_network_interface_ids` | Resource IDs |
| `fortigate_interface_order` | Configured Azure NIC order, not FortiOS port names |
| `fortigate_managed_identity_principal_ids` | Identity principals keyed by VM suffix |
| `fortigate_route_role_assignment_ids` | Table-scoped assignments keyed by VM suffix |
| `fortigate_internal_load_balancer_id`, `fortigate_internal_load_balancer_frontend_ip` | Internal LB ID/address |
| `fortigate_external_load_balancer_id`, `fortigate_external_public_ip_id` | Null when corresponding resources are disabled |
| `fortigate_route_table_id` | Managed route table |
| `fortigate_app_admin_group_role_assignment_ids`, `fortigate_app_user_group_role_assignment_ids` | Group RBAC assignments |

Outputs reflect Terraform evaluation/state and must be compared with Azure for
deployment verification.

## Key Files

- `main.tf`: existing hub VNet lookup, FortiGate subnets, NSG, subnet
  associations, and the reusable FortiGate module invocation.
- `fortigate-route-rbac.tf`: custom route-updater role and route-table-scoped
  assignments for the FortiGate VM managed identities.
- `docs/fortigate-port-mapping.md`: dated Azure NIC order/IP/MAC evidence and
  the required FortiOS mapping checks before any attachment reorder.
- `docs/images/fortigate-simple-architecture.png`: single-node POC architecture overview.
- `docs/images/fortigate-full-architecture.png`: full HA architecture;
  includes `/25` external/internal subnets, both VMs' interface IPs, and the
  internal LB frontend IP, plus an Azure RBAC scope/permissions panel.
  External ingress is staged off.
- `docs/azure-devops-pipeline-prerequisites.md`: Azure DevOps variables,
  secrets, permissions, repository access, and environment requirements.
- `environments/dev/terraform.tfvars`: current dev implementation settings, interface mappings, load
  balancers, NSG rules, and the prepared UDR.
- `variables.tf`: defaults, types, validations, and optional advanced inputs.
- `outputs.tf`: deployed FortiGate private IP addresses.
- `azure-pipelines.yml`: Terraform CI/CD workflow.

## Architecture References

- [Fortinet: HA for FortiGate-VM on Azure](https://docs.fortinet.com/document/fortigate-public-cloud/8.0.0/azure-administration-guide/983245/ha-for-fortigate-vm-on-azure)
- [Microsoft: Deploy highly available network virtual appliances](https://learn.microsoft.com/azure/architecture/networking/guide/network-virtual-appliance-high-availability)
- [Microsoft: Azure Load Balancer HA Ports](https://learn.microsoft.com/azure/load-balancer/load-balancer-ha-ports-overview)
