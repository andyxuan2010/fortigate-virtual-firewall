module "vpc" {
  source = "git::https://github.com/andyxuan2010/aws-template.git//modules/vpc?ref=main"

  name        = var.name_prefix
  workload    = var.workload
  region_code = var.region_code
  environment = var.environment
  instance    = "001"
  cidr_block  = var.vpc_cidr

  enable_internet_gateway = true
  nat_gateway_mode        = var.nat_gateway_mode
  subnets                 = local.vpc_subnets
  inherited_tags          = var.tags
}

module "fortigate_security_group" {
  source = "git::https://github.com/andyxuan2010/aws-template.git//modules/security_group?ref=main"

  name                 = var.name_prefix
  workload             = var.workload
  region_code          = var.region_code
  environment          = var.environment
  instance             = "001"
  description          = "FortiGate virtual firewall interfaces"
  vpc_id               = module.vpc.vpc_id
  allow_public_ingress = var.enable_external_ingress
  ingress_rules        = local.ingress_rules
  egress_rules         = local.egress_rules
  inherited_tags       = var.tags
}

module "fortigate_iam_role" {
  source = "git::https://github.com/andyxuan2010/aws-template.git//modules/iam_role?ref=main"

  name        = var.name_prefix
  workload    = var.workload
  environment = var.environment
  instance    = "001"

  create_instance_profile = true
  trust_policy_statements = [{
    actions = ["sts:AssumeRole"]
    principals = [{
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }]
  }]
  inline_policies = {
    fortigate_failover_and_routes = local.fortigate_iam_policy
  }
  inherited_tags = var.tags
}

module "fortigate" {
  source = "git::https://github.com/andyxuan2010/aws-template.git//modules/fortigate?ref=main"

  name          = var.name_prefix
  workload      = var.workload
  region_code   = var.region_code
  environment   = var.environment
  instance      = "001"
  architecture  = local.mode == "ha" ? "active-passive" : "single"
  ami_id        = var.fortigate_ami_id
  license_type  = var.fortigate_license_type
  instance_type = var.fortigate_instance_type

  interfaces         = local.fortigate_interfaces
  security_group_ids = toset([module.fortigate_security_group.security_group_id])
  bootstrap = {
    config           = local.fortigate_bootstrap_config
    license_file     = coalesce(var.fortigate_license_file, "")
    include_hostname = true
  }
  ha                          = var.fortigate_ha
  iam_instance_profile_name   = module.fortigate_iam_role.instance_profile_name
  key_name                    = var.fortigate_key_name
  associate_public_ip_address = false
  allow_public_ip             = false
  monitoring                  = var.fortigate_monitoring
  disable_api_termination     = var.fortigate_disable_api_termination
  ebs_optimized               = var.fortigate_ebs_optimized
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = var.fortigate_root_volume_size
    encrypted             = true
    kms_key_id            = var.fortigate_kms_key_id
    delete_on_termination = true
  }
  inherited_tags = var.tags
  tags = {
    Name = var.name_prefix
  }
}

module "fortigate_gateway_load_balancer" {
  count  = var.enable_internal_load_balancer ? 1 : 0
  source = "git::https://github.com/andyxuan2010/aws-template.git//modules/gateway_load_balancer?ref=main"

  name                             = "${var.name_prefix}-gwlb"
  target_group_name                = "${var.name_prefix}-gwlb-tg"
  workload                         = var.workload
  region_code                      = var.region_code
  environment                      = var.environment
  instance                         = "001"
  vpc_id                           = module.vpc.vpc_id
  subnet_mappings                  = local.gateway_load_balancer_subnet_mappings
  targets                          = local.gateway_load_balancer_targets
  health_check                     = var.gateway_load_balancer_health_check
  stickiness                       = var.gateway_load_balancer_stickiness
  target_failover                  = var.gateway_load_balancer_target_failover
  enable_cross_zone_load_balancing = var.gateway_load_balancer_enable_cross_zone_load_balancing
  enable_deletion_protection       = var.gateway_load_balancer_enable_deletion_protection
  inherited_tags                   = var.tags
}

resource "aws_route" "workload_to_fortigate" {
  for_each = var.enable_workload_routes ? var.workload_route_table_ids : toset([])

  route_table_id         = each.value
  destination_cidr_block = var.route_destination_cidr_block
  network_interface_id   = var.route_next_hop_network_interface_id

  lifecycle {
    precondition {
      condition     = var.route_next_hop_network_interface_id != null
      error_message = "route_next_hop_network_interface_id is required when enable_workload_routes is true."
    }
  }
}
