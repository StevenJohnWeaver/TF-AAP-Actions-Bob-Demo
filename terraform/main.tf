# Red Hat + HashiCorp Demo - Main Terraform Configuration
# This configuration provisions AWS infrastructure and triggers AAP via EDA event stream

terraform {
  cloud {
    organization = "redhat-hashicorp-demo"
    workspaces {
      name = "aws-infrastructure"
    }
  }
  
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
    aap = {
      source  = "ansible/aap"
      version = "~> 1.0"
    }
  }
}

# Configure AAP Provider for EDA integration
provider "aap" {
  host     = var.aap_host
  # username = var.aap_username
  # password = var.aap_password
  # Alternatively, use token authentication:
  token = var.aap_token
}

# Configure Vault Provider for HCP Vault
provider "vault" {
  address   = var.hcp_vault_address
  namespace = var.hcp_vault_namespace
  
  # Use AppRole instead of token
  auth_login {
    path = "auth/approle/login"
    
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# Fetch dynamic AWS credentials from HCP Vault
data "vault_aws_access_credentials" "creds" {
  backend = "aws"
  role    = "terraform-provisioner"
}

# Configure AWS Provider with Vault-sourced credentials
provider "aws" {
  region     = var.aws_region
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
  
  default_tags {
    tags = {
      Environment  = var.environment
      ManagedBy    = "terraform"
      Demo         = "redhat-hashicorp"
      Organization = "redhat-hashicorp-demo"
    }
  }
}

# VPC Module - Creates networking infrastructure
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block      = var.vpc_cidr
  environment     = var.environment
  project_name    = var.project_name
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs
  
  tags = {
    Component = "networking"
  }
}

# Security Module - Creates security groups
module "security" {
  source = "./modules/security"
  
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name
  
  # Allow SSH from specific CIDR (adjust as needed)
  ssh_cidr_blocks = var.ssh_cidr_blocks
  
  # Allow HTTP/HTTPS from anywhere for demo
  web_cidr_blocks = ["0.0.0.0/0"]
  
  tags = {
    Component = "security"
  }
}

# Compute Module - Creates EC2 instances
module "compute" {
  source = "./modules/compute"
  
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.ssh_key_name
  security_group_id = module.security.app_sg_id
  environment       = var.environment
  
  tags = {
    Component = "compute"
    Role      = "app-server"
  }
}

# Define action to post event to AAP EDA after infrastructure is created
action "aap_eda_eventstream_post" "infrastructure_ready" {
  config {
    limit             = "all"
    template_type     = "job"
    job_template_name = "Configure AWS Infrastructure"
    organization_name = "Default"
    event_stream_config = {
      username = var.eda_event_stream_username
      password = var.eda_event_stream_password
      url      = "${var.aap_host}/api/eda/v1/event-streams/${var.eda_event_stream_name}/post/"
    }
  }
}

# Trigger the action after compute resources are created
resource "terraform_data" "trigger_aap_action" {
  depends_on = [
    module.vpc,
    module.compute,
    module.security
  ]
  
  # Trigger on infrastructure changes
  input = {
    vpc_id       = module.vpc.vpc_id
    instance_ids = module.compute.instance_ids
  }
  
  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.aap_eda_eventstream_post.infrastructure_ready]
    }
  }
}

# Outputs for reference and validation
output "infrastructure_details" {
  value = {
    vpc_id          = module.vpc.vpc_id
    vpc_cidr        = module.vpc.vpc_cidr
    instance_ids    = module.compute.instance_ids
    private_ips     = module.compute.private_ips
    public_ips      = module.compute.public_ips
    security_groups = module.security.security_group_ids
  }
  description = "Infrastructure details"
}

output "ansible_inventory" {
  value = {
    for idx, id in module.compute.instance_ids :
    "app-server-${idx + 1}" => {
      instance_id = id
      private_ip  = module.compute.private_ips[idx]
      public_ip   = module.compute.public_ips[idx]
    }
  }
  description = "Ansible inventory structure"
}

output "eda_event_posted" {
  value = {
    event_stream = var.eda_event_stream_name
    timestamp    = timestamp()
    status       = "Action configured to post to AAP EDA"
  }
  description = "EDA event posting confirmation"
  depends_on  = [terraform_data.trigger_aap_action]
}

