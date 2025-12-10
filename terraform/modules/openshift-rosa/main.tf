# OpenShift on AWS (ROSA) Module
# This module demonstrates Terraform's ability to provision OpenShift clusters
# Commented out in main.tf for demo purposes, but shows the capability

terraform {
  required_providers {
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = ">= 1.6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ROSA Cluster
resource "rhcs_cluster_rosa_classic" "openshift_cluster" {
  name               = var.cluster_name
  cloud_region       = var.aws_region
  aws_account_id     = var.aws_account_id
  availability_zones = var.availability_zones
  
  # Cluster configuration
  version            = var.openshift_version
  compute_machine_type = var.compute_machine_type
  replicas           = var.compute_nodes
  
  # Networking
  machine_cidr       = var.machine_cidr
  service_cidr       = var.service_cidr
  pod_cidr           = var.pod_cidr
  host_prefix        = var.host_prefix
  
  # Use existing VPC (from our VPC module)
  aws_subnet_ids     = var.subnet_ids
  
  # Multi-AZ for production
  multi_az           = var.multi_az
  
  # Properties
  properties = {
    rosa_creator_arn = var.rosa_creator_arn
  }
  
  # Disable workload monitoring for cost savings in demo
  disable_workload_monitoring = var.disable_workload_monitoring
  
  # Tags
  tags = merge(
    var.common_tags,
    {
      "Name"        = var.cluster_name
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
      "Purpose"     = "AI-Ready-Infrastructure"
    }
  )
  
  # Wait for cluster to be ready
  wait_for_create_complete = true
  
  lifecycle {
    ignore_changes = [
      # Ignore changes to availability_zones as they can't be modified
      availability_zones,
    ]
  }
}

# Identity Provider (optional - for demo purposes)
resource "rhcs_identity_provider" "htpasswd_idp" {
  count = var.create_admin_user ? 1 : 0
  
  cluster = rhcs_cluster_rosa_classic.openshift_cluster.id
  name    = "htpasswd-demo"
  
  htpasswd = {
    users = [
      {
        username = var.admin_username
        password = var.admin_password
      }
    ]
  }
}

# Cluster Admin User
resource "rhcs_cluster_rosa_classic_admin_credentials" "admin_creds" {
  count = var.create_admin_user ? 1 : 0
  
  cluster = rhcs_cluster_rosa_classic.openshift_cluster.id
  
  depends_on = [rhcs_identity_provider.htpasswd_idp]
}

# Machine Pool for GPU nodes (AI workloads)
resource "rhcs_machine_pool" "gpu_pool" {
  count = var.enable_gpu_nodes ? 1 : 0
  
  cluster      = rhcs_cluster_rosa_classic.openshift_cluster.id
  name         = "gpu-workers"
  machine_type = var.gpu_machine_type
  replicas     = var.gpu_node_count
  
  labels = {
    "node-role.kubernetes.io/gpu" = ""
    "workload"                     = "ai-ml"
  }
  
  taints = [
    {
      key    = "nvidia.com/gpu"
      value  = "true"
      effect = "NoSchedule"
    }
  ]
  
  autoscaling = {
    enabled = var.gpu_autoscaling_enabled
    min_replicas = var.gpu_autoscaling_enabled ? var.gpu_min_replicas : null
    max_replicas = var.gpu_autoscaling_enabled ? var.gpu_max_replicas : null
  }
}

# OpenShift GitOps (ArgoCD) Operator
resource "rhcs_rosa_operator_roles" "gitops_operator" {
  count = var.enable_gitops ? 1 : 0
  
  cluster          = rhcs_cluster_rosa_classic.openshift_cluster.id
  operator_role_prefix = "${var.cluster_name}-gitops"
  
  account_role_prefix = var.account_role_prefix
}

# Cluster Autoscaler
resource "rhcs_cluster_autoscaler" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0
  
  cluster = rhcs_cluster_rosa_classic.openshift_cluster.id
  
  autoscaler = {
    balance_similar_node_groups      = true
    skip_nodes_with_local_storage    = true
    log_verbosity                    = 1
    max_pod_grace_period             = 600
    pod_priority_threshold           = -10
    ignore_daemonsets_utilization    = true
    max_node_provision_time          = "15m"
    balancing_ignored_labels         = ["topology.kubernetes.io/zone"]
    
    resource_limits = {
      max_nodes_total = var.max_nodes_total
      cores = {
        min = var.min_cores
        max = var.max_cores
      }
      memory = {
        min = var.min_memory_gb
        max = var.max_memory_gb
      }
    }
    
    scale_down = {
      enabled               = true
      delay_after_add       = "10m"
      delay_after_delete    = "10s"
      delay_after_failure   = "3m"
      unneeded_time         = "10m"
      utilization_threshold = "0.5"
    }
  }
}

# Outputs for integration with other modules
output "cluster_id" {
  description = "The ID of the ROSA cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.id
}

output "cluster_name" {
  description = "The name of the ROSA cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.name
}

output "api_url" {
  description = "The API URL of the OpenShift cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.api_url
}

output "console_url" {
  description = "The console URL of the OpenShift cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.console_url
}

output "domain" {
  description = "The domain of the OpenShift cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.domain
}

output "state" {
  description = "The state of the OpenShift cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.state
}

output "admin_credentials" {
  description = "Admin credentials for the cluster"
  value = var.create_admin_user ? {
    username = var.admin_username
    password = nonsensitive(rhcs_cluster_rosa_classic_admin_credentials.admin_creds[0].password)
  } : null
  sensitive = true
}

output "gpu_machine_pool_id" {
  description = "ID of the GPU machine pool"
  value       = var.enable_gpu_nodes ? rhcs_machine_pool.gpu_pool[0].id : null
}

# Made with Bob