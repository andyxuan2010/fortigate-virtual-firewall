locals {
  name_suffix         = "${var.workload}-${var.environment}"
  normalized_location = replace(replace(lower(var.location), " ", ""), "-", "")
  region_code_map = {
    canadacentral  = "cc"
    canadaeast     = "ce"
    eastus         = "eus"
    eastus2        = "eus2"
    centralus      = "cus"
    southcentralus = "scus"
    northcentralus = "ncus"
    westus         = "wus"
    westus2        = "wus2"
    westus3        = "wus3"
  }
  region_code = lookup(local.region_code_map, local.normalized_location, substr(local.normalized_location, 0, 3))



  environment_tag_map = {
    dev         = "DEV"
    development = "DEV"
    sbx         = "SBX"
    sandbox     = "SBX"
    prod        = "PROD"
    production  = "PROD"
    stg         = "STG"
    stage       = "STG"
    staging     = "STG"
    qa          = "QA"
    test        = "TEST"
    poc         = "POC"
  }
  environment_tag_value = lookup(local.environment_tag_map, lower(trimspace(var.environment)), var.environment)

  rg_tags = merge(
    var.rg_tags,
    {
      Environment = local.environment_tag_value
      Workload    = var.workload
    }
  )
  module_tags = {
    for key, value in local.rg_tags :
    key => value
    if !contains(["environment", "workload"], lower(trimspace(key)))
  }
















  subscription_id_resolved = trimspace(var.subscription_id) != "" ? trimspace(var.subscription_id) : data.azurerm_client_config.current.subscription_id
  tenant_id_resolved       = trimspace(var.tenant_id) != "" ? trimspace(var.tenant_id) : data.azurerm_client_config.current.tenant_id

  # Project resources and shared IaC resources use separate resource groups.
  resource_group_name        = trimspace(var.fortigate_resource_group_name)
  iac_resource_group_name    = trimspace(var.iac_resource_group_name)
  network_resource_group     = var.network_resource_group_name
  private_dns_resource_group = var.private_dns_resource_group_name
  vnet_name                  = var.shared_vnet_name
  app_subnet_name            = var.app_subnet_name
  private_endpoint_subnet    = var.private_endpoint_subnet_name
  firewall_subnet_name       = var.firewall_subnet_name

  subscription_resource_id   = "/subscriptions/${local.subscription_id_resolved}"
  resource_group_id          = "${local.subscription_resource_id}/resourceGroups/${local.resource_group_name}"
  iac_resource_group_id      = "${local.subscription_resource_id}/resourceGroups/${local.iac_resource_group_name}"
  network_resource_group_id  = "${local.subscription_resource_id}/resourceGroups/${local.network_resource_group}"
  vnet_id                    = "${local.subscription_resource_id}/resourceGroups/${local.network_resource_group}/providers/Microsoft.Network/virtualNetworks/${local.vnet_name}"
  app_subnet_id              = "${local.vnet_id}/subnets/${local.app_subnet_name}"
  private_endpoint_subnet_id = "${local.vnet_id}/subnets/${local.private_endpoint_subnet}"
  firewall_subnet_id         = "${local.vnet_id}/subnets/${local.firewall_subnet_name}"

  iac_storage_account_name     = trimspace(var.iac_storage_account_name)
  iac_key_vault_name           = trimspace(var.iac_key_vault_name)
  log_analytics_name           = trimspace(var.shared_log_analytics_name) != "" ? trimspace(var.shared_log_analytics_name) : "law-${var.workload}-${var.environment}"
  app_service_plan_name        = trimspace(var.shared_app_service_plan_name) != "" ? trimspace(var.shared_app_service_plan_name) : "asp-${var.workload}-${var.environment}"
  vm_name                      = trimspace(var.shared_vm_name) != "" ? trimspace(var.shared_vm_name) : substr("vm${var.workload}${var.environment}", 0, 12)
  management_group_name        = var.shared_management_group_name
  management_group_id          = "/providers/Microsoft.Management/managementGroups/${local.management_group_name}"
  iac_storage_account_id       = "${local.iac_resource_group_id}/providers/Microsoft.Storage/storageAccounts/${local.iac_storage_account_name}"
  iac_key_vault_id             = "${local.iac_resource_group_id}/providers/Microsoft.KeyVault/vaults/${local.iac_key_vault_name}"
  log_analytics_workspace_id   = "${local.resource_group_id}/providers/Microsoft.OperationalInsights/workspaces/${local.log_analytics_name}"
  app_service_plan_id          = "${local.resource_group_id}/providers/Microsoft.Web/serverFarms/${local.app_service_plan_name}"
  user_assigned_identity_id    = "${local.resource_group_id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-${local.name_suffix}"
  peering_spoke_vnet_name      = trimspace(var.vnet_name) != "" ? trimspace(var.vnet_name) : local.vnet_name
  peering_spoke_vnet_id        = "${local.subscription_resource_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Network/virtualNetworks/${local.peering_spoke_vnet_name}"
  peering_hub_subscription_id  = trimspace(var.hub_vnet_subscription_id) != "" ? trimspace(var.hub_vnet_subscription_id) : local.subscription_id_resolved
  peering_hub_vnet_id          = trimspace(var.hub_vnet_id) != "" ? trimspace(var.hub_vnet_id) : "/subscriptions/${local.peering_hub_subscription_id}/resourceGroups/${var.hub_vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.hub_vnet_name}"
  peering_hub_values_available = trimspace(var.hub_vnet_id) != "" || (trimspace(var.hub_vnet_resource_group_name) != "" && trimspace(var.hub_vnet_name) != "")

  private_dns_zone_id = "${local.subscription_resource_id}/resourceGroups/${local.private_dns_resource_group}/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net"

  private_dns_zones = {
    "privatelink.azurewebsites.net" = {
      vnet_links = {
        sample = {
          virtual_network_id   = local.vnet_id
          registration_enabled = false
          tags                 = local.rg_tags
        }
      }
      a_records = {}
    }
  }

  default_vnet_subnets = {
    # (local.app_subnet_name) = {
    #   address_prefixes = ["10.42.1.0/24"]
    #   delegations = local.module_plan_enabled.sqlmi || local.module_plan_enabled.sqlmi_db ? {
    #     sqlmi = {
    #       name                    = "sqlmi"
    #       service_delegation_name = "Microsoft.Sql/managedInstances"
    #       actions                 = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    #     }
    #   } : {}
    # }
    # (local.private_endpoint_subnet) = {
    #   address_prefixes                  = ["10.42.2.0/24"]
    #   private_endpoint_network_policies = "Disabled"
    # }
  }
  vnet_subnets = merge(local.default_vnet_subnets, var.vnet_subnets)

  # Keep the full environment subnet catalog available for HA, while only
  # creating/managing the subnets required by the selected FortiGate mode.
  fortigate_subnet_names_for_mode = toset([
    for interface in var.fortigate_network_interfaces :
    interface.subnet_name
    if contains(try(interface.enabled_in_modes, ["single", "ha"]), lower(trimspace(var.fortigate_deployment_mode)))
  ])
  fortigate_vnet_subnets = {
    for subnet_name, subnet in local.vnet_subnets :
    subnet_name => subnet
    if contains(local.fortigate_subnet_names_for_mode, subnet_name)
  }

  sample_policy_rule = jsonencode({
    if = {
      field = "location"
      notIn = [var.location]
    }
    then = {
      effect = "audit"
    }
  })

  sample_role_assignments = {
    reader = {
      scope                = local.subscription_resource_id
      role_definition_name = "Reader"
      principal_id         = var.sample_principal_object_id
    }
  }

  feature_keys = keys(var.features)
  feature_flags = {
    enable_acr                             = lookup(var.features, "enable_acr", var.module_plan_enabled.acr)
    enable_adf                             = lookup(var.features, "enable_adf", var.module_plan_enabled.adf)
    enable_aks                             = lookup(var.features, "enable_aks", var.module_plan_enabled.aks)
    enable_application_gateway             = lookup(var.features, "enable_application_gateway", var.module_plan_enabled.applicationgateway)
    enable_app_registration_for_appservice = lookup(var.features, "enable_app_registration_for_appservice", var.module_plan_enabled.appregistration)
    enable_app_services                    = lookup(var.features, "enable_app_services", var.module_plan_enabled.appservice || var.module_plan_enabled.appserviceplan)
    enable_automation_accounts             = lookup(var.features, "enable_automation_accounts", var.module_plan_enabled.automationaccount)
    enable_automation_ari_workloads        = lookup(var.features, "enable_automation_ari_workloads", false)
    enable_azure_ai_search                 = lookup(var.features, "enable_azure_ai_search", var.module_plan_enabled.azure_ai_search)
    enable_azure_ai_service                = lookup(var.features, "enable_azure_ai_service", var.module_plan_enabled.azure_ai_service)
    enable_cosmosdb                        = lookup(var.features, "enable_cosmosdb", var.module_plan_enabled.cosmosdb)
    enable_databricks                      = lookup(var.features, "enable_databricks", var.module_plan_enabled.databricks)
    enable_enterprise_application          = lookup(var.features, "enable_enterprise_application", var.module_plan_enabled.enterpriseapplication)
    enable_eventhub                        = lookup(var.features, "enable_eventhub", var.module_plan_enabled.eventhub)
    enable_firewall                        = lookup(var.features, "enable_firewall", var.module_plan_enabled.firewall)
    enable_functionapp                     = lookup(var.features, "enable_functionapp", var.module_plan_enabled.functionapp)
    enable_keyvault                        = lookup(var.features, "enable_keyvault", var.module_plan_enabled.keyvault)
    enable_linux_vm                        = lookup(var.features, "enable_linux_vm", var.module_plan_enabled.linuxvm)
    enable_loganalytics                    = lookup(var.features, "enable_loganalytics", var.module_plan_enabled.loganalytics)
    enable_logicapp                        = lookup(var.features, "enable_logicapp", var.module_plan_enabled.logicapp)
    enable_managed_identity                = lookup(var.features, "enable_managed_identity", var.module_plan_enabled.managedidentity)
    enable_management_group                = lookup(var.features, "enable_management_group", var.module_plan_enabled.managementgroups)
    enable_nsg                             = lookup(var.features, "enable_nsg", var.module_plan_enabled.nsg)
    enable_openai                          = lookup(var.features, "enable_openai", var.module_plan_enabled.openai)
    enable_policy                          = lookup(var.features, "enable_policy", var.module_plan_enabled.policy)
    enable_private_dns                     = lookup(var.features, "enable_private_dns", var.module_plan_enabled.private_dns)
    enable_resource_group                  = lookup(var.features, "enable_resource_group", var.module_plan_enabled.rg)
    enable_roleassignments                 = lookup(var.features, "enable_roleassignments", var.module_plan_enabled.roleassignments)
    enable_route_table                     = lookup(var.features, "enable_route_table", var.module_plan_enabled.route_table)
    enable_servicebus                      = lookup(var.features, "enable_servicebus", var.module_plan_enabled.servicebus)
    enable_sqldb                           = lookup(var.features, "enable_sqldb", var.module_plan_enabled.sqldb)
    enable_sqlmi                           = lookup(var.features, "enable_sqlmi", var.module_plan_enabled.sqlmi)
    enable_sqlmi_db                        = lookup(var.features, "enable_sqlmi_db", var.module_plan_enabled.sqlmi_db)
    enable_storageaccount                  = lookup(var.features, "enable_storageaccount", var.module_plan_enabled.storageaccount)
    enable_subscription_bootstrap          = lookup(var.features, "enable_subscription_bootstrap", var.module_plan_enabled.subscription_vending)
    enable_vnet                            = lookup(var.features, "enable_vnet", var.module_plan_enabled.vnet)
    enable_winvm                           = lookup(var.features, "enable_winvm", var.module_plan_enabled.winvm)
  }

  existing_vnet_subnets_enabled    = lookup(var.features, "enable_existing_vnet_subnets", false)
  existing_vnet_subnets_create_nsg = local.existing_vnet_subnets_enabled && lookup(var.features, "enable_nsg", false)
  fortigate_enabled                = lookup(var.features, "enable_fortigate", false)

  # fortigate_deployment_mode is the single architecture switch. Keep the
  # HA defaults available, but derive the smallest valid single-node POC SKU
  # unless an explicit fortigate_vm_size override is supplied.
  fortigate_vm_size_effective = trimspace(var.fortigate_vm_size) != "" ? trimspace(var.fortigate_vm_size) : (
    lower(trimspace(var.fortigate_deployment_mode)) == "ha" ? "Standard_F8s_v2" : "Standard_F4s_v2"
  )

  fortigate_single_internal_ip = try([
    for interface in var.fortigate_network_interfaces :
    interface.private_ip_addresses_by_suffix["a"]
    if lower(trimspace(interface.role)) == "internal"
  ][0], null)

  fortigate_route_next_hop_ip = coalesce(
    lower(trimspace(var.fortigate_deployment_mode)) == "ha" ? try(var.fortigate_internal_load_balancer.frontend_ip_address, null) : null,
    local.fortigate_single_internal_ip
  )

  fortigate_route_table_routes = {
    for route_name, route in var.route_table_routes :
    route_name => (
      route_name == "default_to_fortigate" &&
      lower(try(route.next_hop_type, "")) == "virtualappliance" &&
      local.fortigate_route_next_hop_ip != null
      ? merge(route, { next_hop_in_ip_address = local.fortigate_route_next_hop_ip })
      : route
    )
  }

  fortigate_nsg_security_rules = {
    for rule_name, rule in var.nsg_security_rules :
    rule_name => rule
    if lower(trimspace(var.fortigate_deployment_mode)) == "ha" || !contains([
      "allow_load_balancer_health_probes",
      "allow_ha_heartbeat",
      "allow_management_ssh_https",
      "allow_approved_external_web",
    ], rule_name)
  }

  # Known Azure Fsv2 NIC limits. The active-passive target uses four interfaces
  # (external, internal, HA, and management), so Standard_F4s_v2 is invalid.
  # Unknown SKUs are left to Azure's authoritative validation.
  fortigate_vm_size_max_nics = lookup({
    standard_f2s_v2  = 2
    standard_f4s_v2  = 2
    standard_f8s_v2  = 4
    standard_f16s_v2 = 4
    standard_f32s_v2 = 8
    standard_f48s_v2 = 8
    standard_f64s_v2 = 8
    standard_f72s_v2 = 8
  }, lower(trimspace(local.fortigate_vm_size_effective)), 0)
  fortigate_enabled_interface_count = length([
    for nic in var.fortigate_network_interfaces : nic
    if contains(try(nic.enabled_in_modes, ["single", "ha"]), lower(trimspace(var.fortigate_deployment_mode)))
  ])

  module_plan_enabled = merge(var.module_plan_enabled, {
    acr                   = local.feature_flags.enable_acr
    adf                   = local.feature_flags.enable_adf
    aks                   = local.feature_flags.enable_aks
    applicationgateway    = local.feature_flags.enable_application_gateway
    appregistration       = contains(local.feature_keys, "enable_app_services") || contains(local.feature_keys, "enable_app_registration_for_appservice") ? local.feature_flags.enable_app_services && local.feature_flags.enable_app_registration_for_appservice : var.module_plan_enabled.appregistration
    appservice            = contains(local.feature_keys, "enable_app_services") ? local.feature_flags.enable_app_services : var.module_plan_enabled.appservice
    appserviceplan        = contains(local.feature_keys, "enable_app_services") ? local.feature_flags.enable_app_services : var.module_plan_enabled.appserviceplan
    automationaccount     = local.feature_flags.enable_automation_accounts
    azure_ai_search       = local.feature_flags.enable_azure_ai_search
    azure_ai_service      = local.feature_flags.enable_azure_ai_service
    cosmosdb              = local.feature_flags.enable_cosmosdb
    databricks            = local.feature_flags.enable_databricks
    enterpriseapplication = local.feature_flags.enable_enterprise_application
    eventhub              = local.feature_flags.enable_eventhub
    firewall              = local.feature_flags.enable_firewall
    functionapp           = local.feature_flags.enable_functionapp
    keyvault              = local.feature_flags.enable_keyvault
    linuxvm               = local.feature_flags.enable_linux_vm
    loganalytics          = local.feature_flags.enable_loganalytics
    logicapp              = local.feature_flags.enable_logicapp
    managedidentity       = local.feature_flags.enable_managed_identity
    managementgroups      = local.feature_flags.enable_management_group
    nsg                   = local.existing_vnet_subnets_enabled ? false : local.feature_flags.enable_nsg
    openai                = local.feature_flags.enable_openai
    policy                = local.feature_flags.enable_policy
    private_dns           = local.feature_flags.enable_private_dns
    rg                    = local.feature_flags.enable_resource_group
    roleassignments       = local.feature_flags.enable_roleassignments
    route_table           = local.feature_flags.enable_route_table
    servicebus            = local.feature_flags.enable_servicebus
    sqldb                 = local.feature_flags.enable_sqldb
    sqlmi                 = local.feature_flags.enable_sqlmi
    sqlmi_db              = local.feature_flags.enable_sqlmi_db
    storageaccount        = local.feature_flags.enable_storageaccount
    subscription_vending  = local.feature_flags.enable_subscription_bootstrap
    vnet                  = local.feature_flags.enable_vnet
    winvm                 = local.feature_flags.enable_winvm
  })
}

check "fortigate_vm_network_interface_capacity" {
  assert {
    condition = (
      !local.fortigate_enabled ||
      local.fortigate_vm_size_max_nics == 0 ||
      local.fortigate_vm_size_max_nics >= local.fortigate_enabled_interface_count
    )
    error_message = "fortigate_vm_size does not support the number of enabled FortiGate NICs. Use a SKU with at least ${local.fortigate_enabled_interface_count} NICs; Standard_F8s_v2 supports the four-NIC active-passive target."
  }
}
