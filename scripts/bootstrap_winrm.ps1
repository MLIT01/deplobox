# scripts/bootstrap_winrm.ps1

# Disable the firewall for the private network so Packer can talk to it
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Configure WinRM for HTTP (Packer connects via public IP or private IP)
# Note: In production pipelines, we often use a private VNET, but this works for general builds.
cmd.exe /c winrm quickconfig -q
cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted="true"}
cmd.exe /c winrm set winrm/config/service/auth @{Basic="true"}

# Make sure the WinRM service is auto-started
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM