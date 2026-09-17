# -------------------------------------------------------------------
# Root Data Sources
# -------------------------------------------------------------------
# The root harness keeps root-level lookups minimal. We only resolve the
# current subscription and tenant so callers can omit those values from
# an environment-specific terraform.tfvars file and use the active Azure
# context instead.
# -------------------------------------------------------------------

data "azurerm_client_config" "current" {}

data "azurerm_private_dns_zone" "databricks" {
  for_each = local.module_plan_enabled.databricks && (var.databricks_private_dns_zone_resource_group_name == null ? "" : trimspace(var.databricks_private_dns_zone_resource_group_name)) != "" ? toset(var.databricks_private_dns_zone_names) : toset([])

  name                = each.value
  resource_group_name = var.databricks_private_dns_zone_resource_group_name
}
