terraform {

  backend "azurerm" {
    resource_group_name  = "mltest-tfstates-gnu-rg"
    storage_account_name = "mltestgnutfstate"
    container_name       = "tfstate"
    key                  = "packer-infra.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}