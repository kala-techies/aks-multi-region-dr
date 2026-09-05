terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # POC IMPLEMENTATION: local state. Fine for a single operator, not safe for
  # a team (no locking, state lives on one machine's disk).
  #
  # PRODUCTION RECOMMENDATION: remote backend (azurerm storage account with
  # a container + state locking) created once, out-of-band, before this
  # config's first apply - commented out here since it introduces a
  # chicken-and-egg bootstrap problem for a POC.
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstatenotesdr"
  #   container_name       = "tfstate"
  #   key                  = "dr-poc.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
