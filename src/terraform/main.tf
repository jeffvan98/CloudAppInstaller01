#
# resource group
#

data "azurerm_resource_group" "existing" {
  count = var.create_virtual_machine_resource_group ? 0 : 1
  name  = var.virtual_machine_resource_group_name
}

resource "azurerm_resource_group" "main" {
  count    = var.create_virtual_machine_resource_group ? 1 : 0

  name     = var.virtual_machine_resource_group_name
  location = var.location
}

locals {
    location = coalesce(
        one(azurerm_resource_group.main[*].location),
        one(data.azurerm_resource_group.existing[*].location),
        var.location
    )

    virtual_machine_resource_group_name = coalesce(
        one(azurerm_resource_group.main[*].name),  
        one(data.azurerm_resource_group.existing[*].name) 
  )   
}

#
# virtual network
#

data "azurerm_virtual_network" "existing" {
  count               = var.create_virtual_machine_network ? 0 : 1
  name                = var.virtual_machine_network_name
  resource_group_name = local.virtual_machine_resource_group_name
}

resource "azurerm_virtual_network" "main" {
  count = var.create_virtual_machine_network ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = var.create_virtual_machine_subnet == true
      error_message = "When creating a virtual network, you must also create a subnet. Set create_virtual_machine_subnet = true."
    }
  }
  
  name                = var.virtual_machine_network_name
  resource_group_name = local.virtual_machine_resource_group_name
  location            = local.location
  address_space       = var.virtual_machine_network_address_space
}

locals {
    virtual_machine_network_name = coalesce(
        one(azurerm_virtual_network.main[*].name),
        one(data.azurerm_virtual_network.existing[*].name),
    )
}

#
# subnet
#

data "azurerm_subnet" "existing" {
  count                = var.create_virtual_machine_subnet ? 0 : 1
  name                 = var.virtual_machine_subnet_name
  virtual_network_name = local.virtual_machine_network_name
  resource_group_name  = local.virtual_machine_resource_group_name
}

resource "azurerm_subnet" "main" {
  count = var.create_virtual_machine_subnet ? 1 : 0
  
  name                 = var.virtual_machine_subnet_name
  resource_group_name  = local.virtual_machine_resource_group_name
  virtual_network_name = local.virtual_machine_network_name
  address_prefixes     = [var.virtual_machine_subnet_address_prefix]
}

locals {
    subnet_id = coalesce(
        one(azurerm_subnet.main[*].id),
        one(data.azurerm_subnet.existing[*].id),
    )
}

#
# network security group
#

data "azurerm_network_security_group" "existing" {
  count                = var.create_virtual_machine_subnet_network_security_group ? 0 : 1
  name                 = var.virtual_machine_subnet_network_security_group_name
  resource_group_name  = local.virtual_machine_resource_group_name
}

resource "azurerm_network_security_group" "main" {
  count = var.create_virtual_machine_subnet_network_security_group ? 1 : 0

  name                = var.virtual_machine_subnet_network_security_group_name
  resource_group_name = local.virtual_machine_resource_group_name
  location            = local.location
}

locals {
    network_security_group_id = coalesce(
        one(azurerm_network_security_group.main[*].id),
        one(data.azurerm_network_security_group.existing[*].id),
    )
}

resource "azurerm_subnet_network_security_group_association" "main" {
  count = var.create_virtual_machine_subnet_network_security_group && var.create_virtual_machine_subnet ? 1 : 0
  
  subnet_id                 = local.subnet_id
  network_security_group_id = local.network_security_group_id
}

#
# route table
#

