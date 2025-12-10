# Ansible Automation Platform (AAP) Setup Guide

This guide walks you through configuring Ansible Automation Platform to receive events from Terraform and execute automation workflows.

---

## Prerequisites

- [ ] AAP 2.4+ installed and accessible
- [ ] Admin access to AAP Controller
- [ ] Admin access to EDA Controller
- [ ] HCP Vault configured (from previous guide)
- [ ] GitHub repository access

---

## Overview

We'll configure:
1. **EDA Event Stream** - Receives events from Terraform
2. **EDA Rulebook** - Processes events and triggers jobs
3. **AAP Projects** - Contains playbooks and roles
4. **AAP Credentials** - HCP Vault integration
5. **AAP Inventories** - Dynamic AWS inventory
6. **AAP Job Templates** - Automation workflows

---

## Step 1: Create EDA Event Stream

### 1.1 Access EDA Controller

1. Log in to your AAP instance
2. Navigate to **Event-Driven Ansible** (EDA Controller)
3. Or access directly: `https://your-aap-host/eda`

### 1.2 Create Event Stream

1. Go to **Event Streams**
2. Click **"Create event stream"**
3. Configure:

**Name**: `terraform-infrastructure-events`

**Description**: `Event stream for Terraform infrastructure provisioning events`

**Organization**: `Default` (or your organization)

**Event Stream Type**: `Generic`

**Enabled**: ✅ Yes

4. Click **"Create event stream"**

### 1.3 Note Event Stream Details

After creation, note:
- **Event Stream Name**: `terraform-infrastructure-events`
- **Event Stream ID**: (shown in URL or details)

> **Important**: This name must match the `eda_event_stream_name` variable in HCP Terraform.

---

## Step 2: Create AAP Project

### 2.1 Create Project from GitHub

1. Go to **Automation Controller** → **Projects**
2. Click **"Add"**
3. Configure:

**Name**: `Red Hat HashiCorp Demo`

**Description**: `Demo project for Red Hat + HashiCorp integration`

**Organization**: `Default`

**Source Control Type**: `Git`

**Source Control URL**: `https://github.com/StevenJohnWeaver/TF-AAP-Actions-Bob-Demo.git`

**Source Control Branch/Tag/Commit**: `main`

**Options**:
- ✅ Update Revision on Launch
- ✅ Clean
- ✅ Delete

4. Click **"Save"**

### 2.2 Sync Project

1. Click the **sync icon** next to your project
2. Wait for sync to complete (should show green checkmark)
3. Verify playbooks are available:
   - `playbooks/configure-infrastructure.yml`
   - `playbooks/deploy-to-openshift.yml`

---

## Step 3: Create HCP Vault Credential Type

### 3.1 Create Custom Credential Type

1. Go to **Credential Types**
2. Click **"Add"**
3. Configure:

**Name**: `HCP Vault AppRole`

**Description**: `Credential type for HCP Vault AppRole authentication`

**Input Configuration**:
```yaml
fields:
  - id: vault_addr
    type: string
    label: HCP Vault Address
    help_text: "HCP Vault cluster URL (e.g., https://your-cluster.vault.hashicorp.cloud:8200)"
  - id: vault_namespace
    type: string
    label: HCP Vault Namespace
    default: admin
  - id: role_id
    type: string
    label: AppRole Role ID
    secret: true
  - id: secret_id
    type: string
    label: AppRole Secret ID
    secret: true
required:
  - vault_addr
  - role_id
  - secret_id
```

**Injector Configuration**:
```yaml
env:
  VAULT_ADDR: '{{ vault_addr }}'
  VAULT_NAMESPACE: '{{ vault_namespace }}'
  VAULT_ROLE_ID: '{{ role_id }}'
  VAULT_SECRET_ID: '{{ secret_id }}'
```

4. Click **"Save"**

---

## Step 4: Create HCP Vault Credential

### 4.1 Create Credential

1. Go to **Credentials**
2. Click **"Add"**
3. Configure:

**Name**: `HCP Vault - Demo`

**Description**: `HCP Vault credentials for demo`

**Organization**: `Default`

**Credential Type**: `HCP Vault AppRole` (the one you just created)

