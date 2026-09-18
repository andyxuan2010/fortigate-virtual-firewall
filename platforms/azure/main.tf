
# -------------------------------------------------------------------
# Root Harness Notes
# -------------------------------------------------------------------
# This file is intentionally organized in exact modules/ folder order.
# Each block is isolated, plan-oriented, and guarded by
# local.module_plan_enabled.<module_name> so the root can remain a clean
# validation harness without forcing every module's live prerequisites
# to exist at the same time.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# acr
# -------------------------------------------------------------------
module "acr" {
  count  = local.module_plan_enabled.acr ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/acr?ref=main"

  providers = {
    azurerm      = azurerm
    azurerm.prod = azurerm.prod
  }

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "acr${var.workload}${var.environment}001"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# adf
# -------------------------------------------------------------------
module "adf" {
  count  = local.module_plan_enabled.adf ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/adf?ref=main"

  name            = var.workload
  workload        = var.workload
  location        = var.location
  iac_rg          = local.iac_resource_group_name
  iac_kv          = local.iac_key_vault_name
  iac_st          = local.iac_storage_account_name
  app_rg          = local.resource_group_name
  app_snet        = local.app_subnet_name
  app_vnet_rg     = local.network_resource_group
  app_vnet        = local.vnet_name
  app_vm          = local.vm_name
  app_env         = var.environment
  resource_group  = local.resource_group_name
  app_admin_group = var.app_admin_group
  app_user_group  = var.app_user_group
  tags            = var.tags
}

# -------------------------------------------------------------------
# aks
# -------------------------------------------------------------------
module "aks" {
  count  = local.module_plan_enabled.aks ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/aks?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "aks-${local.name_suffix}"
  default_node_pool = {
    vnet_subnet_id = local.app_subnet_id
  }
  app_env         = var.environment
  workload        = var.workload
  app_admin_group = var.app_admin_group
  app_user_group  = var.app_user_group
  tags            = var.tags
}

# -------------------------------------------------------------------
# applicationgateway
# -------------------------------------------------------------------
module "applicationgateway" {
  count  = local.module_plan_enabled.applicationgateway ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/applicationgateway?ref=main"

  name                  = trimspace(var.applicationgateway_name) != "" ? var.applicationgateway_name : "agw-${local.name_suffix}"
  resource_group_name   = local.resource_group_name
  location              = var.location
  subnet_id             = trimspace(var.applicationgateway_subnet_id) != "" ? var.applicationgateway_subnet_id : local.app_subnet_id
  backend_address_pools = var.applicationgateway_backend_address_pools
  backend_http_settings = var.applicationgateway_backend_http_settings
  http_listeners        = var.applicationgateway_http_listeners
  request_routing_rules = var.applicationgateway_request_routing_rules
  app_env               = var.environment
  workload              = var.workload
  tags                  = var.tags
}

# -------------------------------------------------------------------
# appregistration
# -------------------------------------------------------------------
module "appregistration" {
  count  = local.module_plan_enabled.appregistration ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/appregistration?ref=main"

  display_name = "appreg-${local.name_suffix}"
  tags         = ["terraform", "plan-harness"]
}

# -------------------------------------------------------------------
# appservice
# -------------------------------------------------------------------
module "appservice" {
  count  = local.module_plan_enabled.appservice ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/appservice?ref=main"

  depends_on = [module.appserviceplan]

  app_name            = "app-${local.name_suffix}"
  resource_group_name = local.resource_group_name
  location            = var.location
  app_service_plan_id = local.module_plan_enabled.appserviceplan ? module.appserviceplan[0].id : local.app_service_plan_id
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# appserviceplan
# -------------------------------------------------------------------
module "appserviceplan" {
  count  = local.module_plan_enabled.appserviceplan ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/appserviceplan?ref=main"

  name                       = local.app_service_plan_name
  resource_group_name        = local.resource_group_name
  location                   = var.location
  sku_name                   = "S1"
  log_analytics_workspace_id = ""
  app_env                    = var.environment
  workload                   = var.workload
  app_admin_group            = var.app_admin_group
  app_user_group             = var.app_user_group
  tags                       = var.tags
}

# -------------------------------------------------------------------
# automationaccount
# -------------------------------------------------------------------
module "automationaccount" {
  count  = local.module_plan_enabled.automationaccount ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/automationaccount?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "aa-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# azure_ai_search
# -------------------------------------------------------------------
module "azure_ai_search" {
  count  = local.module_plan_enabled.azure_ai_search ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/azure_ai_search?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "srch-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# azure_ai_service
# -------------------------------------------------------------------
module "azure_ai_service" {
  count  = local.module_plan_enabled.azure_ai_service ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/azure_ai_service?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "ais-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# cosmosdb
# -------------------------------------------------------------------
module "cosmosdb" {
  count  = local.module_plan_enabled.cosmosdb ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/cosmosdb?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = trimspace(var.cosmosdb_name) != "" ? var.cosmosdb_name : "cosmos-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  sql_databases       = var.cosmosdb_sql_databases
  sql_containers      = var.cosmosdb_sql_containers
  tags                = var.tags
}

# -------------------------------------------------------------------
# databricks
# -------------------------------------------------------------------
module "databricks" {
  count  = local.module_plan_enabled.databricks ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/databricks?ref=main"

