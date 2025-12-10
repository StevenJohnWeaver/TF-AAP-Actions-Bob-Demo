# HCP Terraform Workspace Setup Guide

This guide walks you through setting up your HCP Terraform workspace for the Red Hat + HashiCorp demo.

---

## Prerequisites

- [ ] HCP account (sign up at https://portal.cloud.hashicorp.com)
- [ ] GitHub repository access (https://github.com/StevenJohnWeaver/TF-AAP-Actions-Bob-Demo)
- [ ] AWS account with credentials
- [ ] Ansible Automation Platform instance
- [ ] HCP Vault cluster (we'll set this up in the next guide)

---

## Step 1: Create HCP Terraform Organization

### 1.1 Sign in to HCP Terraform

1. Go to https://app.terraform.io
2. Sign in with your HashiCorp Cloud Platform account
3. If you don't have an organization yet, you'll be prompted to create one

### 1.2 Create Organization (if needed)

1. Click **"Create an organization"**
2. Enter organization name: `redhat-hashicorp-demo` (or your preferred name)
3. Enter your email address
4. Click **"Create organization"**

> **Note**: If you already have an organization, you can use that instead. Just update the organization name in `terraform/main.tf`.

---

## Step 2: Create Workspace

### 2.1 Create New Workspace

1. In your HCP Terraform organization, click **"New workspace"**
2. Choose **"Version control workflow"**
3. Select **"GitHub"** as your VCS provider

### 2.2 Connect to GitHub

If this is your first time:
1. Click **"Connect to GitHub"**
2. Authorize HCP Terraform to access your GitHub account
3. Select the repositories you want to grant access to
4. Click **"Install"**

### 2.3 Choose Repository

1. Search for and select: `StevenJohnWeaver/TF-AAP-Actions-Bob-Demo`
2. Click **"Continue"**

### 2.4 Configure Workspace Settings

**Workspace Name**: `aws-infrastructure`

**Advanced Options**:
- **Terraform Working Directory**: `terraform`
- **Automatic Run Triggering**: ✅ Enabled
- **VCS branch**: `main`
- **Automatic speculative plans**: ✅ Enabled

Click **"Create workspace"**

---

## Step 3: Configure Workspace Settings

### 3.1 General Settings

1. Go to **Settings → General**
2. Configure:
   - **Execution Mode**: Remote
   - **Terraform Version**: Latest (or 1.6.0+)
   - **Apply Method**: Manual apply (for demo control)

### 3.2 Version Control Settings

1. Go to **Settings → Version Control**
2. Verify:
   - **VCS Branch**: `main`
   - **Automatic Run Triggering**: Enabled
   - **Working Directory**: `terraform`

---

## Step 4: Configure Variables

Now we'll add all the required variables. Go to **Variables** in your workspace.

### 4.1 HCP Vault Variables

#### `hcp_vault_address` (Terraform variable)
- **Key**: `hcp_vault_address`
- **Value**: `https://your-cluster.vault.hashicorp.cloud:8200`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: HCP Vault cluster address

> **Note**: You'll get this value after creating your HCP Vault cluster in the next guide.

#### `hcp_vault_namespace` (Terraform variable)
- **Key**: `hcp_vault_namespace`
- **Value**: `admin`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: HCP Vault namespace

#### `hcp_vault_token` (Terraform variable)
- **Key**: `hcp_vault_token`
- **Value**: `<your-vault-token>`
- **Category**: Terraform variable
- **Sensitive**: ✅ Yes
- **Description**: HCP Vault authentication token

> **Note**: You'll generate this token after setting up Vault.

### 4.2 Ansible Automation Platform Variables

#### `aap_host` (Terraform variable)
- **Key**: `aap_host`
- **Value**: `https://your-aap-controller.example.com`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: AAP controller URL

#### `aap_username` (Terraform variable)
- **Key**: `aap_username`
- **Value**: `admin` (or your AAP username)
- **Category**: Terraform variable
- **Sensitive**: ✅ Yes
- **Description**: AAP username

#### `aap_password` (Terraform variable)
- **Key**: `aap_password`
- **Value**: `<your-aap-password>`
- **Category**: Terraform variable
- **Sensitive**: ✅ Yes
- **Description**: AAP password

#### `eda_event_stream_name` (Terraform variable)
- **Key**: `eda_event_stream_name`
- **Value**: `terraform-infrastructure-events`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: EDA event stream name

### 4.3 AWS Configuration Variables

#### `aws_region` (Terraform variable)
- **Key**: `aws_region`
- **Value**: `us-east-1` (or your preferred region)
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: AWS region for deployment

#### `vpc_cidr` (Terraform variable)
- **Key**: `vpc_cidr`
- **Value**: `10.0.0.0/16`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: VPC CIDR block

#### `public_subnet_cidrs` (Terraform variable)
- **Key**: `public_subnet_cidrs`
- **Value**: `["10.0.1.0/24", "10.0.2.0/24"]`
- **Category**: Terraform variable
- **Sensitive**: No
- **HCL**: ✅ Yes
- **Description**: Public subnet CIDR blocks

#### `private_subnet_cidrs` (Terraform variable)
- **Key**: `private_subnet_cidrs`
- **Value**: `["10.0.10.0/24", "10.0.11.0/24"]`
- **Category**: Terraform variable
- **Sensitive**: No
- **HCL**: ✅ Yes
- **Description**: Private subnet CIDR blocks

#### `instance_count` (Terraform variable)
- **Key**: `instance_count`
- **Value**: `2`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Number of EC2 instances

#### `instance_type` (Terraform variable)
- **Key**: `instance_type`
- **Value**: `t3.medium`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: EC2 instance type

#### `ssh_key_name` (Terraform variable)
- **Key**: `ssh_key_name`
- **Value**: `<your-aws-key-pair-name>`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: AWS SSH key pair name

> **Important**: Make sure this key pair exists in your AWS account in the region you're deploying to.

#### `ssh_cidr_blocks` (Terraform variable)
- **Key**: `ssh_cidr_blocks`
- **Value**: `["0.0.0.0/0"]`
- **Category**: Terraform variable
- **Sensitive**: No
- **HCL**: ✅ Yes
- **Description**: CIDR blocks allowed for SSH access

> **Security Note**: For production, restrict this to your IP address or VPN range.

### 4.4 Ansible Configuration Variables

#### `ansible_user` (Terraform variable)
- **Key**: `ansible_user`
- **Value**: `ec2-user`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: SSH user for Ansible

#### `ansible_ssh_key_path` (Terraform variable)
- **Key**: `ansible_ssh_key_path`
- **Value**: `~/.ssh/demo-key.pem`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Path to SSH private key for Ansible

### 4.5 OpenShift Configuration Variables

#### `openshift_namespace` (Terraform variable)
- **Key**: `openshift_namespace`
- **Value**: `demo-app`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: OpenShift namespace for deployment

#### `application_name` (Terraform variable)
- **Key**: `application_name`
- **Value**: `demo-app`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Application name

#### `openshift_replicas` (Terraform variable)
- **Key**: `openshift_replicas`
- **Value**: `2`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Number of application replicas

### 4.6 General Configuration Variables

#### `environment` (Terraform variable)
- **Key**: `environment`
- **Value**: `demo`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Environment name

#### `project_name` (Terraform variable)
- **Key**: `project_name`
- **Value**: `redhat-hashicorp`
- **Category**: Terraform variable
- **Sensitive**: No
- **Description**: Project name for resource naming

### 4.7 Environment Variables (for AWS Credentials)

> **Note**: These will be provided by HCP Vault's AWS secrets engine, but you need root credentials to configure Vault.

#### `AWS_ACCESS_KEY_ID` (Environment variable)
- **Key**: `AWS_ACCESS_KEY_ID`
- **Value**: `<your-aws-access-key>`
- **Category**: Environment variable
- **Sensitive**: ✅ Yes
- **Description**: AWS access key (temporary, for Vault setup)

#### `AWS_SECRET_ACCESS_KEY` (Environment variable)
- **Key**: `AWS_SECRET_ACCESS_KEY`
- **Value**: `<your-aws-secret-key>`
- **Category**: Environment variable
- **Sensitive**: ✅ Yes
- **Description**: AWS secret key (temporary, for Vault setup)

> **Important**: These are only needed temporarily to configure Vault's AWS secrets engine. Once Vault is configured, Terraform will get dynamic credentials from Vault.

---

## Step 5: Verify Configuration

### 5.1 Check Variables

1. Go to **Variables** in your workspace
2. Verify all variables are set correctly
3. Ensure sensitive variables are marked as sensitive

### 5.2 Variable Summary

You should have approximately **20 Terraform variables** and **2 environment variables** configured.

**Required Variables Checklist**:
- [ ] HCP Vault configuration (3 variables)
- [ ] AAP configuration (4 variables)
- [ ] AWS configuration (8 variables)
- [ ] Ansible configuration (2 variables)
- [ ] OpenShift configuration (3 variables)
- [ ] General configuration (2 variables)
- [ ] AWS credentials (2 environment variables)

---

## Step 6: Test Configuration

### 6.1 Queue a Plan

1. Go to your workspace
2. Click **"Actions"** → **"Start new plan"**
3. Add a reason: "Initial configuration test"
4. Click **"Start plan"**

### 6.2 Expected Behavior

At this point, the plan will likely fail because:
- HCP Vault is not yet configured
- AAP event stream doesn't exist yet
- AWS credentials from Vault are not available

**This is expected!** We'll fix these in the next guides.

---

## Step 7: Configure Notifications (Optional)

### 7.1 Add Webhook for AAP (Later)

Once AAP is set up, you can add a notification:

1. Go to **Settings → Notifications**
2. Click **"Create a notification"**
3. Choose **"Webhook"**
4. Configure:
   - **Name**: "AAP EDA Notification"
   - **Webhook URL**: `https://your-eda-server.example.com/webhook`
   - **Triggers**: 
     - ✅ Completed
     - ✅ Errored

> **Note**: We're using the AAP provider's `eda_eventstream_post` action instead of webhooks, so this is optional.

---

## Quick Reference: Variable Values Template

Copy this template and fill in your values:

```bash
# HCP Vault
hcp_vault_address = "https://your-cluster.vault.hashicorp.cloud:8200"
hcp_vault_namespace = "admin"
hcp_vault_token = "<from-vault-setup>"

# AAP
aap_host = "https://your-aap-controller.example.com"
aap_username = "admin"
aap_password = "<your-password>"
eda_event_stream_name = "terraform-infrastructure-events"

# AWS
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
instance_count = 2
instance_type = "t3.medium"
ssh_key_name = "<your-key-name>"
ssh_cidr_blocks = ["0.0.0.0/0"]

# Ansible
ansible_user = "ec2-user"
ansible_ssh_key_path = "~/.ssh/demo-key.pem"

# OpenShift
openshift_namespace = "demo-app"
application_name = "demo-app"
openshift_replicas = 2

# General
environment = "demo"
project_name = "redhat-hashicorp"

# Environment Variables
AWS_ACCESS_KEY_ID = "<your-access-key>"
AWS_SECRET_ACCESS_KEY = "<your-secret-key>"
```

---

## Troubleshooting

### Issue: "Organization not found"

**Solution**: Update the organization name in `terraform/main.tf`:
```hcl
terraform {
  cloud {
    organization = "your-actual-org-name"  # Update this
    workspaces {
      name = "aws-infrastructure"
    }
  }
}
```

### Issue: "Workspace not found"

**Solution**: Ensure the workspace name matches exactly: `aws-infrastructure`

### Issue: "Invalid variable type"

**Solution**: For list variables like `public_subnet_cidrs`, make sure to:
1. Check the **HCL** checkbox
2. Use proper HCL syntax: `["value1", "value2"]`

### Issue: "Cannot connect to Vault"

**Solution**: This is expected until Vault is configured. Continue to the next guide.

---

## Next Steps

✅ **Completed**: HCP Terraform workspace is configured!

**Next Guide**: `02-hcp-vault-setup.md` - Set up HCP Vault cluster and configure secrets engines

---

## Additional Resources

- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [Workspace Variables](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/variables)
- [VCS Integration](https://developer.hashicorp.com/terraform/cloud-docs/vcs)