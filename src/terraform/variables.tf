#
# location
#

variable "location" {
    description = "location for all resources"
    type        = string
    default     = "East US"
}

#
# resource group
#

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

#
# virtual network
#

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

#
# subnet
#

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

#
# network security group
#

variable "create_virtual_machine_subnet_network_security_group" {
  description = "Flag to create a network security group for the subnet"
  type        = bool
  default     = true
}

variable "virtual_machine_subnet_network_security_group_name" {
  description = "Name of the network security group for the subnet"
  type        = string
  default     = "default-nsg"
}

#
# route table
#

variable "create_route_table" {
  description = "Create a User-Defined Route (UDR) table for the subnet"
  type        = bool
  default     = false
}

variable "route_table_name" {
  description = "Name of the route table"
  type        = string
  default     = "default-rt"
}

variable "custom_routes" {
  description = "List of custom routes to add to the route table"
  type = list(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = []
  
  validation {
    condition = alltrue([
      for route in var.custom_routes : 
      contains(["VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"], route.next_hop_type)
    ])
    error_message = "next_hop_type must be one of: VirtualNetworkGateway, VnetLocal, Internet, VirtualAppliance, None"
  }
}

variable "bgp_route_propagation_enabled" {
  description = "Enable BGP route propagation on the route table"
  type        = bool
  default     = true
}

#
# virtual machine
#

variable "virtual_machine_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "default-vm"
}

variable "virtual_machine_size" {
  description = "SKU/size of the virtual machine"
  type        = string
  default     = "Standard_D4s_v5"
  
  validation {
    condition = can(regex("^Standard_", var.virtual_machine_size))
    error_message = "VM size must be a valid Azure VM SKU starting with 'Standard_'."
  }
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureuser"
  
  validation {
    condition = length(var.admin_username) >= 1 && length(var.admin_username) <= 64
    error_message = "Admin username must be between 1 and 64 characters."
  }
}

variable "authentication_type" {
  description = "Type of authentication (SSH or Password)"
  type        = string
  default     = "SSH"
  
  validation {
    condition = contains(["SSH", "Password"], var.authentication_type)
    error_message = "Authentication type must be either 'SSH' or 'Password'."
  }
}

variable "admin_password" {
  description = "Administrator password (only used if authentication_type is Password)"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for authentication (only used if authentication_type is SSH)"
  type        = string
  default     = null
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 250
  
  validation {
    condition = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "OS disk size must be between 30 GB and 4095 GB."
  }
}

variable "os_disk_type" {
  description = "Storage type for OS disk"
  type        = string
  default     = "Premium_LRS"
  
  validation {
    condition = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "UltraSSD_LRS"], var.os_disk_type)
    error_message = "OS disk type must be Standard_LRS, StandardSSD_LRS, Premium_LRS, or UltraSSD_LRS."
  }
}

variable "create_data_disk" {
  description = "Create an additional data disk"
  type        = bool
  default     = false
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 1024
  
  validation {
    condition = var.data_disk_size_gb >= 4 && var.data_disk_size_gb <= 32767
    error_message = "Data disk size must be between 4 GB and 32767 GB."
  }
}

variable "data_disk_type" {
  description = "Storage type for data disk"
  type        = string
  default     = "Premium_LRS"
  
  validation {
    condition = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "UltraSSD_LRS"], var.data_disk_type)
    error_message = "Data disk type must be Standard_LRS, StandardSSD_LRS, Premium_LRS, or UltraSSD_LRS."
  }
}

variable "data_disk_caching" {
  description = "Caching type for the data disk"
  type        = string
  default     = "None"
  
  validation {
    condition = contains(["None", "ReadOnly", "ReadWrite"], var.data_disk_caching)
    error_message = "Data disk caching must be None, ReadOnly, or ReadWrite."
  }  
}

variable "install_gpu_drivers" {
  description = "Install NVIDIA GPU drivers (if VM supports GPU)"
  type        = bool
  default     = true
}

variable "gpu_driver_type" {
  description = "Type of GPU driver to install"
  type        = string
  default     = "CUDA"
  
  validation {
    condition = contains(["CUDA", "GRID"], var.gpu_driver_type)
    error_message = "GPU driver type must be either 'CUDA' (for compute) or 'GRID' (for graphics)."
  }
}

#
# azure files share configuration (optional)
#