**HCP Vault Address**: `https://your-cluster.vault.hashicorp.cloud:8200`

**HCP Vault Namespace**: `admin`

**AppRole Role ID**: `<from Vault setup script output>`

**AppRole Secret ID**: `<from Vault setup script output>`

4. Click **"Save"**

> **Note**: You got these values when you ran `vault/scripts/setup-hcp-vault.sh`

---

## Step 5: Create AWS Dynamic Inventory

### 5.1 Create Inventory

1. Go to **Inventories**
2. Click **"Add"** → **"Add inventory"**
3. Configure:

**Name**: `AWS Dynamic Inventory`

**Description**: `Dynamic inventory for AWS EC2 instances`

**Organization**: `Default`

4. Click **"Save"**

### 5.2 Add Inventory Source

1. In your new inventory, go to **Sources** tab
2. Click **"Add"**
3. Configure:

**Name**: `AWS EC2 Source`

**Description**: `Dynamic EC2 inventory source`

**Source**: `Amazon EC2`

**Credential**: (Create new AWS credential or use existing)

**Regions**: `us-east-1` (or your region)

**Instance Filters**: `tag:ManagedBy=terraform`

**Options**:
- ✅ Overwrite
- ✅ Update on launch

**Update Options**:
- ✅ Update on project update

4. Click **"Save"**

### 5.3 Sync Inventory

1. Click the **sync icon** next to your inventory source
2. Wait for sync to complete

> **Note**: This will be empty until Terraform creates instances.

---

## Step 6: Create Job Templates

### 6.1 Create "Configure AWS Infrastructure" Job Template

1. Go to **Templates**
2. Click **"Add"** → **"Add job template"**
3. Configure:

**Name**: `Configure AWS Infrastructure`

**Description**: `Configure EC2 instances provisioned by Terraform`

**Job Type**: `Run`

**Inventory**: `AWS Dynamic Inventory`

**Project**: `Red Hat HashiCorp Demo`

**Playbook**: `playbooks/configure-infrastructure.yml`

**Credentials**:
- Add: `HCP Vault - Demo`
- Add: Your SSH credential (for EC2 access)

**Variables** (leave empty - will be provided by EDA):
```yaml
# Variables will be passed from EDA rulebook:
# - terraform_workspace
# - terraform_run_id
# - vpc_id
# - instances
# - etc.
```

**Options**:
- ✅ Enable Privilege Escalation
- ✅ Enable Fact Storage

**Verbosity**: `1 (Verbose)`

4. Click **"Save"**

### 6.2 Create "Deploy to OpenShift" Job Template

1. Click **"Add"** → **"Add job template"**
2. Configure:

**Name**: `Deploy to OpenShift`

**Description**: `Deploy application to OpenShift`

**Job Type**: `Run`

**Inventory**: `AWS Dynamic Inventory` (or create localhost inventory)

**Project**: `Red Hat HashiCorp Demo`

**Playbook**: `playbooks/deploy-to-openshift.yml`

**Credentials**:
- Add: `HCP Vault - Demo`

**Variables** (leave empty - will be provided by previous job):
```yaml
# Variables will be passed from configure-infrastructure playbook:
# - terraform_run_id
# - vpc_id
# - instances
# - openshift_namespace
# - etc.
```

**Options**:
- ✅ Enable Fact Storage

**Verbosity**: `1 (Verbose)`

3. Click **"Save"**

---

## Step 7: Import EDA Rulebook

### 7.1 Create EDA Project

1. Go to **Event-Driven Ansible** → **Projects**
2. Click **"Create project"**
3. Configure:

**Name**: `Red Hat HashiCorp Demo - EDA`

**Description**: `EDA rulebooks for Terraform integration`

**Source Control Type**: `Git`

**Source Control URL**: `https://github.com/StevenJohnWeaver/TF-AAP-Actions-Bob-Demo.git`

**Source Control Branch**: `main`

4. Click **"Create project"**

### 7.2 Sync EDA Project

1. Click the **sync icon**
2. Wait for sync to complete
3. Verify rulebook is available:
   - `extensions/eda/rulebooks/terraform-infrastructure-trigger.yml`

