# Outputs for OpenShift on AWS (ROSA) Module

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

output "version" {
  description = "The OpenShift version of the cluster"
  value       = rhcs_cluster_rosa_classic.openshift_cluster.version
}

output "admin_credentials" {
  description = "Admin credentials for the cluster (sensitive)"
  value = var.create_admin_user ? {
    username = var.admin_username
    password = nonsensitive(rhcs_cluster_rosa_classic_admin_credentials.admin_creds[0].password)
  } : null
  sensitive = true
}

output "gpu_machine_pool_id" {
  description = "ID of the GPU machine pool for AI/ML workloads"
  value       = var.enable_gpu_nodes ? rhcs_machine_pool.gpu_pool[0].id : null
}

output "cluster_details" {
  description = "Comprehensive cluster details"
  value = {
    id           = rhcs_cluster_rosa_classic.openshift_cluster.id
    name         = rhcs_cluster_rosa_classic.openshift_cluster.name
    api_url      = rhcs_cluster_rosa_classic.openshift_cluster.api_url
    console_url  = rhcs_cluster_rosa_classic.openshift_cluster.console_url
    domain       = rhcs_cluster_rosa_classic.openshift_cluster.domain
    state        = rhcs_cluster_rosa_classic.openshift_cluster.state
    version      = rhcs_cluster_rosa_classic.openshift_cluster.version
    region       = var.aws_region
    multi_az     = var.multi_az
    compute_nodes = var.compute_nodes
    gpu_enabled  = var.enable_gpu_nodes
  }
}

# Made with Bob