  depends_on = [module.vnet, module.nsg]

  resource_group_name         = local.resource_group_name
  location                    = var.location
  name                        = trimspace(var.databricks_name) != "" ? var.databricks_name : "dbw-${local.name_suffix}"
  inherit_resource_group_tags = var.databricks_inherit_resource_group_tags

  sku                                   = var.databricks_sku
  managed_resource_group_name           = var.databricks_managed_resource_group_name
  public_network_access_enabled         = var.databricks_public_network_access_enabled
  network_security_group_rules_required = var.databricks_network_security_group_rules_required

  customer_managed_key_enabled                        = var.databricks_customer_managed_key_enabled
  infrastructure_encryption_enabled                   = var.databricks_infrastructure_encryption_enabled
  managed_disk_cmk_key_vault_id                       = var.databricks_managed_disk_cmk_key_vault_id
  managed_disk_cmk_key_vault_key_id                   = var.databricks_managed_disk_cmk_key_vault_key_id
  managed_disk_cmk_rotation_to_latest_version_enabled = var.databricks_managed_disk_cmk_rotation_to_latest_version_enabled
  managed_services_cmk_key_vault_id                   = var.databricks_managed_services_cmk_key_vault_id
  managed_services_cmk_key_vault_key_id               = var.databricks_managed_services_cmk_key_vault_key_id
  root_dbfs_customer_managed_key                      = var.databricks_root_dbfs_customer_managed_key
  enhanced_security_compliance                        = var.databricks_enhanced_security_compliance

  default_storage_firewall_enabled                  = var.databricks_default_storage_firewall_enabled
  access_connector_id                               = var.databricks_access_connector_id
  create_access_connector                           = var.databricks_create_access_connector
  access_connector_name                             = var.databricks_access_connector_name
  access_connector_system_assigned_identity_enabled = var.databricks_access_connector_system_assigned_identity_enabled
  access_connector_identity_ids                     = var.databricks_access_connector_identity_ids
  access_connector_role_assignments                 = var.databricks_access_connector_role_assignments

  custom_parameters = var.databricks_custom_parameters != null ? merge(
    var.databricks_custom_parameters,
    {
      virtual_network_id                                   = local.vnet_id
      public_subnet_network_security_group_association_id  = "${local.network_resource_group_id}/providers/Microsoft.Network/networkSecurityGroups/${trimspace(var.nsg_name) != "" ? var.nsg_name : "nsg-${local.name_suffix}"}/subnets/${lookup(var.databricks_custom_parameters, "public_subnet_name", "")}"
      private_subnet_network_security_group_association_id = "${local.network_resource_group_id}/providers/Microsoft.Network/networkSecurityGroups/${trimspace(var.nsg_name) != "" ? var.nsg_name : "nsg-${local.name_suffix}"}/subnets/${lookup(var.databricks_custom_parameters, "private_subnet_name", "")}"
    }
  ) : null

  private_endpoint_subnet_id                   = trimspace(var.databricks_private_endpoint_subnet_id) != "" ? var.databricks_private_endpoint_subnet_id : local.private_endpoint_subnet_id
  private_endpoint_subnet_name                 = var.databricks_private_endpoint_subnet_name
  private_endpoint_vnet_name                   = var.databricks_private_endpoint_vnet_name
  private_endpoint_network_resource_group_name = var.databricks_private_endpoint_network_resource_group_name
  private_endpoint_subresource_names           = var.databricks_private_endpoint_subresource_names
  private_dns_zone_ids                         = var.databricks_private_dns_zone_ids
  private_dns_zone_names                       = var.databricks_private_dns_zone_names
  private_dns_zone_resource_group_name         = var.databricks_private_dns_zone_resource_group_name
  private_endpoint_manual_connection_enabled   = var.databricks_private_endpoint_manual_connection_enabled
  private_endpoint_request_message             = var.databricks_private_endpoint_request_message
  private_endpoint_network_interface_name      = var.databricks_private_endpoint_network_interface_name

  enable_diagnostics                        = var.databricks_enable_diagnostics
  log_analytics_workspace_id                = trimspace(var.databricks_log_analytics_workspace_id) != "" ? var.databricks_log_analytics_workspace_id : (var.databricks_enable_diagnostics ? local.log_analytics_workspace_id : "")
  diagnostic_storage_account_id             = var.databricks_diagnostic_storage_account_id
  diagnostic_eventhub_authorization_rule_id = var.databricks_diagnostic_eventhub_authorization_rule_id
  diagnostic_eventhub_name                  = var.databricks_diagnostic_eventhub_name
  diagnostic_setting_name                   = var.databricks_diagnostic_setting_name

