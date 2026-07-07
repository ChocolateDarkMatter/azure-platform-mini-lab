locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    environment = var.environment
    owner       = var.owner
  })
}

data "azurerm_client_config" "current" {}

resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------
# Phase 1 - Resource Group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${var.location}-001"
  location = var.location
  tags     = local.common_tags
}
