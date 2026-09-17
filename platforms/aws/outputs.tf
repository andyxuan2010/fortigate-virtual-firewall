output "deployment_mode" {
  description = "Selected FortiGate deployment mode."
  value       = local.mode
}

output "vpc_id" {
  description = "FortiGate VPC ID."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "FortiGate subnet IDs keyed by interface role and node."
  value       = module.vpc.subnet_ids
}

output "security_group_id" {
  description = "FortiGate security group ID."
  value       = module.fortigate_security_group.security_group_id
}

output "iam_role_arn" {
  description = "IAM role ARN assigned to the FortiGate instances."
  value       = module.fortigate_iam_role.role_arn
}

output "instance_profile_name" {
  description = "IAM instance profile assigned to the FortiGate instances."
  value       = module.fortigate_iam_role.instance_profile_name
}

output "fortigate_instance_ids" {
  description = "FortiGate EC2 instance IDs keyed by node."
  value       = module.fortigate.instance_ids
}

output "fortigate_interface_ids" {
  description = "FortiGate ENI IDs keyed by interface role and node."
  value = merge(
    { for node, eni_id in module.fortigate.primary_network_interface_ids : "${node}-external" => eni_id },
    module.fortigate.network_interface_ids
  )
}

output "fortigate_private_ips" {
  description = "FortiGate ENI private IPs keyed by interface role and node."
  value = merge(
    { for node, ip in module.fortigate.instance_private_ips : "${node}-external" => ip },
    module.fortigate.network_interface_private_ips
  )
}

output "workload_route_ids" {
  description = "Optional static route IDs created by this composition."
  value       = { for key, route in aws_route.workload_to_fortigate : key => route.id }
}

output "internal_load_balancer_status" {
  description = "Gateway Load Balancer status and integration boundary."
  value = {
    requested        = var.enable_internal_load_balancer
    arn              = try(module.fortigate_gateway_load_balancer[0].load_balancer_arn, null)
    target_group_arn = try(module.fortigate_gateway_load_balancer[0].target_group_arn, null)
    status           = var.enable_internal_load_balancer ? "GWLB provisioned; FortiOS GENEVE configuration, GWLB endpoints, endpoint services, and route tables remain caller responsibilities" : "disabled"
  }
}

output "gateway_load_balancer_arn" {
  description = "Gateway Load Balancer ARN, or null when disabled."
  value       = try(module.fortigate_gateway_load_balancer[0].load_balancer_arn, null)
}

output "gateway_load_balancer_target_group_arn" {
  description = "GWLB GENEVE target group ARN, or null when disabled."
  value       = try(module.fortigate_gateway_load_balancer[0].target_group_arn, null)
}

output "implementation_gaps" {
  description = "Capabilities that still require FortiGate-specific AWS implementation or operator input."
  value = [
    "Provide a real FortiGate AMI ID for the selected AWS region.",
    "Provide FortiOS bootstrap/user-data and license/entitlement configuration.",
    "Configure FortiOS GENEVE and health-check behavior when GWLB is enabled.",
    "Create GWLB endpoints, endpoint services, and route-table steering for the approved traffic path.",
    "Implement automatic HA route-target updates; static route automation is currently manual."
  ]
}
