

packer init .
packer build admin-box.pkr.hcl

terraform apply -var="admin_password=ChangeMe!123456"

az keyvault secret show --name "admin-vm-password" --vault-name "kv-admin-box-secure-99" --query value

## Troubleshooting

Run these on the VM via Run Command in GUI:

Get-Content C:\Windows\System32\Sysprep\Panther\setupact.log -Tail 50
Get-EventLog -LogName Application -Newest 20 -EntryType Error,Warning
Get-Service wuauserv # should be stopped
Get-Process TiWorker -ErrorAction SilentlyContinue





