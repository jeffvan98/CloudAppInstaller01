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
    )
}

data "azurerm_virtual_network" "existing" {
  count               = var.create_virtual_machine_network ? 0 : 1
  name                = var.virtual_machine_network_name
  resource_group_name = var.virtual_machine_resource_group_name
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
  resource_group_name = var.virtual_machine_resource_group_name
  location            = local.location
  address_space       = var.virtual_machine_network_address_space
}

data "azurerm_subnet" "existing" {
  count                = var.create_virtual_machine_subnet ? 0 : 1
  name                 = var.virtual_machine_subnet_name
  virtual_network_name = var.virtual_machine_network_name
  resource_group_name  = var.virtual_machine_resource_group_name
}

resource "azurerm_subnet" "main" {
  count = var.create_virtual_machine_subnet ? 1 : 0
  
  name                 = var.virtual_machine_subnet_name
  resource_group_name  = var.virtual_machine_resource_group_name
  virtual_network_name = var.virtual_machine_network_name
  address_prefixes     = [var.virtual_machine_subnet_address_prefix]
}