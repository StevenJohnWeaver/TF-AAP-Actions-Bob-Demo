# Security Module Outputs

output "app_sg_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "web_sg_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "database_sg_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "internal_sg_id" {
  description = "ID of the internal security group"
  value       = aws_security_group.internal.id
}

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    app      = aws_security_group.app.id
    web      = aws_security_group.web.id
    database = aws_security_group.database.id
    internal = aws_security_group.internal.id
  }
}