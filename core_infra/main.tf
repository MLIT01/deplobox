provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "UK South"
}

resource "azurerm_resource_group" "rg_core" {
  name     = "rg-admin-core"
  location = var.location
}

# Azure Compute Gallery
resource "azurerm_shared_image_gallery" "gallery" {
  name                = "gal_admin_images"
  resource_group_name = azurerm_resource_group.rg_core.name
  location            = azurerm_resource_group.rg_core.location
  description         = "Shared images for Admin Jumpboxes"
}

# Image Definition (The logical container for versions)
resource "azurerm_shared_image" "admin_box_def" {
  name                = "AdminJumpBox"
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  resource_group_name = azurerm_resource_group.rg_core.name
  location            = azurerm_resource_group.rg_core.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "MyCompany"
    offer     = "AdminBox"
    sku       = "Win2025"
  }
}