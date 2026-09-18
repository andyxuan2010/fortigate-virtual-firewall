aws_region         = "us-east-1"
region_code        = "use1"
environment        = "dev"
workload           = "vfirewall"
name_prefix        = "fgt-vfirewall-dev"
vpc_cidr           = "10.32.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
nat_gateway_mode   = "single"

fortigate_deployment_mode = "single"
fortigate_ami_id          = "ami-00000000000000000"
fortigate_license_type    = "byol"
fortigate_instance_type   = "m5.large"

fortigate_subnet_cidrs = {
  external   = { a = "10.32.192.0/25" }
  internal   = { a = "10.32.193.0/25" }
  ha         = {}
  management = {}
}

fortigate_private_ips = {
  external   = { a = "10.32.192.10" }
  internal   = { a = "10.32.193.10" }
  ha         = {}
  management = {}
}

# Replace this private CIDR with the approved administrator source range.
management_cidr_blocks       = ["10.32.0.0/16"]
workload_cidr_blocks         = []
external_ingress_cidr_blocks = []
enable_external_ingress      = false

# Route-manager and a FortiGate-compatible GWLB are disabled for the simple example.
enable_workload_routes                = false
workload_route_table_ids              = []
route_next_hop_network_interface_id   = null
workload_route_target_type            = "network_interface_id"
workload_route_target_id              = null
enable_route_failover                 = false
workload_route_failover_active_target = "primary"
workload_route_secondary_target_type  = "network_interface_id"
workload_route_secondary_target_id    = null
enable_internal_load_balancer         = false

# Supply approved FortiOS CLI bootstrap content through a protected variable or secret pipeline input.
fortigate_bootstrap_config = null
fortigate_license_file     = null
fortigate_ha               = {}
fortigate_key_name         = null

tags = {
  Owner = "REPLACE_ME"
}