---

## Step 8: Create EDA Rulebook Activation

### 8.1 Create Activation

1. Go to **Event-Driven Ansible** → **Rulebook Activations**
2. Click **"Create rulebook activation"**
3. Configure:

**Name**: `Terraform Infrastructure Handler`

**Description**: `Process Terraform infrastructure provisioning events`

**Project**: `Red Hat HashiCorp Demo - EDA`

**Rulebook**: `extensions/eda/rulebooks/terraform-infrastructure-trigger.yml`

**Decision Environment**: `Default Decision Environment`

**Restart Policy**: `On failure`

**Rulebook Activation Enabled**: ✅ Yes

**Event Streams**:
- Add: `terraform-infrastructure-events`

**Credentials**:
- Add: `HCP Vault - Demo`

**Extra Variables**:
```yaml
# Optional: Override default values
webhook_token: "your-webhook-token"
```

4. Click **"Create rulebook activation"**

### 8.2 Verify Activation

1. Check that activation status is **"Running"**
2. Click on the activation to view logs
3. You should see: "Listening to Terraform event stream"

---

## Step 9: Configure AAP Controller Token (for EDA)

### 9.1 Create Personal Access Token

1. Go to **Users** → Click your username
2. Go to **Tokens** tab
3. Click **"Add"**
4. Configure:

**Application**: `Event-Driven Ansible`

**Description**: `Token for EDA to trigger job templates`

**Scope**: `Write`

