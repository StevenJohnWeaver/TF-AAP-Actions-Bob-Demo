# Compute Module Outputs

output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "Private IP addresses of instances"
  value       = aws_instance.app[*].private_ip
}

output "public_ips" {
  description = "Public IP addresses of instances (Elastic IPs if assigned)"
  value       = var.assign_public_ip ? aws_eip.app[*].public_ip : aws_instance.app[*].public_ip
}

output "subnet_ids" {
  description = "Subnet IDs where instances are placed"
  value       = aws_instance.app[*].subnet_id
}

output "availability_zones" {
  description = "Availability zones where instances are placed"
  value       = aws_instance.app[*].availability_zone
}

output "instance_details" {
  description = "Detailed information about instances"
  value = [
    for idx, instance in aws_instance.app : {
      id                = instance.id
      name              = "app-server-${idx + 1}"
      private_ip        = instance.private_ip
      public_ip         = var.assign_public_ip ? aws_eip.app[idx].public_ip : instance.public_ip
      subnet_id         = instance.subnet_id
      availability_zone = instance.availability_zone
    }
  ]
}