output "deployment_info" {
  value = {
    terraform_run_id    = var.terraform_run_id
    aws_region          = var.aws_region
    environment         = var.environment
    openshift_namespace = var.openshift_namespace
    application_name    = var.application_name
  }
  description = "Deployment metadata"

# ============================================================================
# OpenShift Cluster Module (COMMENTED OUT FOR DEMO)
# ============================================================================
# This module demonstrates Terraform's capability to provision OpenShift clusters
# alongside traditional cloud infrastructure. Uncomment to actually deploy ROSA.
#
# NOTE: Deploying ROSA incurs significant costs (~$500-1400/month)
# For demo purposes, this is shown but not executed.
# ============================================================================

/*
module "openshift_cluster" {
  source = "./modules/openshift-rosa"
  
  # Cluster identification
  cluster_name   = "${var.project_name}-openshift-${var.environment}"
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  
  # Use the VPC and subnets created above
  availability_zones = var.availability_zones
  subnet_ids         = module.vpc.private_subnet_ids
  
  # Networking - align with VPC module
  machine_cidr = module.vpc.vpc_cidr
  service_cidr = "172.30.0.0/16"
  pod_cidr     = "10.128.0.0/14"
  host_prefix  = 23
  
  # Cluster configuration
  openshift_version    = "4.14"
  compute_machine_type = "m5.xlarge"
  compute_nodes        = 3
  multi_az             = true
  
  # AI/ML capabilities - GPU nodes for AI workloads
  enable_gpu_nodes         = true
  gpu_machine_type         = "g4dn.xlarge"  # NVIDIA T4 GPUs
  gpu_node_count           = 2
  gpu_autoscaling_enabled  = true
  gpu_min_replicas         = 1
  gpu_max_replicas         = 5
  
  # Cluster autoscaling
  enable_autoscaling = true
  max_nodes_total    = 10
  max_cores          = 100
  max_memory_gb      = 400
  
  # GitOps for application deployment
  enable_gitops        = true
  account_role_prefix  = "ManagedOpenShift"
  
  # Admin access
  create_admin_user = true
  admin_username    = "cluster-admin"
  admin_password    = var.openshift_admin_password  # Store in Vault!
  
  # IAM
  rosa_creator_arn = data.aws_caller_identity.current.arn
  
  # Cost optimization
  disable_workload_monitoring = false  # Enable for production
  
  # Tags
  common_tags = local.common_tags
  environment = var.environment
  
  # Dependencies - ensure VPC is created first
  depends_on = [module.vpc]
}

# Store OpenShift credentials in Vault
resource "vault_kv_secret_v2" "openshift_cluster" {
  mount = "secret"
  name  = "openshift/cluster"
  
  data_json = jsonencode({
    cluster_id   = module.openshift_cluster.cluster_id
    cluster_name = module.openshift_cluster.cluster_name
    api_url      = module.openshift_cluster.api_url
    console_url  = module.openshift_cluster.console_url
    domain       = module.openshift_cluster.domain
    region       = var.aws_region
    admin_user   = module.openshift_cluster.admin_credentials.username
    admin_pass   = module.openshift_cluster.admin_credentials.password
  })
  
  depends_on = [module.openshift_cluster]
}

# Output OpenShift cluster information
output "openshift_cluster_info" {
  description = "OpenShift cluster details"
  value = {
    cluster_id  = module.openshift_cluster.cluster_id
    api_url     = module.openshift_cluster.api_url
    console_url = module.openshift_cluster.console_url
    state       = module.openshift_cluster.state
  }
}
*/

# ============================================================================
# Demo Notes for OpenShift Module
# ============================================================================
# During the demo, you can:
# 1. Show this commented code to illustrate unified provisioning
# 2. Explain how the same Terraform patterns work for:
#    - AWS infrastructure (VPC, EC2, Security Groups)
#    - OpenShift clusters (ROSA)
#    - Multi-cloud environments (Azure, GCP with similar modules)
# 3. Highlight AI-ready features:
#    - GPU node pools for machine learning
#    - Autoscaling for variable workloads
#    - GitOps integration for application deployment
# 4. Emphasize cost control:
#    - Infrastructure as code enables easy cleanup
#    - Autoscaling optimizes resource usage
#    - Vault manages credentials across all platforms
# ============================================================================
}
