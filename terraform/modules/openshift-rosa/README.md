# OpenShift on AWS (ROSA) Terraform Module

This module demonstrates Terraform's capability to provision Red Hat OpenShift Service on AWS (ROSA) clusters. It showcases infrastructure-as-code for OpenShift deployment alongside traditional cloud resources.

## Purpose

This module is included in the demo to illustrate:
- **Multi-cloud provisioning** - Same Terraform patterns for AWS infrastructure AND OpenShift clusters
- **AI-ready infrastructure** - GPU node pools for machine learning workloads
- **Enterprise features** - Multi-AZ, autoscaling, GitOps integration
- **Unified automation** - One workflow for all infrastructure types

## Features

### Core Cluster
- ✅ ROSA Classic cluster deployment
- ✅ Multi-AZ support for high availability
- ✅ Custom networking (VPC, subnets, CIDR blocks)
- ✅ Integration with existing VPC module
- ✅ Configurable OpenShift version

### AI/ML Capabilities
- ✅ GPU node pools (g4dn, p3, p4d instances)
- ✅ Taints and labels for GPU workloads
- ✅ Autoscaling for GPU nodes
- ✅ Optimized for AI/ML frameworks

### Enterprise Features
- ✅ Cluster autoscaler with resource limits
- ✅ OpenShift GitOps (ArgoCD) integration
- ✅ Identity provider configuration
- ✅ Admin user creation
- ✅ Comprehensive tagging

## Usage

### Basic Cluster

```hcl
module "openshift_cluster" {
  source = "./modules/openshift-rosa"
  
  cluster_name    = "ai-platform-prod"
  aws_region      = "us-east-1"
  aws_account_id  = "123456789012"
  
  availability_zones = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]
  
  # Use subnets from VPC module
  subnet_ids = module.vpc.private_subnet_ids
  
  # Cluster configuration
  openshift_version    = "4.14"
  compute_machine_type = "m5.xlarge"
  compute_nodes        = 3
  multi_az             = true
  
  # Admin access
  create_admin_user = true
  admin_username    = "cluster-admin"
  admin_password    = var.openshift_admin_password
  
  # IAM
  rosa_creator_arn = data.aws_caller_identity.current.arn
  
  # Tags
  common_tags = {
    Project     = "AI-Platform"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}
```

### AI/ML Cluster with GPU Nodes

```hcl
module "ai_cluster" {
  source = "./modules/openshift-rosa"
  
  cluster_name   = "ai-ml-cluster"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  
  availability_zones = ["us-east-1a", "us-east-1b"]
  subnet_ids         = module.vpc.private_subnet_ids
  
  # Standard compute nodes
  compute_machine_type = "m5.2xlarge"
  compute_nodes        = 3
  
  # GPU nodes for AI/ML workloads
  enable_gpu_nodes  = true
  gpu_machine_type  = "g4dn.xlarge"  # NVIDIA T4 GPUs
  gpu_node_count    = 2
  
  # Autoscaling for GPU nodes
  gpu_autoscaling_enabled = true
  gpu_min_replicas        = 1
  gpu_max_replicas        = 5
  
  # Cluster autoscaling
  enable_autoscaling = true
  max_nodes_total    = 20
  max_cores          = 200
  max_memory_gb      = 800
  
  # GitOps for AI model deployment
  enable_gitops = true
  
  rosa_creator_arn = data.aws_caller_identity.current.arn
}
```

### Integration with Other Modules

```hcl
# VPC for OpenShift
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# OpenShift cluster using the VPC
module "openshift" {
  source = "./modules/openshift-rosa"
  
  cluster_name   = "demo-cluster"
  aws_region     = "us-east-1"
  aws_account_id = var.aws_account_id
  
  availability_zones = module.vpc.availability_zones
  subnet_ids         = module.vpc.private_subnet_ids
  
  # Use VPC CIDR for machine network
  machine_cidr = module.vpc.vpc_cidr
  
  rosa_creator_arn = data.aws_caller_identity.current.arn
}

# Store OpenShift credentials in Vault
resource "vault_kv_secret_v2" "openshift_creds" {
  mount = "secret"
  name  = "openshift/cluster"
  
  data_json = jsonencode({
    api_url      = module.openshift.api_url
    console_url  = module.openshift.console_url
    admin_user   = module.openshift.admin_credentials.username
    admin_pass   = module.openshift.admin_credentials.password
  })
}
```