variable "create_azure_files_share" {
  description = "Create and configure an Azure Files share with private endpoint"
  type        = bool
  default     = false
}

#
# files - subnet
#

variable "create_private_endpoint_subnet" {
  description = "Create a new subnet for private endpoints (only used if create_azure_files_share is true)"
  type        = bool
  default     = true
}

variable "private_endpoint_virtual_network_name" {
  description = "Name of the virtual network that contains or will contain the private endpoint subnet"
  type        = string
  default     = ""  # Will default to main VNet if empty
}

variable "private_endpoint_subnet_name" {
  description = "Name of the subnet for private endpoints (new or existing)"
  type        = string
  default     = "private-endpoint-subnet"
}

variable "private_endpoint_subnet_address_prefix" {
  description = "Address prefix for the private endpoint subnet (only used if creating new subnet)"
  type        = string
  default     = "10.0.2.0/24"
}

#
# files - network security group
#

variable "create_private_endpoint_nsg" {
  description = "Create a network security group for the private endpoint subnet"
  type        = bool
  default     = true
}

variable "private_endpoint_nsg_name" {
  description = "Name of the NSG for the private endpoint subnet"
  type        = string
  default     = "private-endpoint-nsg"
}

#
# files - storage account
#

variable "azure_files_storage_account_name" {
  description = "Name of the storage account for Azure Files (leave empty for auto-generated)"
  type        = string
  default     = ""
  
  validation {
    condition = var.azure_files_storage_account_name == "" || (
      length(var.azure_files_storage_account_name) >= 3 && 
      length(var.azure_files_storage_account_name) <= 24 &&
      can(regex("^[a-z0-9]+$", var.azure_files_storage_account_name))
    )
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "azure_files_storage_account_tier" {
  description = "Performance tier of the storage account"
  type        = string
  default     = "Standard"
  
  validation {
    condition = contains(["Standard", "Premium"], var.azure_files_storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "azure_files_storage_account_replication" {
  description = "Replication type for the storage account"
  type        = string
  default     = "LRS"
  
  validation {
    condition = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.azure_files_storage_account_replication)
    error_message = "Replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "azure_files_share_name" {
  description = "Name of the Azure Files share"
  type        = string
  default     = "vmfileshare"
  
  validation {
    condition = can(regex("^[a-z0-9-]{3,63}$", var.azure_files_share_name))
    error_message = "File share name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "azure_files_share_quota_gb" {
  description = "Quota for the Azure Files share in GB"
  type        = number
  default     = 100
  
  validation {
    condition = var.azure_files_share_quota_gb >= 1 && var.azure_files_share_quota_gb <= 102400
    error_message = "File share quota must be between 1 GB and 102,400 GB (100 TB)."
  }
}

variable "azure_files_share_access_tier" {
  description = "Access tier for the Azure Files share"
  type        = string
  default     = "TransactionOptimized"
  
  validation {
    condition = contains(["TransactionOptimized", "Hot", "Cool"], var.azure_files_share_access_tier)
    error_message = "Access tier must be TransactionOptimized, Hot, or Cool."
  }
}

#
# files - rbac
#

variable "azure_files_vm_rbac_roles" {
  description = "RBAC roles to assign to the VM for Azure Files access"
  type        = list(string)
  default     = [
    "Storage File Data SMB Share Contributor"
  ]
  
  validation {
    condition = alltrue([
      for role in var.azure_files_vm_rbac_roles :
      contains([
        "Storage File Data SMB Share Reader",
        "Storage File Data SMB Share Contributor", 
        "Storage File Data SMB Share Elevated Contributor"
      ], role)
    ])
    error_message = "RBAC roles must be valid Azure Files SMB share roles."
  }
}

#
# files - private dns
#

variable "create_private_dns_zone_for_files" {
  description = "Create a private DNS zone for Azure Files private endpoint"
  type        = bool
  default     = true
}

variable "private_dns_zone_name_for_files" {
  description = "Name of the private DNS zone for Azure Files"
  type        = string
  default     = "privatelink.file.core.windows.net"
}

variable "private_dns_zone_target_vnets" {
  description = "List of virtual network IDs to link to the private DNS zone"
  type        = list(string)
  default     = []  # Will default to main VNet if empty
}

variable "private_dns_zone_registration_enabled" {
  description = "Enable auto-registration in the private DNS zone"
  type        = bool
  default     = false
}