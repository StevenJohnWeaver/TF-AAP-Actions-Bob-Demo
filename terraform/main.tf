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
  username = var.aap_username
  password = var.aap_password
  # Alternatively, use token authentication:
  # token = var.aap_token
}

# Configure Vault Provider for HCP Vault
provider "vault" {
  address   = var.hcp_vault_address
  namespace = var.hcp_vault_namespace
  token     = var.hcp_vault_token
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
      username = var.aap_username
      password = var.aap_password
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
}