  role_assignments = var.databricks_role_assignments
  app_env          = var.environment
  workload         = var.workload
  app_admin_group  = var.app_admin_group
  app_user_group   = var.app_user_group
  tags             = local.rg_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "databricks" {
  for_each = data.azurerm_private_dns_zone.databricks

  name                  = trimspace(var.databricks_private_dns_vnet_link_name) != "" ? var.databricks_private_dns_vnet_link_name : local.vnet_name
  resource_group_name   = each.value.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = local.rg_tags

  depends_on = [module.vnet]
}

# -------------------------------------------------------------------
# enterpriseapplication
# -------------------------------------------------------------------
module "enterpriseapplication" {
  count  = local.module_plan_enabled.enterpriseapplication ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/enterpriseapplication?ref=main"

  application_id                = trimspace(var.enterprise_application_application_id) != "" ? var.enterprise_application_application_id : one(module.appregistration[*].application_id)
  account_enabled               = var.enterprise_application_account_enabled
  app_role_assignment_required  = var.enterprise_application_app_role_assignment_required
  description                   = var.enterprise_application_description
  notes                         = var.enterprise_application_notes
  login_url                     = var.enterprise_application_login_url
  preferred_single_sign_on_mode = var.enterprise_application_preferred_single_sign_on_mode
  saml_relay_state              = var.enterprise_application_saml_relay_state
  owners                        = var.enterprise_application_owners
  add_current_caller_as_owner   = var.enterprise_application_add_current_caller_as_owner
  notification_email_addresses  = var.enterprise_application_notification_email_addresses
  feature_tags                  = var.enterprise_application_feature_tags
  use_existing                  = var.enterprise_application_use_existing
  app_role_assignments          = var.enterprise_application_app_role_assignments
  create_application_proxy      = var.enterprise_application_create_application_proxy
  application_proxy             = var.enterprise_application_create_application_proxy ? var.enterprise_application_application_proxy : null
}

# -------------------------------------------------------------------
# eventhub
# -------------------------------------------------------------------
module "eventhub" {
  count  = local.module_plan_enabled.eventhub ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/eventhub?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = trimspace(var.eventhub_name) != "" ? var.eventhub_name : "evh-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  eventhubs           = var.eventhub_eventhubs
  tags                = var.tags
}

# -------------------------------------------------------------------
# firewall
# -------------------------------------------------------------------
module "firewall" {
  count  = local.module_plan_enabled.firewall ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/firewall?ref=main"

  name                = trimspace(var.firewall_name) != "" ? var.firewall_name : "afw-${local.name_suffix}"
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = trimspace(var.firewall_subnet_id) != "" ? var.firewall_subnet_id : local.firewall_subnet_id
  app_env             = var.environment
  workload            = var.workload
  tags                = var.tags
}

# -------------------------------------------------------------------
# fortigate
# -------------------------------------------------------------------
# The existing hub VNet is looked up near the end of this file. Its new
# FortiGate subnets and shared NSG can be deployed before compute is enabled.

locals {
  fortigate_resource_group_name = trimspace(var.fortigate_resource_group_name) != "" ? trimspace(var.fortigate_resource_group_name) : local.network_resource_group
  fortigate_architecture        = lower(trimspace(var.fortigate_deployment_mode)) == "ha" ? "active-passive" : "single"

  fortigate_module_interfaces = {
    for nic in var.fortigate_network_interfaces : nic.name => {
      role                           = nic.role
      subnet_id                      = contains(keys(azurerm_subnet.existing_vnet), nic.subnet_name) ? azurerm_subnet.existing_vnet[nic.subnet_name].id : "${data.azurerm_virtual_network.existing.id}/subnets/${nic.subnet_name}"
      primary                        = try(nic.primary, false)
      enabled_architectures          = toset([for mode in try(nic.enabled_in_modes, ["single", "ha"]) : mode == "ha" ? "active-passive" : mode])
      private_ip_address_allocation  = try(nic.private_ip_address_allocation, "Dynamic")
      private_ip_addresses           = try(nic.private_ip_addresses_by_suffix, {})
      enable_ip_forwarding           = try(nic.enable_ip_forwarding, true)
      accelerated_networking_enabled = try(nic.accelerated_networking_enabled, false)
      associate_nsg                  = false
    }
  }
}

resource "azurerm_marketplace_agreement" "fortigate" {
  count = local.fortigate_enabled && var.fortigate_marketplace_plan != null ? 1 : 0

  publisher = var.fortigate_marketplace_plan.publisher
  offer     = var.fortigate_marketplace_plan.product
  plan      = var.fortigate_marketplace_plan.name
}

module "fortigate" {
  count  = local.fortigate_enabled ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/fortigate?ref=main"

