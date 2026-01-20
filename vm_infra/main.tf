
resource "azurerm_resource_group" "rg" {
  name     = "rg-admin-box-live"
  location = "UK South"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-admin"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet_vm" {
  name                 = "snet-jumpbox"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for Bastion (MUST be named AzureBastionSubnet)
resource "azurerm_subnet" "snet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip_bastion" {
  name                = "pip-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-admin"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet_bastion.id
    public_ip_address_id = azurerm_public_ip.pip_bastion.id
  }
}

data "azurerm_shared_image_version" "packer_image" {
  name                = "latest"
  image_name          = "AdminJumpBox"
  gallery_name        = "gal_admin_images"
  resource_group_name = "rg-admin-core"
}

resource "azurerm_network_interface" "nic_vm" {
  name                = "nic-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

# resource "azurerm_user_assigned_identity" "vm_identity" {
#   location            = azurerm_resource_group.rg.location
#   name                = "id-admin-jumpbox"
#   resource_group_name = azurerm_resource_group.rg.name
# }

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "vm-admin-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = random_password.vm_password.result
  network_interface_ids = [
    azurerm_network_interface.nic_vm.id,
  ]

  source_image_id = data.azurerm_shared_image_version.packer_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  
#   identity {
#     type         = "UserAssigned"
#     identity_ids = [azurerm_user_assigned_identity.vm_identity.id]
#   }
}

resource "azurerm_network_security_group" "nsg_vm" {
  name                = "nsg-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowBastionInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.2.0/24" # Your Bastion Subnet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllRDP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_vm.id
  network_security_group_id = azurerm_network_security_group.nsg_vm.id
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
}