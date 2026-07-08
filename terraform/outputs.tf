output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "vm_ssh_command" {
  value = "ssh -i ~/.ssh/azure-platform-lab_ed25519 ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "action_group_name" {
  value = azurerm_monitor_action_group.main.name
}