  system_assigned_identity_enabled = true
  disable_password_authentication  = false

  architecture                 = local.fortigate_architecture
  resource_group_name          = local.fortigate_resource_group_name
  location                     = var.location
  name_prefix                  = var.fortigate_name_prefix
  license_type                 = var.fortigate_license_type
  vm_size                      = local.fortigate_vm_size_effective
  single_zone                  = var.fortigate_zone
  availability_zones           = var.fortigate_availability_zones
  load_balancer_frontend_zones = var.fortigate_load_balancer_frontend_zones

  admin_username                 = var.fortigate_admin_username
  admin_password                 = var.fortigate_admin_password
  admin_ssh_public_key           = var.fortigate_admin_ssh_public_key
  admin_credentials_key_vault_id = local.iac_key_vault_id
  admin_password_secret_name     = var.fortigate_admin_password_secret_name
  admin_ssh_key_secret_name      = var.fortigate_admin_ssh_key_secret_name
  management_access_model        = var.fortigate_management_access_model

  image            = var.fortigate_image
  marketplace_plan = var.fortigate_marketplace_plan
  os_disk          = var.fortigate_os_disk
  custom_data      = var.fortigate_custom_data

  # Load balancers are an HA concern. The input objects remain populated so
  # switching back to ha requires changing only fortigate_deployment_mode.
  internal_load_balancer = local.fortigate_architecture == "active-passive" ? var.fortigate_internal_load_balancer : merge(var.fortigate_internal_load_balancer, { enabled = false })
  external_load_balancer = local.fortigate_architecture == "active-passive" ? var.fortigate_external_load_balancer : merge(var.fortigate_external_load_balancer, { enabled = false })

  create_subnets                = false
  create_network_security_group = false
  interfaces                    = local.fortigate_module_interfaces
  interface_order               = var.fortigate_interface_order
  app_admin_group               = var.app_admin_group
  app_user_group                = var.app_user_group
  # The RG is created by this composition. Supplying its planned tags avoids
  # a data lookup for a resource group that does not exist before apply.
  inherited_resource_group_tags = local.rg_tags
  tags                          = local.rg_tags

  depends_on = [
    module.rg,
    azurerm_marketplace_agreement.fortigate,
    azurerm_subnet_network_security_group_association.existing_vnet
  ]
}

# -------------------------------------------------------------------
# functionapp
# -------------------------------------------------------------------
module "functionapp" {
  count  = local.module_plan_enabled.functionapp ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/functionapp?ref=main"

  depends_on = [module.appserviceplan, module.storageaccount]

  resource_group_name                 = local.resource_group_name
  name                                = trimspace(var.functionapp_name) != "" ? var.functionapp_name : "func-${local.name_suffix}"
  location                            = var.location
  service_plan_id                     = trimspace(var.functionapp_service_plan_id) != "" ? var.functionapp_service_plan_id : (local.module_plan_enabled.appserviceplan ? module.appserviceplan[0].id : local.app_service_plan_id)
  storage_account_name                = trimspace(var.functionapp_storage_account_name) != "" ? var.functionapp_storage_account_name : (local.module_plan_enabled.storageaccount ? module.storageaccount[0].name : local.iac_storage_account_name)
  storage_account_resource_group_name = trimspace(var.functionapp_storage_account_resource_group_name) != "" ? var.functionapp_storage_account_resource_group_name : (local.module_plan_enabled.storageaccount ? module.storageaccount[0].resource_group_name : local.iac_resource_group_name)
  app_env                             = var.environment
  workload                            = var.workload
  app_admin_group                     = var.app_admin_group
  app_user_group                      = var.app_user_group
  tags                                = var.tags
}

# -------------------------------------------------------------------
# keyvault
# -------------------------------------------------------------------
module "keyvault" {
  count  = local.module_plan_enabled.keyvault ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/keyvault?ref=main"

  providers = {
    azurerm      = azurerm
    azurerm.prod = azurerm.prod
  }

  resource_group_name = local.resource_group_name
  location            = var.location
  tenant_id           = local.tenant_id_resolved
  name                = trimspace(var.keyvault_name) != "" ? var.keyvault_name : local.iac_key_vault_name
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# linuxvm
# -------------------------------------------------------------------
module "linuxvm" {
  count  = local.module_plan_enabled.linuxvm ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/linuxvm?ref=main"

