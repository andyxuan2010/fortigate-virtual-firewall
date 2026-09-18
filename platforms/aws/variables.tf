variable "aws_region" {
  description = "AWS region in which the FortiGate environment is deployed."
  type        = string
  default     = "us-east-1"
}

variable "region_code" {
  description = "Short region identifier used by the shared AWS naming modules."
  type        = string
  default     = "use1"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,8}$", var.region_code))
    error_message = "region_code must contain 2-8 lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], lower(var.environment))
    error_message = "environment must be dev or prod."
  }
}

variable "workload" {
  description = "Workload identifier used in resource names and tags."
  type        = string
  default     = "vfirewall"
}

variable "name_prefix" {
  description = "Prefix applied to resources created by this root composition."
  type        = string
  default     = "fgt-vfirewall"
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS VPC."
  type        = string
  default     = "10.32.0.0/16"
}

variable "availability_zones" {
  description = "At least two AZs; simple mode uses the first and HA mode uses both."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones must contain at least two availability zones."
  }
}

variable "nat_gateway_mode" {
  description = "NAT gateway topology for private firewall subnets."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be none, single, or per_az."
  }
}

variable "fortigate_deployment_mode" {
  description = "FortiGate topology: one node in simple mode or two nodes in HA mode."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "ha"], lower(var.fortigate_deployment_mode))
    error_message = "fortigate_deployment_mode must be single or ha."
  }
}

variable "fortigate_ami_id" {
  description = "FortiGate VM AMI ID for the selected AWS region. The default is a syntactic placeholder."
  type        = string
  default     = "ami-00000000000000000"

  validation {
    condition     = can(regex("^ami-[0-9a-fA-F]{8,17}$", var.fortigate_ami_id))
    error_message = "fortigate_ami_id must be an AWS AMI ID such as ami-0123456789abcdef0."
  }
}

variable "fortigate_license_type" {
  description = "FortiGate licensing model. Marketplace agreement and entitlement are not automated yet."
  type        = string
  default     = "byol"

  validation {
    condition     = contains(["byol", "payg"], lower(var.fortigate_license_type))
    error_message = "fortigate_license_type must be byol or payg."
  }
}

variable "fortigate_instance_type" {
  description = "EC2 instance type for each FortiGate node. Confirm FortiOS support and ENI limits."
  type        = string
  default     = "m5.large"
}

variable "fortigate_key_name" {
  description = "Optional EC2 key pair name for emergency console access."
  type        = string
  default     = null
}

variable "fortigate_user_data" {
  description = "Deprecated compatibility input treated as FortiOS CLI bootstrap config; prefer fortigate_bootstrap_config."
  type        = string
  default     = null
  sensitive   = true
}

variable "fortigate_bootstrap_config" {
  description = "Optional FortiOS CLI bootstrap configuration generated into the FortiGate module MIME user data."
  type        = string
  default     = null
  sensitive   = true
}

variable "fortigate_license_file" {
  description = "Optional BYOL license file passed to the FortiGate module. It is stored in Terraform state when supplied."
  type        = string
  default     = null
  sensitive   = true
}

variable "fortigate_ha" {
  description = "Active-passive FortiGate HA settings. Used when fortigate_deployment_mode is ha."
  type = object({
    group_id            = optional(number, 1)
    group_name          = optional(string, "fortigate-ha")
    heartbeat_interface = optional(string, "ha")
    heartbeat_priority  = optional(number, 100)
    primary_priority    = optional(number, 200)
    secondary_priority  = optional(number, 100)
    session_pickup      = optional(bool, true)
    unicast_hb          = optional(bool, true)
  })
  default = {}
}

variable "fortigate_subnet_cidrs" {
  description = "Per-role, per-node subnet CIDRs. Simple mode needs a entries; HA mode needs a and b entries."
  type = object({
    external   = map(string)
    internal   = map(string)
    ha         = map(string)
    management = map(string)
  })
  default = {
    external   = { a = "10.32.192.0/25", b = "10.32.192.128/25" }
    internal   = { a = "10.32.193.0/25", b = "10.32.193.128/25" }
    ha         = { a = "10.32.194.0/28", b = "10.32.194.16/28" }
    management = { a = "10.32.195.0/24", b = "10.32.196.0/24" }
  }
}

variable "fortigate_private_ips" {
  description = "Optional static private IP for each interface and node. Leave an entry absent for AWS allocation."
  type = object({
    external   = map(string)
    internal   = map(string)
    ha         = map(string)
    management = map(string)
  })
  default = {
    external   = { a = "10.32.192.10", b = "10.32.192.138" }
    internal   = { a = "10.32.193.10", b = "10.32.193.138" }
    ha         = { a = "10.32.194.10", b = "10.32.194.26" }
    management = { a = "10.32.195.10", b = "10.32.196.10" }
  }
}

variable "management_cidr_blocks" {
  description = "CIDRs permitted to reach the FortiGate management services. Empty means no management ingress rule."
  type        = list(string)
  default     = []
}

