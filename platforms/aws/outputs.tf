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
  value       = { for node, instance in aws_instance.fortigate : node => instance.id }
}

output "fortigate_interface_ids" {
  description = "FortiGate ENI IDs keyed by interface role and node."
  value       = { for key, interface in aws_network_interface.fortigate : key => interface.id }
}

output "fortigate_private_ips" {
  description = "FortiGate ENI private IPs keyed by interface role and node."
  value       = { for key, interface in aws_network_interface.fortigate : key => interface.private_ip }
}

output "workload_route_ids" {
  description = "Optional static route IDs created by this composition."
  value       = { for key, route in aws_route.workload_to_fortigate : key => route.id }
}

output "internal_load_balancer_status" {
  description = "Explicit status of the not-yet-implemented FortiGate-compatible AWS load balancer."
  value = {
    requested = var.enable_internal_load_balancer
    arn       = var.internal_load_balancer_arn
    status    = "placeholder: aws-template has no NLB/GWLB module and the available ALB module is layer-7, not equivalent to Azure HA Ports/floating IP forwarding"
  }
}

output "implementation_gaps" {
  description = "Capabilities that still require FortiGate-specific AWS implementation or operator input."
  value = [
    "Provide a real FortiGate AMI ID for the selected AWS region.",
    "Provide FortiOS bootstrap/user-data and license/entitlement configuration.",
    "Implement FortiGate HA heartbeat and failover orchestration.",
    "Implement a FortiGate-compatible NLB/GWLB data-plane load balancer if required.",
    "Implement automatic HA route-target updates; static route automation is currently manual."
  ]
}
