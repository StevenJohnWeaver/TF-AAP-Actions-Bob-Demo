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

# Post infrastructure provisioning event to AAP EDA
resource "aap_eda_eventstream_post" "infrastructure_ready" {
  # Ensure all infrastructure is created before posting event
  depends_on = [
    module.vpc,
    module.compute,
    module.security
  ]
  
  # Name of the EDA event stream (must exist in AAP)
  event_stream_name = var.eda_event_stream_name
  
  # Event payload - this is what the EDA rulebook will receive
  event = jsonencode({
    # Event metadata
    source      = "terraform"
    event_type  = "infrastructure_provisioned"
    timestamp   = timestamp()
    
    # Terraform context
    terraform = {
      workspace    = "aws-infrastructure"
      organization = "redhat-hashicorp-demo"
      run_id       = var.terraform_run_id
    }
    
    # Infrastructure details
    infrastructure = {
      # VPC information
      vpc = {
        id   = module.vpc.vpc_id
        cidr = module.vpc.vpc_cidr
        public_subnets = [
          for subnet in module.vpc.public_subnet_ids : {
            id   = subnet
            cidr = module.vpc.public_subnet_cidrs[index(module.vpc.public_subnet_ids, subnet)]
          }
        ]
        private_subnets = [
          for subnet in module.vpc.private_subnet_ids : {
            id   = subnet
            cidr = module.vpc.private_subnet_cidrs[index(module.vpc.private_subnet_ids, subnet)]
          }
        ]
      }
      
      # EC2 instances
      instances = [
        for idx, id in module.compute.instance_ids : {
          id         = id
          name       = "app-server-${idx + 1}"
          private_ip = module.compute.private_ips[idx]
          public_ip  = module.compute.public_ips[idx]
          role       = "app-server"
          subnet_id  = module.compute.subnet_ids[idx]
        }
      ]
      
      # Security groups
      security_groups = {
        app_sg_id = module.security.app_sg_id
        web_sg_id = module.security.web_sg_id
      }
      
      # AWS metadata
      region      = var.aws_region
      environment = var.environment
    }
    
    # Ansible inventory structure for AAP
    ansible_inventory = {
      all = {
        hosts = {
          for idx, id in module.compute.instance_ids :
          "app-server-${idx + 1}" => {
            ansible_host = module.compute.private_ips[idx]
            instance_id  = id
            public_ip    = module.compute.public_ips[idx]
            ansible_user = var.ansible_user
          }
        }
        vars = {
          ansible_ssh_private_key_file = var.ansible_ssh_key_path
          aws_region                   = var.aws_region
          vpc_id                       = module.vpc.vpc_id
          environment                  = var.environment
        }
      }
      children = {
        app_servers = {
          hosts = [
            for idx in range(length(module.compute.instance_ids)) :
            "app-server-${idx + 1}"
          ]
        }
        aws_ec2 = {
          hosts = [
            for idx in range(length(module.compute.instance_ids)) :
            "app-server-${idx + 1}"
          ]
        }
      }
    }
    
    # OpenShift deployment configuration
    deployment = {
      openshift_namespace = var.openshift_namespace
      application_name    = var.application_name
      replicas           = var.openshift_replicas
    }
    
    # HCP Vault configuration for AAP
    vault = {
      address   = var.hcp_vault_address
      namespace = var.hcp_vault_namespace
    }
  })
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
    status       = "Event posted to AAP EDA successfully"
  }
  description = "EDA event posting confirmation"
  depends_on  = [aap_eda_eventstream_post.infrastructure_ready]
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