5. Click **"Save"**
6. **Copy the token** (you won't see it again!)

### 9.2 Add Token to EDA Activation

1. Go back to your EDA activation
2. Edit the activation
3. Add to **Extra Variables**:
```yaml
aap_controller_token: "your-token-here"
```

4. Save and restart the activation

---

## Step 10: Test the Integration

### 10.1 Manual Event Test

You can test the event stream manually:

```bash
# Get your AAP token
AAP_TOKEN="your-aap-token"

# Post a test event
curl -X POST https://your-aap-host/api/eda/v1/event-streams/terraform-infrastructure-events/post/ \
  -H "Authorization: Bearer $AAP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "terraform",
    "event_type": "infrastructure_provisioned",
    "timestamp": "2024-12-09T22:00:00Z",
    "terraform": {
      "workspace": "aws-infrastructure",
      "organization": "redhat-hashicorp-demo",
      "run_id": "test-run-123"
    },
    "infrastructure": {
      "vpc": {
        "id": "vpc-test123",
        "cidr": "10.0.0.0/16"
      },
      "instances": [
        {
          "id": "i-test123",
          "name": "app-server-1",
          "private_ip": "10.0.1.10",
          "public_ip": "54.1.2.3",
          "role": "app-server"
        }
      ],
      "region": "us-east-1",
      "environment": "demo"
    },
    "ansible_inventory": {
      "all": {
        "hosts": {
          "app-server-1": {
            "ansible_host": "10.0.1.10",
            "instance_id": "i-test123",
            "public_ip": "54.1.2.3",
            "ansible_user": "ec2-user"
          }
        }
      }
    },
    "deployment": {
      "openshift_namespace": "demo-app",
      "application_name": "demo-app",
      "replicas": 2
    },
    "vault": {
      "address": "https://your-cluster.vault.hashicorp.cloud:8200",
      "namespace": "admin"
    }
  }'
```

### 10.2 Verify Event Processing

1. Go to **Event-Driven Ansible** → **Rulebook Activations**
2. Click on your activation
3. Check **History** tab for event processing
4. Verify job template was triggered
5. Check **Jobs** in Automation Controller for job execution

---

## Step 11: Configure Ansible Collections

### 11.1 Required Collections

Ensure these collections are installed in your execution environment:

```yaml
collections:
  - name: ansible.eda
    version: ">=1.0.0"
  - name: awx.awx
    version: ">=23.0.0"
  - name: kubernetes.core
    version: ">=2.4.0"
  - name: community.hashi_vault
    version: ">=5.0.0"
  - name: amazon.aws
    version: ">=6.0.0"
```

### 11.2 Verify Collections

```bash
# SSH to AAP execution environment or use ansible-navigator
ansible-galaxy collection list
```

If collections are missing, install them:

```bash
ansible-galaxy collection install ansible.eda awx.awx kubernetes.core community.hashi_vault amazon.aws
```

---

## Configuration Summary

### ✅ Checklist

- [ ] EDA event stream created: `terraform-infrastructure-events`
- [ ] AAP project synced from GitHub
- [ ] HCP Vault credential type created
- [ ] HCP Vault credential configured
- [ ] AWS dynamic inventory created
- [ ] Job template: "Configure AWS Infrastructure"
- [ ] Job template: "Deploy to OpenShift"
- [ ] EDA project synced
- [ ] EDA rulebook activation running
- [ ] AAP controller token configured
- [ ] Required Ansible collections installed
- [ ] Manual test event successful

### 📋 Important Values

Record these for reference:

```yaml
# AAP Configuration
aap_host: "https://your-aap-controller.example.com"
aap_username: "admin"
eda_event_stream_name: "terraform-infrastructure-events"

# HCP Vault Credentials (in AAP)
vault_addr: "https://your-cluster.vault.hashicorp.cloud:8200"
vault_namespace: "admin"
vault_role_id: "<from-vault-setup>"
vault_secret_id: "<from-vault-setup>"

# Job Templates
configure_infrastructure_template: "Configure AWS Infrastructure"
deploy_openshift_template: "Deploy to OpenShift"

# EDA Activation
rulebook_activation: "Terraform Infrastructure Handler"
```

---

## Troubleshooting

### Issue: EDA activation not starting

**Symptoms**: Activation shows "Pending" or "Failed"

**Solutions**:
1. Check EDA controller logs:
   ```bash
   kubectl logs -n aap deployment/eda-controller
   ```
2. Verify event stream exists and is enabled
3. Check rulebook syntax:
   ```bash
   ansible-rulebook --rulebook extensions/eda/rulebooks/terraform-infrastructure-trigger.yml --check
   ```

### Issue: Job template not triggered

**Symptoms**: Event received but no job starts

**Solutions**:
1. Check EDA activation logs for errors
2. Verify job template name matches exactly in rulebook
3. Check AAP controller token has correct permissions
4. Verify credentials are attached to job template

### Issue: Vault authentication fails

**Symptoms**: Job fails with "Unable to authenticate to Vault"

**Solutions**:
1. Verify Vault credentials in AAP:
   ```bash
   # Test from AAP execution environment
   export VAULT_ADDR="https://your-cluster.vault.hashicorp.cloud:8200"
   export VAULT_NAMESPACE="admin"
   vault login -method=approle role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID
   ```
2. Check AppRole is still valid in Vault
3. Regenerate Secret ID if expired:
   ```bash
   vault write -f auth/approle/role/ansible/secret-id
   ```

### Issue: Dynamic inventory empty

**Symptoms**: No hosts found in inventory

**Solutions**:
1. Verify AWS credentials are configured
2. Check instance filters match Terraform tags
3. Manually sync inventory source
4. Verify instances exist in AWS with correct tags

### Issue: Playbook fails with "Module not found"

**Symptoms**: Task fails with import error

**Solutions**:
1. Verify required collections are installed
2. Check execution environment has all dependencies
3. Update collections:
   ```bash
   ansible-galaxy collection install -r requirements.yml --force
   ```

---

## Testing Checklist

Before running the full demo:

- [ ] EDA activation is running
- [ ] Manual test event triggers job successfully
- [ ] Job can authenticate to Vault
- [ ] Job can fetch secrets from Vault
- [ ] Dynamic inventory syncs successfully
- [ ] SSH access to EC2 instances works (after Terraform creates them)
- [ ] OpenShift is accessible from AAP

---

## Next Steps

✅ **Completed**: AAP is configured and ready!

**Next Guide**: `04-openshift-setup.md` - Set up OpenShift Local (CRC)

---

## Additional Resources

- [AAP Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform)
- [Event-Driven Ansible](https://www.ansible.com/products/event-driven-ansible)
- [Ansible Vault Integration](https://docs.ansible.com/ansible/latest/collections/community/hashi_vault/)
- [Dynamic Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html)