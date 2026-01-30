variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "petclinic-rg"
}

variable "location" {
  description = "Azure region for resources."
  type        = string
  default     = "westus3"
}

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "petclinic-vnet"
}

variable "admin_password" {
  description = "Administrator password for VMSS and Database."
  type        = string
  default     = "PetClinic!2026!Azure"
}