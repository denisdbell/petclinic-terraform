terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # UNCOMMENT and configure this block for your Azure Pipeline
   backend "azurerm" {
     resource_group_name  = "rg-tfstate"
     storage_account_name = "tfstateaccountpetclinic"
     container_name       = "tfstate"
     key                  = "petclinic.tfstate"
   }
}

provider "azurerm" {
  features {}
  # Add this line to stop Terraform from trying to register providers
  skip_provider_registration = true
}