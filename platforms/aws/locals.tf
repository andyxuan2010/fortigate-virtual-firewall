locals {
  mode = lower(var.fortigate_deployment_mode)

  node_keys = local.mode == "ha" ? ["a", "b"] : ["a"]

  active_roles = local.mode == "ha" ? ["external", "ha", "internal", "management"] : ["external", "internal"]

  node_az = {
    a = var.availability_zones[0]
    b = var.availability_zones[1]
  }

  common_tags = merge(var.tags, {
    Environment          = lower(var.environment)
    Workload             = var.workload
    Platform             = "aws"
    Service              = "fortigate-virtual-firewall"
    ManagedBy            = "terraform"
    FortiGateMode        = local.mode
    FortiGateLicenseType = lower(var.fortigate_license_type)
  })

  subnet_definitions = {
    for item in flatten([
      for node in local.node_keys : [
        for role in local.active_roles : {
          key               = "${role}-${node}"
          role              = role
          node              = node
          cidr_block        = var.fortigate_subnet_cidrs[role][node]
          availability_zone = local.node_az[node]
          public            = role == "external"
        }
      ]
    ]) : item.key => item
  }

  vpc_subnets = {
    for key, subnet in local.subnet_definitions : key => {
      cidr_block              = subnet.cidr_block
      availability_zone       = subnet.availability_zone
      public                  = subnet.public
      map_public_ip_on_launch = false
      assign_ipv6_on_creation = false
      tags = {
        Name          = "${var.name_prefix}-${key}"
        FortiGateRole = subnet.role
        FortiGateNode = subnet.node
      }
    }
  }

  fortigate_interfaces = {
    for role in local.active_roles : role => merge(
      {
        role                  = role
        primary               = role == "external"
        device_index          = index(local.active_roles, role)
        security_group_ids    = toset([module.fortigate_security_group.security_group_id])
        enabled_architectures = toset([local.mode == "ha" ? "active-passive" : "single"])
      },
      local.mode == "ha" ? {
        subnet_ids = {
          for node in local.node_keys : node => module.vpc.subnet_ids["${role}-${node}"]
        }
        private_ips = {
          for node in local.node_keys : node => try(var.fortigate_private_ips[role][node], null)
        }
        } : {
        subnet_id  = module.vpc.subnet_ids["${role}-a"]
        private_ip = try(var.fortigate_private_ips[role].a, null)
      }
    )
  }

  gateway_load_balancer_subnet_mappings = {
    for node in local.node_keys : "az-${node}" => {
      availability_zone = local.node_az[node]
      subnet_id         = module.vpc.subnet_ids["external-${node}"]
    }
  }

  gateway_load_balancer_targets = {
    for node in local.node_keys : "fortigate-${node}" => {
      availability_zone = local.node_az[node]
      ip                = module.fortigate.network_interface_private_ips["${node}-internal"]
    }
  }

  fortigate_bootstrap_config = coalesce(var.fortigate_bootstrap_config, var.fortigate_user_data, "")

  management_ingress_rules = merge(
    {
      for index, cidr in var.management_cidr_blocks : "management-ssh-${index}" => {
        description = "Management SSH"
        ip_protocol = "tcp"
        from_port   = 22
        to_port     = 22
        cidr_ipv4   = cidr
      }
    },
    {
      for index, cidr in var.management_cidr_blocks : "management-https-${index}" => {
        description = "Management HTTPS"
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = cidr
      }
    }
  )

  workload_ingress_rules = {
    for index, cidr in var.workload_cidr_blocks : "workload-${index}" => {
      description = "Workload forwarding traffic"
      ip_protocol = "-1"
      cidr_ipv4   = cidr
    }
  }

  external_ingress_rules = var.enable_external_ingress ? {
    for index, cidr in var.external_ingress_cidr_blocks : "external-${index}" => {
      description = "Approved external ingress"
      ip_protocol = "-1"
      cidr_ipv4   = cidr
    }
  } : {}

  ha_ingress_rules = local.mode == "ha" ? {
    for index, cidr in values(var.fortigate_subnet_cidrs.ha) : "ha-${index}" => {
      description = "FortiGate HA synchronization"
      ip_protocol = "-1"
      cidr_ipv4   = cidr
    }
  } : {}

  ingress_rules = merge(
    {
      health-probe = {
        description = "Internal health probe"
        ip_protocol = "tcp"
        from_port   = 8008
        to_port     = 8008
        cidr_ipv4   = var.vpc_cidr
      }
    },
    local.management_ingress_rules,
    local.workload_ingress_rules,
    local.external_ingress_rules,
    local.ha_ingress_rules
  )

  egress_rules = {
    all = {
      description = "FortiGate egress"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  default_fortigate_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:ReplaceRoute",
        "ec2:DeleteRoute",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses",
        "ec2:ModifyNetworkInterfaceAttribute"
      ]
      Resource = "*"
    }]
  })

  fortigate_iam_policy = coalesce(var.fortigate_iam_policy_json, local.default_fortigate_iam_policy)
}