## Requirements

### Prerequisites

1. **AWS Account** with ROSA enabled
2. **Red Hat Account** with ROSA entitlements
3. **Terraform** >= 1.5.0
4. **ROSA CLI** installed and configured
5. **AWS CLI** configured with appropriate credentials

### Provider Configuration

```hcl
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

provider "rhcs" {
  token = var.redhat_api_token
  url   = "https://api.openshift.com"
}
```

### ROSA Setup

Before using this module, you need to:

1. **Enable ROSA in your AWS account:**
```bash
rosa init
```

2. **Create ROSA account roles:**
```bash
rosa create account-roles --mode auto --yes
```

3. **Get your Red Hat API token:**
   - Visit https://console.redhat.com/openshift/token
   - Copy your offline access token

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the OpenShift cluster | string | - | yes |
| aws_region | AWS region | string | - | yes |
| aws_account_id | AWS account ID | string | - | yes |
| availability_zones | List of AZs | list(string) | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| rosa_creator_arn | IAM ARN creating cluster | string | - | yes |
| openshift_version | OpenShift version | string | "4.14" | no |
| compute_machine_type | EC2 instance type | string | "m5.xlarge" | no |
| compute_nodes | Number of compute nodes | number | 3 | no |
| multi_az | Multi-AZ deployment | bool | true | no |
| enable_gpu_nodes | Enable GPU nodes | bool | false | no |
| gpu_machine_type | GPU instance type | string | "g4dn.xlarge" | no |
| enable_autoscaling | Enable autoscaling | bool | false | no |
| enable_gitops | Enable GitOps | bool | false | no |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ROSA cluster ID |
| api_url | OpenShift API URL |
| console_url | Web console URL |
| domain | Cluster domain |
| state | Cluster state |
| admin_credentials | Admin credentials (sensitive) |
| gpu_machine_pool_id | GPU pool ID |

## Cost Considerations

ROSA pricing includes:
- **Control plane**: ~$0.03/hour per cluster
- **Worker nodes**: EC2 instance costs
- **GPU nodes**: Higher EC2 costs (g4dn.xlarge ~$0.526/hour)
- **Data transfer**: Standard AWS rates

**Estimated monthly costs:**
- Basic cluster (3 x m5.xlarge): ~$500-600/month
- AI cluster with GPUs (+ 2 x g4dn.xlarge): ~$1,200-1,400/month

## Demo Usage

This module is **commented out** in the main Terraform configuration for the demo. It's included to showcase capability without incurring costs.

To show during demo:
1. Open `terraform/modules/openshift-rosa/main.tf`
2. Explain the ROSA cluster configuration
3. Highlight GPU node pools for AI workloads
4. Show integration with VPC module
5. Demonstrate unified Terraform workflow

To actually deploy (not recommended for demo):
1. Uncomment in `terraform/main.tf`
2. Set required variables
3. Run `terraform plan` (review costs!)
4. Run `terraform apply` (takes 30-40 minutes)

## References

- [ROSA Documentation](https://docs.openshift.com/rosa/)
- [Terraform RHCS Provider](https://registry.terraform.io/providers/terraform-redhat/rhcs/latest/docs)
- [ROSA Pricing](https://aws.amazon.com/rosa/pricing/)
- [GPU Instance Types](https://aws.amazon.com/ec2/instance-types/g4/)

## Notes

- Cluster creation takes 30-40 minutes
- GPU nodes require specific instance types with NVIDIA GPUs
- Multi-AZ clusters provide high availability but cost more
- Autoscaling helps optimize costs for variable workloads
- GitOps integration enables declarative application deployment

---

**Made with Bob** - Demonstrating unified infrastructure automation across AWS and OpenShift