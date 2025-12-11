# Red Hat + HashiCorp Demo - Terraform Variables

# ============================================================================
# HCP Vault Configuration
# ============================================================================

variable "hcp_vault_address" {
  description = "HCP Vault cluster address (e.g., https://your-cluster.vault.hashicorp.cloud:8200)"
  type        = string
}

variable "hcp_vault_namespace" {
  description = "HCP Vault namespace"
  type        = string
  default     = "admin"
}

variable "hcp_vault_token" {
  description = "HCP Vault authentication token"
  type        = string
  sensitive   = true
}

variable "vault_role_id" {
  description = "Vault AppRole Role ID"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Vault AppRole Secret ID"
  type        = string
  sensitive   = true
}

# ============================================================================
# Ansible Automation Platform Configuration
# ============================================================================

variable "aap_host" {
  description = "Ansible Automation Platform controller URL (e.g., https://aap-controller.example.com)"
  type        = string
}

variable "aap_username" {
  description = "AAP username for authentication"
  type        = string
  sensitive   = true
}

variable "aap_password" {
  description = "AAP password for authentication"
  type        = string
  sensitive   = true
}

variable "aap_token" {
  description = "AAP token for authentication (alternative to username/password)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aap_job_template_id" {
  description = "AAP job template ID for Configure AWS Infrastructure"
  type        = number
}

variable "eda_event_stream_name" {
  description = "Name of the EDA event stream to post events to"
  type        = string
  default     = "terraform-infrastructure-events"
}

variable "eda_event_stream_uuid" {
  description = "UUID of the EDA event stream (found in event stream URL)"
  type        = string
  sensitive   = true
}

variable "eda_event_stream_username" {
  description = "Username for posting events to the EDA event stream"
  type        = string
  sensitive   = true
}

variable "eda_event_stream_password" {
  description = "Password for posting events to the EDA event stream"
  type        = string
  sensitive   = true
}

# ============================================================================
# AWS Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty to use latest Amazon Linux 2)"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for EC2 instances"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

# ============================================================================
# Ansible Configuration
# ============================================================================

variable "ansible_user" {
  description = "Default SSH user for Ansible"
  type        = string
  default     = "ec2-user"
}

variable "ansible_ssh_key_path" {
  description = "Path to SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/demo-key.pem"
}

# ============================================================================
# OpenShift Configuration
# ============================================================================

variable "openshift_namespace" {
  description = "OpenShift namespace for application deployment"
  type        = string
  default     = "demo-app"
}

variable "application_name" {
  description = "Name of the application to deploy"
  type        = string
  default     = "demo-app"
}

variable "openshift_replicas" {
  description = "Number of application replicas in OpenShift"
  type        = number
  default     = 2
  
  validation {
    condition     = var.openshift_replicas > 0 && var.openshift_replicas <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

# ============================================================================
# General Configuration
# ============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "demo"
  
  validation {
    condition     = contains(["dev", "demo", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, demo, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "redhat-hashicorp"
}

variable "terraform_run_id" {
  description = "Terraform Cloud run ID (auto-populated by HCP Terraform)"
  type        = string
  default     = "local-run"
}

variable "terraform_workspace" {
  description = "Terraform Cloud workspace name (auto-populated by HCP Terraform)"
  type        = string
  default     = "default"
}

variable "terraform_organization" {
  description = "Terraform Cloud organization name (auto-populated by HCP Terraform)"
  type        = string
  default     = "default"
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
