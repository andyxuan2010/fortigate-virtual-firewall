# Operations Reference

This reference records network controls, FortiGate interface evidence,
troubleshooting guidance, and production-readiness boundaries.
Configuration paths are relative to the Azure Terraform root:
`platforms/azure/`.

## FortiGate interface mapping

The last Azure inspection recorded the following HA attachment order. This is
Azure NIC evidence, not a verified FortiOS port-number mapping.

| Position | Role | VM A IP | VM B IP |
|---|---|---|---|
| 1 (primary) | External | `10.32.192.4` | `10.32.192.6` |
| 2 | HA | `10.32.194.4` | `10.32.194.5` |
| 3 | Internal | `10.32.193.4` | `10.32.193.6` |
| 4 | Management | `10.32.195.4` | `10.32.195.5` |

In single mode, only the external and internal interfaces are enabled. Before
changing attachment order, inspect the appliance through the approved private
management path:

```text
get system interface physical
diagnose hardware deviceinfo nic <name>
```

Compare permanent hardware MAC addresses with Azure NIC data. Do not infer a
FortiOS interface number from Azure NIC position alone.

## Network and security controls

- Azure IP forwarding is enabled on each enabled FortiGate NIC.
- The shared NSG permits the configured private hub/spoke traffic boundary.
- HA heartbeat, load-balancer probe, and management rules are filtered out of
  the active single-mode ruleset.
- No public management IP is created.
- FortiOS security policies and port forwarding remain appliance-side work.
- Workload route associations are not configured until approved subnet IDs are
  provided.

## Identity and route RBAC

The FortiGate VM identity is intended to read the route table and update route
entries required by the integration. It is not granted route-table deletion,
whole-table deletion, or unrelated network/RBAC administration.

If Azure reports `RoleAssignmentExists`, use the exact assignment ID from the
error and either import it with the dev variable file or remove it after
confirming the assignment is owned by this deployment. Do not remove a
Contributor assignment simply to resolve a Reader assignment conflict.

## Common Terraform errors

### Configuration for import target does not exist

Run imports from the repository root with the correct environment variable file:

```powershell
terraform import -var-file="environments/dev/terraform.tfvars" <address> <azure-id>
```

Without the file, feature flags can disable `module.rg[0]`, and values such as
`vnet_name` or the FortiGate internal IP can be empty.

### `coalesce` has no non-null arguments

This normally means the single-mode internal interface was not loaded. Confirm
`fortigate_deployment_mode` and `fortigate_network_interfaces` are coming from
`environments/dev/terraform.tfvars`.

### Invalid `for_each` with an unknown data source

This can occur when optional modules are evaluated with default values rather
than the environment file. Re-run the command with the correct `-var-file` and
confirm optional Databricks/private-DNS features are disabled when unused.

### Existing subnet, NSG, or resource group

An existing Azure object must be represented in Terraform state before apply or
removed from the configuration if this repository is not its owner. Confirm the
full resource ID and import address from the Terraform error.

## Validation checklist

- `terraform fmt -check -recursive`
- `terraform init -reconfigure -backend-config="environments/dev/backend.hcl"`
- `terraform validate`
- `terraform plan -var-file="environments/dev/terraform.tfvars"`
- Azure NIC/IP forwarding and route-table scope reviewed
- FortiOS interface mapping, licensing, policies, and private administration
  tested separately

## Production readiness

The current `single` profile is POC/demo only. Production use requires at least
FortiOS licensing, policy review, HA cluster configuration and failover tests,
approved workload routing, management integration, telemetry integration,
capacity validation, and a documented rollback plan.
