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

# ---------------------------------------------------------------------------
# Phase 2 - Networking
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}-${var.location}-001"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "app" {
  name                 = "subnet-app-${var.environment}-001"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${var.environment}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowSSHFromAdminIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllOtherInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ---------------------------------------------------------------------------
# Phase 3 - Workload Target (Linux VM)
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "vm" {
  name                = "pip-vm-${local.name_prefix}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-vm-${local.name_prefix}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-${local.name_prefix}-001"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.vm.id]
  disable_password_authentication = true
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# Phase 4 - Key Vault + dummy secret
# ---------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project}-${random_string.unique.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.common_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
  }

  # Production note (for interview): grant the VM's system-assigned managed
  # identity a "Get"-only access policy instead of using shared credentials.
}

resource "azurerm_key_vault_secret" "dummy" {
  name         = "dummy-app-secret"
  value        = "this-is-a-placeholder-not-a-real-credential"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault.main]
}

# ---------------------------------------------------------------------------
# Phase 5 - Observability
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_prefix}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${local.name_prefix}-001"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "platlabag"
  tags                = local.common_tags

  email_receiver {
    name          = "primary-owner"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "vm_cpu" {
  name                = "alert-vm-high-cpu-001"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.app.id]
  description         = "Alert when VM average CPU exceeds 80% for 5 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}