resource "azurerm_route_table" "main" {
  count = var.create_route_table ? 1 : 0
  
  name                          = var.route_table_name
  location                      = local.location
  resource_group_name           = local.virtual_machine_resource_group_name
  bgp_route_propagation_enabled = var.bgp_route_propagation_enabled

  dynamic "route" {
    for_each = var.custom_routes
    content {
      name                   = route.value.name
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = route.value.next_hop_in_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "main" {
  count = var.create_route_table && var.create_virtual_machine_subnet ? 1 : 0
  
  subnet_id      = azurerm_subnet.main[0].id
  route_table_id = azurerm_route_table.main[0].id
}

#
# virtual machine
#

locals {
  is_gpu_enabled = can(regex("^Standard_N[CDGV]", var.virtual_machine_size))  
}

resource "azurerm_network_interface" "main" {
  name                          = "${var.virtual_machine_name}-nic"
  location                      = local.location
  resource_group_name           = local.virtual_machine_resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_managed_disk" "main" {
  count = var.create_data_disk ? 1 : 0
  
  name                 = "${var.virtual_machine_name}-data-disk"
  location             = local.location
  resource_group_name  = local.virtual_machine_resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = var.virtual_machine_name
  location            = local.location
  resource_group_name = local.virtual_machine_resource_group_name
  size                = var.virtual_machine_size
  admin_username      = var.admin_username
  admin_password      = var.authentication_type == "Password" ? var.admin_password : null

  disable_password_authentication = var.authentication_type == "SSH"

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  dynamic "admin_ssh_key" {
    for_each = var.authentication_type == "SSH" && var.ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned" 
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  count = var.create_data_disk ? 1 : 0
  
  managed_disk_id    = azurerm_managed_disk.main[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = "1"
  caching            = var.data_disk_caching
}

resource "azurerm_virtual_machine_extension" "nvidia_gpu_driver" {
  count = local.is_gpu_enabled && var.install_gpu_drivers ? 1 : 0
  
  name                 = "${var.virtual_machine_name}-nvidia-gpu-driver"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.HpcCompute"
  type                 = "NvidiaGpuDriverLinux"
  type_handler_version = "1.9"
  
  settings = jsonencode({
    "DriverType" = var.gpu_driver_type
  })
}

#
# optional files
#

locals {
  # Use main VNet if no specific VNet specified for private endpoints
  private_endpoint_vnet_name = coalesce(
    var.private_endpoint_virtual_network_name != "" ? var.private_endpoint_virtual_network_name : null,
    var.virtual_machine_network_name
  )
    
  # Generate storage account name if not provided
  azure_files_storage_name = coalesce(
    var.azure_files_storage_account_name != "" ? var.azure_files_storage_account_name : null,
    "${replace(var.virtual_machine_name, "-", "")}files${coalesce(one(random_id.storage_suffix[*].hex), "default")}"
  )
}

resource "random_id" "storage_suffix" {
  count = var.create_azure_files_share && var.azure_files_storage_account_name == "" ? 1 : 0
  byte_length = 4
}

#
# private endpoint
#

resource "azurerm_subnet" "private_endpoint" {
  count = var.create_azure_files_share && var.create_private_endpoint_subnet ? 1 : 0
  
  name                 = var.private_endpoint_subnet_name
  resource_group_name  = local.virtual_machine_resource_group_name
  virtual_network_name = local.private_endpoint_vnet_name
  address_prefixes     = [var.private_endpoint_subnet_address_prefix]
  
  # Required for private endpoints
  private_endpoint_network_policies = "Disabled"
}

data "azurerm_subnet" "private_endpoint_existing" {
  count = var.create_azure_files_share && !var.create_private_endpoint_subnet ? 1 : 0
  
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = local.private_endpoint_vnet_name
  resource_group_name  = local.virtual_machine_resource_group_name
}

locals {
  private_endpoint_subnet_id = var.create_azure_files_share ? (
    var.create_private_endpoint_subnet ? 
      azurerm_subnet.private_endpoint[0].id : 
      data.azurerm_subnet.private_endpoint_existing[0].id
  ) : null
}

#
# network security group
#

resource "azurerm_network_security_group" "private_endpoint" {
  count = var.create_azure_files_share && var.create_private_endpoint_nsg ? 1 : 0
  
  name                = var.private_endpoint_nsg_name
  location            = local.location
  resource_group_name = local.virtual_machine_resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  count = var.create_azure_files_share && var.create_private_endpoint_nsg && var.create_private_endpoint_subnet ? 1 : 0
  
  subnet_id                 = azurerm_subnet.private_endpoint[0].id
  network_security_group_id = azurerm_network_security_group.private_endpoint[0].id
}

#
# storage account
#

resource "azurerm_storage_account" "azure_files" {
  count = var.create_azure_files_share ? 1 : 0
  
  name                     = local.azure_files_storage_name
  resource_group_name      = local.virtual_machine_resource_group_name
  location                 = local.location
  account_tier             = var.azure_files_storage_account_tier
  account_replication_type = var.azure_files_storage_account_replication
  
  # Required for private endpoints
  public_network_access_enabled = false
  
  # Enable large file shares if using Standard tier
  large_file_share_enabled = var.azure_files_storage_account_tier == "Standard" ? true : null
}

#
# files
#

resource "azurerm_storage_share" "main" {
  count = var.create_azure_files_share ? 1 : 0
  
  name                 = var.azure_files_share_name
  storage_account_name = azurerm_storage_account.azure_files[0].name
  quota                = var.azure_files_share_quota_gb
  access_tier          = var.azure_files_share_access_tier
}

#
# dns
#

resource "azurerm_private_dns_zone" "azure_files" {
  count = var.create_azure_files_share && var.create_private_dns_zone_for_files ? 1 : 0
  
  name                = var.private_dns_zone_name_for_files
  resource_group_name = local.virtual_machine_resource_group_name

  tags = {
    Environment = "Development"
    Project     = "CloudAppInstaller"
    ManagedBy   = "Terraform"
  }
}

#
# dns link
#

resource "azurerm_private_dns_zone_virtual_network_link" "azure_files" {
  count = var.create_azure_files_share && var.create_private_dns_zone_for_files ? 1 : 0
  
  name                  = "${local.private_endpoint_vnet_name}-files-link"
  resource_group_name   = local.virtual_machine_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.azure_files[0].name
  virtual_network_id = coalesce(
    one(azurerm_virtual_network.main[*].id),
    one(data.azurerm_virtual_network.existing[*].id)
  )
  registration_enabled  = var.private_dns_zone_registration_enabled
}

#
# private endpoint
#

resource "azurerm_private_endpoint" "azure_files" {
  count = var.create_azure_files_share ? 1 : 0
  
  name                = "${azurerm_storage_account.azure_files[0].name}-pe"
  location            = local.location
  resource_group_name = local.virtual_machine_resource_group_name
  subnet_id           = local.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${azurerm_storage_account.azure_files[0].name}-psc"
    private_connection_resource_id = azurerm_storage_account.azure_files[0].id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  # Link to private DNS zone if created
  dynamic "private_dns_zone_group" {
    for_each = var.create_private_dns_zone_for_files ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [azurerm_private_dns_zone.azure_files[0].id]
    }
  }
}

#
# rbac
#

resource "azurerm_role_assignment" "vm_azure_files" {
  count = var.create_azure_files_share ? length(var.azure_files_vm_rbac_roles) : 0
  
  scope                = azurerm_storage_account.azure_files[0].id
  role_definition_name = var.azure_files_vm_rbac_roles[count.index]
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
  
  depends_on = [
    azurerm_linux_virtual_machine.main
  ]
}

# TODO - mount the share on the VM