  iac_rg                         = local.iac_resource_group_name
  iac_kv                         = local.iac_key_vault_name
  iac_kv_id                      = local.iac_key_vault_id
  iac_st                         = local.iac_storage_account_name
  iac_st_id                      = local.iac_storage_account_id
  iac_st_primary_blob_endpoint   = "https://${local.iac_storage_account_name}.blob.core.windows.net/"
  resource_group_name            = local.resource_group_name
  subnet_name                    = local.app_subnet_name
  subnet_id                      = local.app_subnet_id
  vnet_resource_group_name       = local.network_resource_group
  vnet_name                      = local.vnet_name
  vm_name                        = local.vm_name
  app_env                        = var.environment
  workload                       = var.workload
  admin_username                 = var.azure-user
  admin_password                 = var.azure-password
  admin_ssh_key                  = var.azure-ssh-key
  admin_credentials_key_vault_id = local.iac_key_vault_id
  datadog_api_key                = var.linux_vm_datadog_api_key
  app_admin_group                = var.app_admin_group
  app_user_group                 = var.app_user_group
  tags                           = var.tags
}

# -------------------------------------------------------------------
# loganalytics
# -------------------------------------------------------------------
module "loganalytics" {
  count  = local.module_plan_enabled.loganalytics ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/loganalytics?ref=main"

  name                = trimspace(var.loganalytics_name) != "" ? var.loganalytics_name : local.log_analytics_name
  resource_group_name = local.resource_group_name
  location            = var.location
  app_env             = var.environment
  workload            = var.workload
  tags                = var.tags
}

# -------------------------------------------------------------------
# logicapp
# -------------------------------------------------------------------
module "logicapp" {
  count  = local.module_plan_enabled.logicapp ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/logicapp?ref=main"

  depends_on = [module.appserviceplan, module.storageaccount]

  resource_group_name                 = local.resource_group_name
  name                                = trimspace(var.logicapp_name) != "" ? var.logicapp_name : "logic-${local.name_suffix}"
  location                            = var.location
  service_plan_id                     = trimspace(var.logicapp_service_plan_id) != "" ? var.logicapp_service_plan_id : (local.module_plan_enabled.appserviceplan ? module.appserviceplan[0].id : local.app_service_plan_id)
  storage_account_name                = trimspace(var.logicapp_storage_account_name) != "" ? var.logicapp_storage_account_name : (local.module_plan_enabled.storageaccount ? module.storageaccount[0].name : local.iac_storage_account_name)
  storage_account_resource_group_name = trimspace(var.logicapp_storage_account_resource_group_name) != "" ? var.logicapp_storage_account_resource_group_name : (local.module_plan_enabled.storageaccount ? module.storageaccount[0].resource_group_name : local.iac_resource_group_name)
  app_env                             = var.environment
  workload                            = var.workload
  app_admin_group                     = var.app_admin_group
  app_user_group                      = var.app_user_group
  tags                                = var.tags
}

# -------------------------------------------------------------------
# managedidentity
# -------------------------------------------------------------------
module "managedidentity" {
  count  = local.module_plan_enabled.managedidentity ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/managedidentity?ref=main"

  name                = trimspace(var.managedidentity_name) != "" ? var.managedidentity_name : "id-${local.name_suffix}"
  resource_group_name = local.resource_group_name
  location            = var.location
  app_env             = var.environment
  workload            = var.workload
  tags                = var.tags
}

# -------------------------------------------------------------------
# managementgroups
# -------------------------------------------------------------------
module "managementgroups" {
  count  = local.module_plan_enabled.managementgroups ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/managementgroups?ref=main"

  name         = local.management_group_name
  display_name = "Platform ${upper(var.environment)}"
  tags         = var.tags
}

# -------------------------------------------------------------------
# nsg
# -------------------------------------------------------------------
module "nsg" {
  count  = local.module_plan_enabled.nsg ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/nsg?ref=main"

  depends_on = [
    module.vnet,
    azurerm_virtual_network_peering.hub_to_spoke
  ]

  name                = trimspace(var.nsg_name) != "" ? var.nsg_name : "nsg-${local.name_suffix}"
  resource_group_name = local.resource_group_name
  location            = var.location
  security_rules      = var.nsg_security_rules
  subnet_ids = length(var.nsg_subnet_ids) > 0 ? var.nsg_subnet_ids : (local.module_plan_enabled.vnet ? [
    module.vnet[0].subnet_ids[lookup(var.databricks_custom_parameters, "public_subnet_name", "")],
    module.vnet[0].subnet_ids[lookup(var.databricks_custom_parameters, "private_subnet_name", "")]
  ] : [])
  network_interface_ids = var.nsg_network_interface_ids
  app_env               = var.environment
  workload              = var.workload
  tags                  = local.rg_tags
}

# -------------------------------------------------------------------
# openai
# -------------------------------------------------------------------
module "openai" {
  count  = local.module_plan_enabled.openai ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/openai?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = "oai-${local.name_suffix}"
  deployments = {
    gpt4o_mini = {
      model_format = "OpenAI"
      model_name   = "gpt-4o-mini"
      sku_name     = "Standard"
    }
  }
  app_env         = var.environment
  workload        = var.workload
  app_admin_group = var.app_admin_group
  app_user_group  = var.app_user_group
  tags            = var.tags
}

# -------------------------------------------------------------------
# policy
# -------------------------------------------------------------------
module "policy" {
  count  = local.module_plan_enabled.policy ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/policy?ref=main"

