variable "admin_password" {
  type      = string
  sensitive = true
  # You will pass this in at runtime: -var="admin_password=..."
}