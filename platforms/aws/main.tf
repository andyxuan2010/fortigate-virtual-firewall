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

# The shared ec2_instance module currently creates only a primary ENI and does
# not expose source_dest_check or static primary private IPs. FortiGate needs
# all interfaces to be explicitly modeled, so native ENIs/instances are used
# here until a FortiGate-specific AWS module is available.
resource "aws_network_interface" "fortigate" {
  for_each = local.interface_definitions

  subnet_id         = module.vpc.subnet_ids[each.key]
  security_groups   = [module.fortigate_security_group.security_group_id]
  source_dest_check = false
  private_ips       = each.value.private_ip == null ? null : [each.value.private_ip]

  tags = merge(local.common_tags, {
    Name          = "${var.name_prefix}-${each.key}-eni"
    FortiGateRole = each.value.role
    FortiGateNode = each.value.node
  })
}

resource "aws_instance" "fortigate" {
  for_each = toset(local.node_keys)

  ami                         = var.fortigate_ami_id
  instance_type               = var.fortigate_instance_type
  iam_instance_profile        = module.fortigate_iam_role.instance_profile_name
  key_name                    = var.fortigate_key_name
  monitoring                  = var.fortigate_monitoring
  ebs_optimized               = var.fortigate_ebs_optimized
  disable_api_termination     = var.fortigate_disable_api_termination
  user_data                   = var.fortigate_user_data
  user_data_replace_on_change = true

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.fortigate["external-${each.key}"].id
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.fortigate_root_volume_size
    encrypted             = true
    kms_key_id            = var.fortigate_kms_key_id
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name          = "${var.name_prefix}-${each.key}"
    FortiGateNode = each.key
  })
}

resource "aws_network_interface_attachment" "fortigate_secondary" {
  for_each = local.secondary_interface_definitions

  instance_id          = aws_instance.fortigate[each.value.node].id
  network_interface_id = aws_network_interface.fortigate[each.key].id
  device_index         = index(local.active_roles, each.value.role)
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
