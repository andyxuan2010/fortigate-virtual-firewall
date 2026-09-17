# -------------------------------------------------------------------
# Feature Toggle
# -------------------------------------------------------------------
features = {
  # The hub VNet already exists. Keep enable_vnet false so Terraform does not
  # try to create or manage vnet-hub-platform-dev itself.
  enable_vnet                  = false
  enable_existing_vnet_subnets = true
  enable_nsg                   = true
  # The IaC resource group, Key Vault, and storage account are existing
  # shared platform resources and are not created by this project.
  enable_keyvault       = false
  enable_storageaccount = false
  # FortiGate requires an admin password or SSH public key from a protected
  # pipeline secret when this feature is enabled.
  enable_fortigate      = true
  enable_route_table    = true
  enable_resource_group = true
}

# -------------------------------------------------------------------
# Shared Deployment Inputs
# -------------------------------------------------------------------
location                    = "canadacentral"
environment                 = "dev"
workload                    = "vfirewall"
iac_resource_group_name     = "rg-ccoe-iac-cc-dev"
iac_key_vault_name          = "kv-ccoe-cc-dev"
iac_storage_account_name    = "stccoeiacccdev"
network_resource_group_name = "rg-platform-dev"

# Entra group display names or object IDs used for FortiGate resource RBAC.
# Populate these with the approved dev groups before enabling FortiGate.
app_admin_group = ["85052ddf-9641-48d9-a0a9-faf8d322f573"]
app_user_group  = ["85052ddf-9641-48d9-a0a9-faf8d322f573                                                                                                                    "]

rg_tags = {
  "AppSupport Team"                   = "CCOE"
  "Application Name"                  = "CCOE INFRA IAC"
  "Application Owner"                 = "CCOE"
  "Approval Group"                    = "CCOE"
  "Business Owner"                    = "CCOE"
  "Environment"                       = "Development"
  "Infra Availability Classification" = "Bronze"
  "InfraSupport Team"                 = "CCOE"
  "Maintenance Window"                = "CCOE"
  "Project Name"                      = "CCOE INFRA IAC"
  "Project Number"                    = "N/A"
  "RPO-RTO"                           = "48H/24H"
  "Run Cost(Approved Run Budget)-USD" = "100"
  "Workload"                          = "platform"
}

# -------------------------------------------------------------------
# Existing Hub VNet Subnet Configuration
# -------------------------------------------------------------------
vnet_name = "vnet-hub-platform-dev"

nsg_name = "nsg-ba-cc-dev-vfirewall"

vnet_subnets = {
  "snet-ba-cc-dev-vfirewall-external" = {
    address_prefixes = ["10.32.192.0/25"]
  }
  "snet-ba-cc-dev-vfirewall-internal" = {
    address_prefixes = ["10.32.193.0/25"]
  }
  "snet-ba-cc-dev-vfirewall-ha" = {
    address_prefixes = ["10.32.194.0/28"]
  }
  "snet-ba-cc-dev-vfirewall-management" = {
    # Keep the existing /24 until active allocations outside the target /28
    # are migrated or released in Azure.
    address_prefixes = ["10.32.195.0/24"]
  }
}

# The shared NSG is applied to the four dedicated firewall subnets. Workload
# and FortiOS policies remain separate controls. Priority 110 broadly allows
# VirtualNetwork traffic to all four subnets; the later HA and management allow
# rules do not enforce isolation. Restricted source ranges remain to be approved.
nsg_security_rules = {
  allow_load_balancer_health_probes = {
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8008"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Allow Standard Load Balancer health probes."
  }
  allow_private_forwarding = {
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "Allow private hub and spoke traffic to the firewall interfaces."
  }
  allow_ha_heartbeat = {
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.32.194.0/28"
    destination_address_prefix = "10.32.194.0/28"
    description                = "Allow FortiGate HA synchronization on the dedicated heartbeat subnet."
  }
  allow_management_ssh_https = {
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "443"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "10.32.195.0/24"
    description                = "Allow private FortiManager or approved Bastion management traffic."
  }
  allow_approved_external_web = {
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "10.32.192.0/25"
    description                = "Allow only approved published web ports through the external load balancer."
  }
}