  name                = trimspace(var.policy_name) != "" ? var.policy_name : "allowed-location-${var.environment}"
  display_name        = trimspace(var.policy_display_name) != "" ? var.policy_display_name : "Allowed Location ${upper(var.environment)}"
  management_group_id = trimspace(var.policy_management_group_id) != "" ? var.policy_management_group_id : local.management_group_id
  policy_rule         = trimspace(var.policy_rule) != "" ? var.policy_rule : local.sample_policy_rule
}

# -------------------------------------------------------------------
# private_dns
# -------------------------------------------------------------------
module "private_dns" {
  count  = local.module_plan_enabled.private_dns ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/private_dns?ref=main"

  resource_group_name = local.private_dns_resource_group
  zones               = local.private_dns_zones
  app_env             = var.environment
  workload            = var.workload
  tags                = var.tags
}

# -------------------------------------------------------------------
# rg
# -------------------------------------------------------------------
module "rg" {
  count  = local.module_plan_enabled.rg ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/rg?ref=main"

  name            = local.resource_group_name
  location        = var.location
  app_env         = var.environment
  workload        = var.workload
  app_admin_group = var.app_admin_group
  app_user_group  = var.app_user_group
  tags            = local.rg_tags
}

# -------------------------------------------------------------------
# roleassignments
# -------------------------------------------------------------------
module "roleassignments" {
  count  = local.module_plan_enabled.roleassignments ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/roleassignments?ref=main"

  assignments = length(var.roleassignments_assignments) > 0 ? var.roleassignments_assignments : local.sample_role_assignments
}

# -------------------------------------------------------------------
# route_table
# -------------------------------------------------------------------
module "route_table" {
  count  = local.module_plan_enabled.route_table ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/route_table?ref=main"

  inherited_resource_group_tags = local.rg_tags

  depends_on = [module.rg]

  name                = trimspace(var.route_table_name) != "" ? var.route_table_name : "rt-${local.name_suffix}"
  resource_group_name = local.resource_group_name
  location            = var.location
  routes              = local.fortigate_route_table_routes
  subnet_ids          = var.route_table_subnet_ids
  app_env             = var.environment
  workload            = var.workload
  tags                = var.tags
}

# -------------------------------------------------------------------
# servicebus
# -------------------------------------------------------------------
module "servicebus" {
  count  = local.module_plan_enabled.servicebus ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/servicebus?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = trimspace(var.servicebus_name) != "" ? var.servicebus_name : "sb-${local.name_suffix}"
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  queues              = var.servicebus_queues
  topics              = var.servicebus_topics
  subscriptions       = var.servicebus_subscriptions
  tags                = var.tags
}

# -------------------------------------------------------------------
# sqldb
# -------------------------------------------------------------------
module "sqldb" {
  count  = local.module_plan_enabled.sqldb ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/sqldb?ref=main"

  server_name                = "sql-${var.workload}-${var.environment}"
  database_name              = "sqldb-${var.workload}-${var.environment}"
  max_size_gb                = 32
  admin_username             = "sqladminuser"
  admin_password             = "ChangeMe12345!"
  ad_admin_login_name        = "sql-admin-group"
  ad_admin_object_id         = var.sample_principal_object_id
  sku_name                   = "S0"
  resource_group_name        = local.resource_group_name
  app_env                    = var.environment
  workload                   = var.workload
  location                   = var.location
  private_endpoint_subnet_id = local.private_endpoint_subnet_id
  app_admin_group            = var.app_admin_group
  app_user_group             = var.app_user_group
  tags                       = var.tags
}

# -------------------------------------------------------------------
# sqlmi
# -------------------------------------------------------------------
module "sqlmi" {
  count  = local.module_plan_enabled.sqlmi ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/sqlmi?ref=main"

  depends_on = [module.vnet]

  name                         = trimspace(var.sqlmi_name) != "" ? var.sqlmi_name : "sqlmi-${local.name_suffix}"
  resource_group_name          = local.resource_group_name
  subnet_id                    = local.module_plan_enabled.vnet ? module.vnet[0].subnet_ids[local.app_subnet_name] : local.app_subnet_id
  administrator_login          = var.sqlmi_administrator_login
  administrator_login_password = var.sqlmi_administrator_login_password
  sku_name                     = var.sqlmi_sku_name
  vcores                       = var.sqlmi_vcores
  storage_size_in_gb           = var.sqlmi_storage_size_in_gb
  app_env                      = var.environment
  workload                     = var.workload
  app_admin_group              = var.app_admin_group
  app_user_group               = var.app_user_group
  tags                         = var.tags
}

# -------------------------------------------------------------------
# sqlmi_db
# -------------------------------------------------------------------
module "sqlmi_db" {
  count  = local.module_plan_enabled.sqlmi_db ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/sqlmi_db?ref=main"

