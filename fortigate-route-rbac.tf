# Permit route reads and updates only on this deployment's route table.
# Keep iteration keys plan-known even when the VM principal IDs are new.
locals {
  fortigate_route_rbac_enabled = local.fortigate_enabled && local.module_plan_enabled.route_table
  fortigate_route_rbac_instances = local.fortigate_route_rbac_enabled ? (
    local.fortigate_architecture == "active-passive" ? toset(["a", "b"]) : toset(["a"])
  ) : toset([])
}

resource "azurerm_role_definition" "fortigate_route_updater" {
  count = local.fortigate_route_rbac_enabled ? 1 : 0

  name        = "FortiGate Route Updater - ${local.resource_group_name}"
  scope       = local.resource_group_id
  description = "Read route tables and read/create/update routes; no table deletion, network changes, or RBAC management."

  permissions {
    actions = [
      "Microsoft.Network/routeTables/read",
      "Microsoft.Network/routeTables/routes/read",
      "Microsoft.Network/routeTables/routes/write",
    ]
  }

  # Availability of the role at RG scope does not grant access at RG scope.
  assignable_scopes = [local.resource_group_id]

  depends_on = [module.rg]
}

resource "azurerm_role_assignment" "fortigate_route_updater" {
  for_each = local.fortigate_route_rbac_instances

  scope                            = module.route_table[0].id
  role_definition_id               = azurerm_role_definition.fortigate_route_updater[0].role_definition_resource_id
  principal_id                     = module.fortigate[0].managed_identity_principal_ids[each.key]
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