# -------------------------------------------------------------------
# FortiGate Virtual Firewall Configuration
# -------------------------------------------------------------------
# Architecture switch:
# - single = minimal POC/demo: one VM, Standard_F4s_v2, external/internal NICs,
#            no HA NIC, management NIC, or load balancers.
# - ha     = two BYOL VMs, Standard_F8s_v2, HA/management NICs, and LB profile.
fortigate_deployment_mode     = "single"
fortigate_license_type        = "byol"
fortigate_name_prefix         = "fgt-ba-cc-dev-vfirewall"
fortigate_resource_group_name = "rg-ba-cc-dev-vfirewall"
# Empty selects the mode-specific default: F4s_v2 for single, F8s_v2 for HA.
fortigate_vm_size = ""
fortigate_zone    = ""
fortigate_availability_zones = {
  a = "1"
  b = "2"
}
fortigate_load_balancer_frontend_zones = ["1", "2"]

fortigate_admin_username = "azureadmin"
# The fallback uses the existing shared IaC Key Vault.
fortigate_admin_password_secret_name = "fortigate-admin-password"
fortigate_admin_ssh_key_secret_name  = "fortigate-admin-pubkey"
# Supply fortigate_admin_password or fortigate_admin_ssh_public_key through a
# protected TF_VAR_* pipeline secret; do not store either credential here.
fortigate_management_access_model = "fortimanager"

fortigate_image = {
  publisher = "fortinet"
  offer     = "fortinet_fortigate-vm_v5"
  sku       = "fortinet_fg-vm"
  version   = "latest"
}

fortigate_marketplace_plan = {
  name      = "fortinet_fg-vm"
  product   = "fortinet_fortigate-vm_v5"
  publisher = "fortinet"
}

fortigate_os_disk = {
  caching              = "ReadWrite"
  storage_account_type = "Premium_LRS"
}

fortigate_custom_data = ""

fortigate_internal_load_balancer = {
  enabled               = true
  name                  = "lb-ba-cc-dev-vfirewall-internal"
  interface_name        = "internal"
  frontend_ip_address   = "10.32.193.5"
  frontend_allocation   = "Static"
  health_probe_port     = 8008
  health_probe_protocol = "Tcp"
  enable_ha_ports       = true
  enable_floating_ip    = true
}

fortigate_external_load_balancer = {
  # Temporarily disabled until explicit public listener rules are added.
  enabled               = false
  name                  = "lb-ba-cc-dev-vfirewall-external"
  interface_name        = "external"
  create_public_ip      = false
  public_ip_name        = "pip-ba-cc-dev-vfirewall-external"
  health_probe_port     = 8008
  health_probe_protocol = "Tcp"
  enable_ha_ports       = true
  enable_floating_ip    = true
}

# The module filters this list by fortigate_deployment_mode. Keeping the full
# order here makes switching back to HA a one-line mode change.
fortigate_interface_order = ["external", "ha", "internal", "management"]

fortigate_network_interfaces = [
  {
    name                          = "external"
    role                          = "external"
    subnet_name                   = "snet-ba-cc-dev-vfirewall-external"
    primary                       = true
    private_ip_address_allocation = "Static"
    private_ip_addresses_by_suffix = {
      a = "10.32.192.4"
      b = "10.32.192.6"
    }
  },
  {
    name                          = "internal"
    role                          = "internal"
    subnet_name                   = "snet-ba-cc-dev-vfirewall-internal"
    private_ip_address_allocation = "Static"
    private_ip_addresses_by_suffix = {
      a = "10.32.193.4"
      b = "10.32.193.6"
    }
  },
  {
    name                          = "ha"
    role                          = "ha"
    subnet_name                   = "snet-ba-cc-dev-vfirewall-ha"
    enabled_in_modes              = ["ha"]
    private_ip_address_allocation = "Static"
    private_ip_addresses_by_suffix = {
      a = "10.32.194.4"
      b = "10.32.194.5"
    }
  },
  {
    name                          = "management"
    role                          = "management"
    subnet_name                   = "snet-ba-cc-dev-vfirewall-management"
    enabled_in_modes              = ["ha"]
    private_ip_address_allocation = "Static"
    private_ip_addresses_by_suffix = {
      a = "10.32.195.4"
      b = "10.32.195.5"
    }
  }
]

# The route table next hop is derived from the architecture switch: the HA
# internal LB frontend in HA, or the single FortiGate internal NIC in POC mode.
# Populate route_table_subnet_ids with approved workload subnet IDs before use.
route_table_name = "rt-ba-cc-dev-vfirewall"
route_table_routes = {
  default_to_fortigate = {
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    # Automatically replaced by the root composition for the selected mode.
    next_hop_in_ip_address = "10.32.193.5"
  }
}
route_table_subnet_ids = []
