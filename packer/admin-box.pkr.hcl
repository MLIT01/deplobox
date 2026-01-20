packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "gallery_resource_group" {
  type    = string
  default = "rg-admin-core" # The RG where your Gallery lives
}

variable "gallery_name" {
  type    = string
  default = "gal_admin_images"
}

variable "image_name" {
  type    = string
  default = "AdminJumpBox"
}

variable "image_version" {
  type    = string
  default = "1.0.0" # Bump this monthly
}

source "azure-arm" "windows" {
  # 1. Authentication (Uses your local az login)
  use_azure_cli_auth = true

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2025-Datacenter-g2" # Confirm this SKU in your region, or use 2022-Datacenter

  
  vm_size         = "Standard_D2s_v3"
  location        = "UK South"

  communicator    = "winrm"
  winrm_use_ssl   = true
  winrm_insecure  = true
  winrm_timeout   = "5m"
  winrm_username  = "packer"
  
  # This command executes the script we uploaded via user_data_file
  user_data_file  = "./scripts/bootstrap_winrm.ps1"
  
  # 5. Output: Send to Azure Compute Gallery
  shared_image_gallery_destination {
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = var.image_name
    image_version        = var.image_version
    replication_regions  = ["UK South"]
  }
}

build {
  sources = ["source.azure-arm.windows"]

  # Step 1: Install Chocolatey (Package Manager)
  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    ]
  }

  # Step 2: Install Admin Tools
  provisioner "powershell" {
    inline = [
      "choco install terraform -y",
      "choco install azure-cli -y",
      "choco install git -y",
      "choco install powershell-core -y",
      "choco install vscode -y",          
      "choco install notepadplusplus -y",
      "choco install firefox -y",
      "choco install sql-server-management-studio -y"
    ]
  }

  # Install VS Code Extensions
  provisioner "powershell" {
    environment_vars = [
      "PATH=$env:PATH;C:\\Program Files\\Microsoft VS Code\\bin" # Ensure 'code' command is found
    ]
    inline = [
      "Write-Output 'Installing VS Code Extensions...'",
      
      # Install the extensions
      "code --install-extension hashicorp.terraform",
      "code --install-extension ms-vscode.azurecli",

      # Create the Default User extension directory
      "New-Item -Path 'C:\\Users\\Default\\.vscode\\extensions' -ItemType Directory -Force",

      # Copy extensions from current user to Default User
      "Copy-Item -Path \"$env:USERPROFILE\\.vscode\\extensions\\*\" -Destination 'C:\\Users\\Default\\.vscode\\extensions' -Recurse -Force"
    ]
  }

  # Windows Update (Optional - This takes a LONG time)
  # Ideally, use the 'community.windows-update' plugin, but for now we skip to keep it simple.
  
  # Sysprep
  provisioner "powershell" {
    inline = [
      # Stop Windows Update Service to prevent Sysprep hangs
      "Get-AppxPackage -Name *NotepadPlusPlus* | Remove-AppxPackage -ErrorAction SilentlyContinue",
      "Write-Output 'Stopping Windows Services...'",
      "Stop-Service -Name 'wuauserv','bits','cryptsvc','trustedinstaller' -Force -ErrorAction SilentlyContinue",
      "Stop-Process -Name 'TiWorker','msiexec' -Force -ErrorAction SilentlyContinue",

      # Run Sysprep
      "Write-Output 'Syprepping...'",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",

      # Wait for Sysprep to finish
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select -ExpandProperty ImageState; if($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break } Start-Sleep -s 10 }"
    ]
  }
}