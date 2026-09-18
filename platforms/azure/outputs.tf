# output "rg-name" {
#   value = module.rg.name
# }
# output "vm-privateip" {
#   value = module.linuxvm.privateip
# }

# output "custom_command" {
#   value = module.linuxvm.custom_command
# }
# output "linuxvm-public-ip" {
#   value = module.linuxvm.public_ip
# }
# output "linuxvm-public-public_ip2" {
#   value = module.linuxvm.public_ip2
# }
# output "sqlmi_name" {
#   value = module.sqlmi_db.name
# }

# output "sqlmi_administrator_login" {
#   value = module.sqlmi_db.administrator_login
# }

# output "sqlmi_fqdn" {
#   value = module.sqlmi_db.fqdn
# }

# output "app-vm" {
#   value = module.vm.app_vm.name
# }

# output "azurerm_cognitive_account_name" {
#   value = azurerm_cognitive_account.cognitive-service.name
# }

# # Output the endpoint and private endpoint URL
# output "cognitive-service-endpoint" {
#   value = azurerm_cognitive_account.cognitive-service.endpoint
# }

# output "private_endpoint_url" {
#   value = azurerm_private_endpoint.edp-cognitive.custom_dns_configs[0].fqdn
# }

# output "private_endpoint_private_ips" {
#   value = azurerm_private_endpoint.edp-cognitive.custom_dns_configs[0].ip_addresses
# }

# output "app_registration_application_id" {
#   description = "Application (client) ID of the app registration created for App Service auth, if enabled."
#   value       = var.enable_app_registration_for_appservice ? module.app_registration[0].application_id : null
# }
#
# output "app_registration_application_object_id" {
#   description = "Object ID of the app registration created for App Service auth, if enabled."
#   value       = var.enable_app_registration_for_appservice ? module.app_registration[0].application_object_id : null
# }
#
# output "app_registration_client_secret" {
#   description = "Client secret created for the app registration, if enabled."
#   value       = var.enable_app_registration_for_appservice ? module.app_registration[0].client_secret : null
#   sensitive   = true
# }

output "fortigate_private_ip_addresses" {
  description = "Private IP addresses assigned to FortiGate NICs, keyed by <instance>-<interface>."
  value       = local.fortigate_enabled ? module.fortigate[0].private_ip_addresses : {}
}

output "fortigate_virtual_machine_ids" {
  description = "FortiGate VM IDs keyed by instance suffix."
  value       = local.fortigate_enabled ? module.fortigate[0].virtual_machine_ids : {}
}

output "fortigate_managed_identity_principal_ids" {
  description = "System-assigned VM identity principal IDs keyed by instance suffix."
  value       = local.fortigate_enabled ? module.fortigate[0].managed_identity_principal_ids : {}
}

output "fortigate_route_role_assignment_ids" {
  description = "Route-table-scoped identity role assignment IDs keyed by instance suffix."
  value       = { for suffix, assignment in azurerm_role_assignment.fortigate_route_updater : suffix => assignment.id }
}

output "fortigate_network_interface_ids" {
  description = "FortiGate NIC IDs keyed by <instance>-<interface>."
  value       = local.fortigate_enabled ? module.fortigate[0].network_interface_ids : {}
}

output "fortigate_interface_order" {
  description = "Configured Azure NIC attachment order; FortiOS port mapping requires appliance verification."
  value       = local.fortigate_enabled ? module.fortigate[0].interface_order : []
}

output "fortigate_internal_load_balancer_id" {
  description = "Internal Standard Load Balancer ID, when enabled."
  value       = local.fortigate_enabled ? module.fortigate[0].internal_load_balancer_id : null
}

output "fortigate_internal_load_balancer_frontend_ip" {
  description = "Internal Standard Load Balancer frontend IP, when enabled."
  value       = local.fortigate_enabled ? module.fortigate[0].internal_load_balancer_frontend_ip : null
}

output "fortigate_external_load_balancer_id" {
  description = "External Standard Load Balancer ID, when enabled."
  value       = local.fortigate_enabled ? module.fortigate[0].external_load_balancer_id : null
}

output "fortigate_external_public_ip_id" {
  description = "External load balancer public IP ID, when the approved public frontend is enabled."
  value       = local.fortigate_enabled ? module.fortigate[0].external_public_ip_id : null
}

output "fortigate_route_table_id" {
  description = "UDR route table ID, when the FortiGate routing feature is enabled."
  value       = local.module_plan_enabled.route_table ? module.route_table[0].id : null
}

output "fortigate_app_admin_group_role_assignment_ids" {
  description = "Contributor role assignments for FortiGate app admin groups."
  value       = local.fortigate_enabled ? module.fortigate[0].app_admin_group_role_assignment_ids : {}
}

output "fortigate_app_user_group_role_assignment_ids" {
  description = "Reader role assignments for FortiGate app user groups."
  value       = local.fortigate_enabled ? module.fortigate[0].app_user_group_role_assignment_ids : {}
}
