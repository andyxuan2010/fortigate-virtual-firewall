aws_region         = "us-east-1"
region_code        = "use1"
environment        = "prod"
workload           = "vfirewall"
name_prefix        = "fgt-vfirewall-prod"
vpc_cidr           = "10.32.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
nat_gateway_mode   = "per_az"

fortigate_deployment_mode = "ha"
fortigate_ami_id          = "ami-00000000000000000"
fortigate_license_type    = "byol"
fortigate_instance_type   = "m5.large"

fortigate_subnet_cidrs = {
  external   = { a = "10.32.192.0/25", b = "10.32.192.128/25" }
  internal   = { a = "10.32.193.0/25", b = "10.32.193.128/25" }
  ha         = { a = "10.32.194.0/28", b = "10.32.194.16/28" }
  management = { a = "10.32.195.0/24", b = "10.32.196.0/24" }
}

fortigate_private_ips = {
  external   = { a = "10.32.192.10", b = "10.32.192.138" }
  internal   = { a = "10.32.193.10", b = "10.32.193.138" }
  ha         = { a = "10.32.194.10", b = "10.32.194.26" }
  management = { a = "10.32.195.10", b = "10.32.196.10" }
}

# Replace these with approved administrator and workload source ranges.
management_cidr_blocks       = ["10.32.0.0/16"]
workload_cidr_blocks         = []
external_ingress_cidr_blocks = []
enable_external_ingress      = false

# HA route-target movement and the internal data-plane load balancer are placeholders.
enable_workload_routes              = false
workload_route_table_ids            = []
route_next_hop_network_interface_id = null
enable_internal_load_balancer       = true

gateway_load_balancer_health_check = {
  protocol = "TCP"
  port     = 8008
}

fortigate_ha = {
  group_id            = 1
  group_name          = "fgt-vfirewall-prod-ha"
  heartbeat_interface = "ha"
  heartbeat_priority  = 100
  primary_priority    = 200
  secondary_priority  = 100
  session_pickup      = true
  unicast_hb          = true
}

# Supply approved FortiOS CLI bootstrap content through a protected variable or secret pipeline input.
fortigate_bootstrap_config = null
fortigate_license_file     = null
fortigate_key_name         = null

tags = {
  Owner = "REPLACE_ME"
}
