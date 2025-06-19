variable "location" {
    description = "location for all resources"
    type        = string
    default     = "East US"
}

variable "create_virtual_machine_resource_group" {
  description = "Flag to create a resource group for the virtual machine"
  type        = bool
  default     = true  
}

variable "virtual_machine_resource_group_name" {
  description = "Name of the resource group for the virtual machine"
  type        = string
  default     = "default-vm-rg"  
}

variable "create_virtual_machine_network" {
  description = "Flag to create a virtual network"
  type        = bool
  default     = true
}

variable "virtual_machine_network_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "default-vnet"
}

variable "virtual_machine_network_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition = length(var.virtual_machine_network_address_space) > 0 && alltrue([
      for cidr in var.virtual_machine_network_address_space : can(cidrhost(cidr, 0))
    ])
    error_message = "All network address spaces must be valid CIDR blocks."
  }  
}

variable "create_virtual_machine_subnet" {
  description = "Flag to create a subnet"
  type        = bool
  default     = true

  validation {
    condition = var.create_virtual_machine_network == false || var.create_virtual_machine_subnet == true
    error_message = "When creating a new virtual network (create_virtual_machine_network = true), you must also create a new subnet (create_virtual_machine_subnet = true)."
  }  
}

variable "virtual_machine_subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "default-subnet"  
}

variable "virtual_machine_subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition = can(cidrhost(var.virtual_machine_subnet_address_prefix, 0))
    error_message = "The subnet address prefix must be a valid CIDR block."
  }
}