  depends_on = [module.sqlmi]

  app_sqlmi       = local.module_plan_enabled.sqlmi ? module.sqlmi[0].name : "sqlmi-${local.name_suffix}"
  app_sqlmi_db    = trimspace(var.sqlmi_db_name) != "" ? var.sqlmi_db_name : "sqlmidb-${local.name_suffix}"
  app_sqlmi_rg    = local.module_plan_enabled.sqlmi ? module.sqlmi[0].resource_group_name : local.resource_group_name
  app_env         = var.environment
  workload        = var.workload
  tags            = var.tags
  app_admin_group = var.app_admin_group
  app_user_group  = var.app_user_group
}

# -------------------------------------------------------------------
# storageaccount
# -------------------------------------------------------------------
module "storageaccount" {
  count  = local.module_plan_enabled.storageaccount ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/storageaccount?ref=main"
  providers = {
    azurerm      = azurerm
    azurerm.prod = azurerm.prod
  }
  resource_group_name = local.resource_group_name
  location            = var.location
  name                = trimspace(var.storageaccount_name) != "" ? var.storageaccount_name : local.iac_storage_account_name
  blob_properties     = var.shared_storage_blob_properties
  containers          = var.storageaccount_containers
  file_shares         = var.storageaccount_file_shares
  queues              = var.storageaccount_queues
  tables              = var.storageaccount_tables
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = var.tags
}

# -------------------------------------------------------------------
# subscription_vending
# -------------------------------------------------------------------
module "subscription_vending" {
  count  = local.module_plan_enabled.subscription_vending ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/subscription_vending?ref=main"

  subscription_name        = "sub-${local.name_suffix}"
  existing_subscription_id = local.subscription_resource_id
  management_group_id      = local.management_group_id
  tags                     = var.tags
}

# -------------------------------------------------------------------
# vnet
# -------------------------------------------------------------------
module "vnet" {
  count  = local.module_plan_enabled.vnet ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/vnet?ref=main"

  resource_group_name = local.resource_group_name
  location            = var.location
  name                = trimspace(var.vnet_name) != "" ? var.vnet_name : local.vnet_name
  address_space       = var.vnet_address_space
  subnets             = local.fortigate_vnet_subnets
  app_env             = var.environment
  workload            = var.workload
  app_admin_group     = var.app_admin_group
  app_user_group      = var.app_user_group
  tags                = local.rg_tags
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = var.hub_vnet_peering_enabled ? 1 : 0

  name                         = "peer-${local.peering_spoke_vnet_name}-to-${var.hub_vnet_name}"
  resource_group_name          = local.resource_group_name
  virtual_network_name         = local.peering_spoke_vnet_name
  remote_virtual_network_id    = local.peering_hub_vnet_id
  allow_virtual_network_access = var.hub_vnet_peering_allow_virtual_network_access
  allow_forwarded_traffic      = coalesce(var.hub_vnet_peering_spoke_to_hub_allow_forwarded_traffic, var.hub_vnet_peering_allow_forwarded_traffic)
  allow_gateway_transit        = false
  use_remote_gateways          = var.hub_vnet_peering_use_remote_gateways

  depends_on = [module.vnet]

  lifecycle {
    precondition {
      condition     = local.peering_hub_values_available
      error_message = "Set hub_vnet_id, or set both hub_vnet_resource_group_name and hub_vnet_name, before enabling hub_vnet_peering_enabled."
    }

    precondition {
      condition     = !var.hub_vnet_peering_use_remote_gateways || (var.hub_vnet_peering_create_reverse && var.hub_vnet_peering_allow_gateway_transit)
      error_message = "hub_vnet_peering_use_remote_gateways requires hub_vnet_peering_create_reverse and hub_vnet_peering_allow_gateway_transit to both be true."
    }
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count = var.hub_vnet_peering_enabled && var.hub_vnet_peering_create_reverse ? 1 : 0

  provider = azurerm.hub

  name                         = "peer-${var.hub_vnet_name}-to-${local.peering_spoke_vnet_name}"
  resource_group_name          = var.hub_vnet_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = local.peering_spoke_vnet_id
  allow_virtual_network_access = var.hub_vnet_peering_allow_virtual_network_access
  allow_forwarded_traffic      = coalesce(var.hub_vnet_peering_hub_to_spoke_allow_forwarded_traffic, var.hub_vnet_peering_allow_forwarded_traffic)
  allow_gateway_transit        = var.hub_vnet_peering_allow_gateway_transit
  use_remote_gateways          = false

  depends_on = [module.vnet]

  lifecycle {
    precondition {
      condition     = trimspace(var.hub_vnet_resource_group_name) != "" && trimspace(var.hub_vnet_name) != ""
      error_message = "Set hub_vnet_resource_group_name and hub_vnet_name before enabling reverse hub-to-spoke peering."
    }
  }
}

# -------------------------------------------------------------------
# winvm
# -------------------------------------------------------------------
module "winvm" {
  count  = local.module_plan_enabled.winvm ? 1 : 0
  source = "git::https://github.com/andyxuan2010/azure-template.git//modules/winvm?ref=main"