variable "workload_cidr_blocks" {
  description = "CIDRs permitted to forward through the FortiGate data interfaces."
  type        = list(string)
  default     = []
}

variable "external_ingress_cidr_blocks" {
  description = "Explicit CIDRs permitted on the external interface when external ingress is enabled."
  type        = list(string)
  default     = []
}

variable "enable_external_ingress" {
  description = "Enable the explicitly supplied external ingress rules."
  type        = bool
  default     = false
}

variable "fortigate_iam_policy_json" {
  description = "Optional replacement IAM policy JSON for FortiGate failover/route automation. The default is a documented placeholder policy."
  type        = string
  default     = null
  sensitive   = true
}

variable "fortigate_root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "fortigate_kms_key_id" {
  description = "Optional KMS key ID/ARN for the encrypted FortiGate root volume."
  type        = string
  default     = null
}

variable "fortigate_monitoring" {
  description = "Enable detailed EC2 monitoring."
  type        = bool
  default     = true
}

variable "fortigate_disable_api_termination" {
  description = "Protect FortiGate instances from API termination."
  type        = bool
  default     = true
}

variable "fortigate_ebs_optimized" {
  description = "Enable EBS optimization on FortiGate instances."
  type        = bool
  default     = true
}

variable "enable_workload_routes" {
  description = "Create optional workload routes through the route_manager module."
  type        = bool
  default     = false
}

variable "workload_route_table_ids" {
  description = "Route table IDs that should send the destination CIDR to a FortiGate ENI."
  type        = set(string)
  default     = []
}

variable "route_next_hop_network_interface_id" {
  description = "Deprecated compatibility input for a FortiGate ENI route target; prefer workload_route_target_id."
  type        = string
  default     = null
}

variable "route_destination_cidr_block" {
  description = "Destination CIDR for optional workload routes."
  type        = string
  default     = "0.0.0.0/0"
}

variable "workload_route_target_type" {
  description = "Primary route target type: a FortiGate ENI or a GWLB VPC endpoint."
  type        = string
  default     = "network_interface_id"

  validation {
    condition     = contains(["network_interface_id", "vpc_endpoint_id"], var.workload_route_target_type)
    error_message = "workload_route_target_type must be network_interface_id or vpc_endpoint_id."
  }
}

variable "workload_route_target_id" {
  description = "Optional primary route target ID. When omitted for an ENI target, the node-a internal ENI is used."
  type        = string
  default     = null
}

variable "enable_route_failover" {
  description = "Add a declarative secondary route target for HA workload routes. This is not a runtime health monitor."
  type        = bool
  default     = false
}

variable "workload_route_failover_active_target" {
  description = "Declarative active route target selection."
  type        = string
  default     = "primary"

  validation {
    condition     = contains(["primary", "secondary"], var.workload_route_failover_active_target)
    error_message = "workload_route_failover_active_target must be primary or secondary."
  }
}

variable "workload_route_secondary_target_type" {
  description = "Secondary route target type for declarative HA failover."
  type        = string
  default     = "network_interface_id"

  validation {
    condition     = contains(["network_interface_id", "vpc_endpoint_id"], var.workload_route_secondary_target_type)
    error_message = "workload_route_secondary_target_type must be network_interface_id or vpc_endpoint_id."
  }
}

variable "workload_route_secondary_target_id" {
  description = "Optional secondary route target ID. When omitted for an ENI target in HA, the node-b internal ENI is used."
  type        = string
  default     = null
}

variable "enable_internal_load_balancer" {
  description = "Create the FortiGate-compatible Gateway Load Balancer and register the FortiGate internal traffic interfaces as GENEVE targets."
  type        = bool
  default     = false
}

variable "gateway_load_balancer_health_check" {
  description = "GWLB target health check. FortiOS must be configured to answer the selected check."
  type = object({
    enabled             = optional(bool, true)
    protocol            = optional(string, "TCP")
    port                = optional(number, 443)
    path                = optional(string, "/")
    matcher             = optional(string, "200-399")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 3)
    unhealthy_threshold = optional(number, 3)
  })
  default = {}
}

variable "gateway_load_balancer_stickiness" {
  description = "Optional GWLB flow stickiness override."
  type = object({
    enabled = optional(bool, false)
    type    = optional(string, "source_ip_dest_ip_proto")
  })
  default = {}
}

variable "gateway_load_balancer_target_failover" {
  description = "GWLB target failover behavior for existing flows."
  type = object({
    on_deregistration = optional(string, "no_rebalance")
    on_unhealthy      = optional(string, "no_rebalance")
  })
  default = {}
}

variable "gateway_load_balancer_enable_cross_zone_load_balancing" {
  description = "Enable GWLB cross-zone load balancing."
  type        = bool
  default     = true
}

variable "gateway_load_balancer_enable_deletion_protection" {
  description = "Protect the production GWLB from API deletion."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
