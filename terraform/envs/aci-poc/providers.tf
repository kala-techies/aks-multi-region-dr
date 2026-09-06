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

  # POC IMPLEMENTATION: local state - see terraform/envs/dr-poc/providers.tf
  # for the same tradeoff and its production recommendation.
}

provider "azurerm" {
  features {}
}