  iac_rg                           = local.iac_resource_group_name
  iac_kv                           = local.iac_key_vault_name
  iac_st                           = local.iac_storage_account_name
  app_rg                           = local.resource_group_name
  app_snet                         = local.app_subnet_name
  app_vnet_rg                      = local.network_resource_group
  app_vnet                         = local.vnet_name
  app_vm                           = local.vm_name
  app_env                          = var.environment
  workload                         = var.workload
  azure-user                       = var.azure-user
  azure-password                   = var.azure-password
  admin_credentials_key_vault_id   = local.iac_key_vault_id
  app_admin_group                  = var.app_admin_group
  app_user_group                   = var.app_user_group
  vm_remote_group                  = var.winvm_vm_remote_group
  vm_admin_group                   = var.winvm_vm_admin_group
  public_network_enabled           = var.winvm_public_network_enabled
  enable_domain_join               = var.winvm_enable_domain_join
  domain_join_user                 = var.winvm_domain_join_user
  domain_join_password             = var.winvm_domain_join_password
  domain_join_username_secret_name = var.winvm_domain_join_username_secret_name
  domain_join_password_secret_name = var.winvm_domain_join_password_secret_name
  enable_shir                      = var.winvm_enable_shir
  tags                             = var.tags
}

# -------------------------------------------------------------------
# Existing Hub VNet and FortiGate Subnets
# -------------------------------------------------------------------
# The hub VNet is existing infrastructure. This repository looks it up by
# name and creates only the dedicated FortiGate subnets and optional NSG.

data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = local.network_resource_group

  lifecycle {
    precondition {
      condition     = trimspace(var.vnet_name) != ""
      error_message = "vnet_name must identify the existing hub VNet."
    }
  }
}

resource "azurerm_subnet" "existing_vnet" {
  for_each = local.existing_vnet_subnets_enabled ? local.fortigate_vnet_subnets : {}

  name                                          = each.key
  resource_group_name                           = data.azurerm_virtual_network.existing.resource_group_name
  virtual_network_name                          = data.azurerm_virtual_network.existing.name
  address_prefixes                              = each.value.address_prefixes
  service_endpoints                             = try(each.value.service_endpoints, null)
  service_endpoint_policy_ids                   = try(each.value.service_endpoint_policy_ids, null)
  private_endpoint_network_policies             = try(each.value.private_endpoint_network_policies, null)
  private_link_service_network_policies_enabled = try(each.value.private_link_service_network_policies_enabled, null)

  dynamic "delegation" {
    for_each = try(each.value.delegations, {})

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation_name
        actions = delegation.value.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "existing_vnet_subnets" {
  count = local.existing_vnet_subnets_create_nsg ? 1 : 0

  name                = trimspace(var.nsg_name) != "" ? trimspace(var.nsg_name) : "nsg-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_virtual_network.existing.resource_group_name
  tags                = local.rg_tags

  dynamic "security_rule" {
    for_each = local.fortigate_nsg_security_rules

    content {
      name                                       = security_rule.key
      priority                                   = security_rule.value.priority
      direction                                  = security_rule.value.direction
      access                                     = security_rule.value.access
      protocol                                   = security_rule.value.protocol
      source_port_range                          = try(security_rule.value.source_port_range, null)
      source_port_ranges                         = try(security_rule.value.source_port_ranges, null)
      destination_port_range                     = try(security_rule.value.destination_port_range, null)
      destination_port_ranges                    = try(security_rule.value.destination_port_ranges, null)
      source_address_prefix                      = try(security_rule.value.source_address_prefix, null)
      source_address_prefixes                    = try(security_rule.value.source_address_prefixes, null)
      destination_address_prefix                 = try(security_rule.value.destination_address_prefix, null)
      destination_address_prefixes               = try(security_rule.value.destination_address_prefixes, null)
      source_application_security_group_ids      = try(security_rule.value.source_application_security_group_ids, null)
      destination_application_security_group_ids = try(security_rule.value.destination_application_security_group_ids, null)
      description                                = try(security_rule.value.description, null)
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "existing_vnet" {
  # Keep for_each keys configuration-known so plan/import can evaluate the
  # association before Azure returns the created subnet IDs.
  for_each = local.existing_vnet_subnets_create_nsg ? local.fortigate_vnet_subnets : {}

  subnet_id                 = azurerm_subnet.existing_vnet[each.key].id
  network_security_group_id = azurerm_network_security_group.existing_vnet_subnets[0].id
}
