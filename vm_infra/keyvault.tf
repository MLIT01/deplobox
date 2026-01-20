data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-admin-box-secure-99" # Must be globally unique
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false

  # Grant the USER running Terraform permission to write the secret
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}

resource "random_password" "vm_password" {
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  override_special = "!@#$%" # Azure sometimes dislikes certain chars
}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "admin-vm-password"
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.kv.id
}