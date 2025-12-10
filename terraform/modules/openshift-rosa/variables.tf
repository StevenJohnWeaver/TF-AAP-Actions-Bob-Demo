# Variables for OpenShift on AWS (ROSA) Module

variable "cluster_name" {
  description = "Name of the OpenShift cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones for the cluster"
  type        = list(string)
}

variable "openshift_version" {
  description = "OpenShift version to deploy"
  type        = string
  default     = "4.14"
}

variable "compute_machine_type" {
  description = "EC2 instance type for compute nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "compute_nodes" {
  description = "Number of compute nodes"
  type        = number
  default     = 3
}

variable "machine_cidr" {
  description = "CIDR block for machines"
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = "172.30.0.0/16"
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.128.0.0/14"
}

variable "host_prefix" {
  description = "Host prefix for pod CIDR"
  type        = number
  default     = 23
}

variable "subnet_ids" {
  description = "List of subnet IDs to use for the cluster"
  type        = list(string)
}

variable "multi_az" {
  description = "Deploy cluster across multiple availability zones"
  type        = bool
  default     = true
}

variable "rosa_creator_arn" {
  description = "ARN of the IAM user/role creating the cluster"
  type        = string
}

variable "disable_workload_monitoring" {
  description = "Disable workload monitoring to reduce costs"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"
}

variable "create_admin_user" {
  description = "Create an admin user for the cluster"
  type        = bool
  default     = true
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "cluster-admin"
}

variable "admin_password" {
  description = "Admin password"
  type        = string
  sensitive   = true
}

variable "enable_gpu_nodes" {
  description = "Enable GPU nodes for AI/ML workloads"
  type        = bool
  default     = false
}

variable "gpu_machine_type" {
  description = "EC2 instance type for GPU nodes"
  type        = string
  default     = "g4dn.xlarge"
}

variable "gpu_node_count" {
  description = "Number of GPU nodes"
  type        = number
  default     = 2
}

variable "gpu_autoscaling_enabled" {
  description = "Enable autoscaling for GPU nodes"
  type        = bool
  default     = false
}

variable "gpu_min_replicas" {
  description = "Minimum number of GPU nodes when autoscaling"
  type        = number
  default     = 1
}

variable "gpu_max_replicas" {
  description = "Maximum number of GPU nodes when autoscaling"
  type        = number
  default     = 5
}

variable "enable_gitops" {
  description = "Enable OpenShift GitOps (ArgoCD)"
  type        = bool
  default     = false
}

variable "account_role_prefix" {
  description = "Prefix for account roles"
  type        = string
  default     = "ManagedOpenShift"
}

variable "enable_autoscaling" {
  description = "Enable cluster autoscaling"
  type        = bool
  default     = false
}

variable "max_nodes_total" {
  description = "Maximum total nodes in the cluster"
  type        = number
  default     = 10
}

variable "min_cores" {
  description = "Minimum total cores"
  type        = number
  default     = 8
}

variable "max_cores" {
  description = "Maximum total cores"
  type        = number
  default     = 100
}

variable "min_memory_gb" {
  description = "Minimum total memory in GB"
  type        = number
  default     = 32
}

variable "max_memory_gb" {
  description = "Maximum total memory in GB"
  type        = number
  default     = 400
}

# Made with Bob