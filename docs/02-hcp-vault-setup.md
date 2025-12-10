# HCP Vault Setup Guide

This guide walks you through creating and configuring your HCP Vault cluster for the Red Hat + HashiCorp demo.

---

## Prerequisites

- [ ] HashiCorp Cloud Platform (HCP) account
- [ ] AWS account with admin credentials
- [ ] Vault CLI installed locally
- [ ] Access to terminal/command line

---

## Overview

We'll configure:
1. **HCP Vault Cluster** - Managed Vault instance
2. **AWS Secrets Engine** - Dynamic AWS credentials
3. **KV Secrets Engine** - Application secrets
4. **AppRole Authentication** - For Ansible
5. **Policies** - Access control
6. **Tokens** - For Terraform and testing

---

## Step 1: Create HCP Vault Cluster

### 1.1 Access HCP Portal

1. Go to https://portal.cloud.hashicorp.com
2. Sign in with your HashiCorp account
3. Navigate to **Vault** in the left sidebar

### 1.2 Create New Cluster

1. Click **"Create cluster"**
2. Configure cluster settings:

**Cluster ID**: `demo-vault-cluster` (or your preferred name)

**Tier**: 
- **Development** (recommended for demo) - Free tier, single node
- **Standard** (for production-like demo) - HA, better performance

**Region**: `us-east-1` (or same region as your AWS resources)

**Public**: ✅ Enabled (for demo access)

**Cluster Size**: 
- Development: Small (fixed)
- Standard: Small (can scale later)

3. Click **"Create cluster"**

### 1.3 Wait for Cluster Creation

- Cluster creation takes **5-10 minutes**
- Status will change from "Creating" to "Running"
- You'll see a green checkmark when ready

### 1.4 Note Cluster Details

Once running, note these important values:

**Public Cluster URL**: `https://demo-vault-cluster-public-vault-xxxxx.hashicorp.cloud:8200`

**Namespace**: `admin` (default for HCP Vault)

**Admin Token**: Click **"Generate token"** to create an admin token

> **Important**: Save the admin token securely! You'll need it for all configuration steps.

---

## Step 2: Install and Configure Vault CLI

### 2.1 Install Vault CLI

**macOS**:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

**Linux**:
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

**Windows**:
```powershell
choco install vault
```

### 2.2 Verify Installation

```bash
vault version
# Should show: Vault v1.15.0 or later
```

### 2.3 Configure Environment Variables

Create a file to store your Vault configuration:

```bash
# Create vault-env.sh
cat > ~/vault-env.sh << 'EOF'
#!/bin/bash
# HCP Vault Configuration

export VAULT_ADDR="https://your-cluster-public-vault-xxxxx.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"
export VAULT_TOKEN="your-admin-token-here"

echo "Vault environment configured:"
echo "  VAULT_ADDR: $VAULT_ADDR"
echo "  VAULT_NAMESPACE: $VAULT_NAMESPACE"
echo "  VAULT_TOKEN: ${VAULT_TOKEN:0:10}..."
EOF

chmod +x ~/vault-env.sh
```

**Load the configuration**:
```bash
source ~/vault-env.sh
```

### 2.4 Test Connection

```bash
vault status
```

Expected output:
```
Key                      Value
---                      -----
Seal Type                shamir
Initialized              true
Sealed                   false
Total Shares             1
Threshold                1
Version                  1.15.0
Storage Type             raft
Cluster Name             vault-cluster-xxxxx
Cluster ID               xxxxx-xxxx-xxxx-xxxx-xxxxx
HA Enabled               true
HA Cluster               https://...
HA Mode                  active
```

---

## Step 3: Run Automated Setup Script

### 3.1 Prepare AWS Credentials

You'll need AWS credentials to configure the AWS secrets engine:

```bash
# Set AWS credentials as environment variables
export AWS_ACCESS_KEY_ID="your-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"
```

> **Note**: These credentials need permissions to create IAM users and policies. They're only used to configure Vault's AWS secrets engine.

### 3.2 Navigate to Scripts Directory

```bash
cd ~/Repositories/TF-AAP-Actions-Bob-Demo/vault/scripts
```

### 3.3 Run Setup Script

```bash
./setup-hcp-vault.sh
```

### 3.4 Script Output

The script will:
1. ✅ Test Vault connection
2. ✅ Enable AWS secrets engine
3. ✅ Configure AWS secrets engine with your credentials
4. ✅ Create AWS roles for Terraform and Ansible
5. ✅ Enable KV v2 secrets engine
6. ✅ Enable AppRole authentication
7. ✅ Create Vault policies (terraform, ansible, openshift)
8. ✅ Create AppRole for Ansible
9. ✅ Generate credentials

**Save these outputs**:

```
========================================
Ansible AppRole Credentials:
========================================
Role ID: 12345678-1234-1234-1234-123456789012
Secret ID: 87654321-4321-4321-4321-210987654321

Save these credentials securely!
Set them as environment variables in AAP:
  VAULT_ROLE_ID=12345678-1234-1234-1234-123456789012
  VAULT_SECRET_ID=87654321-4321-4321-4321-210987654321

========================================
Terraform Token:
========================================
Token: hvs.CAESIJ...

Save this token securely!
Set it in HCP Terraform workspace variables:
  hcp_vault_token=hvs.CAESIJ...
```

---

## Step 4: Seed Demo Secrets

### 4.1 Run Seed Script

```bash
./seed-secrets.sh
```

### 4.2 Verify Secrets

The script creates secrets in these paths:

```bash
# List all secrets
vault kv list secret/

# View application secrets
vault kv get secret/applications/demo-app

# View Ansible secrets
vault kv get secret/ansible/config

# View OpenShift secrets
vault kv get secret/openshift/credentials

# View Terraform secrets
vault kv get secret/terraform/config

# View EDA secrets
vault kv get secret/eda/webhook-tokens
```

---

## Step 5: Configure AWS Secrets Engine

### 5.1 Verify AWS Secrets Engine

```bash
# Check AWS secrets engine status
vault read aws/config/root

# Test Terraform role
vault read aws/creds/terraform-provisioner
```

Expected output:
```
Key                Value
---                -----
access_key         AKIAIOSFODNN7EXAMPLE
secret_key         wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
security_token     <nil>
```

> **Note**: These are temporary credentials that Vault generates dynamically!

### 5.2 Test Ansible Role

```bash
vault read aws/creds/ansible-configurator
```

### 5.3 Verify Credential Rotation

```bash
# Read credentials twice - they should be different
vault read aws/creds/terraform-provisioner
sleep 2
vault read aws/creds/terraform-provisioner
```

---

## Step 6: Configure Policies

### 6.1 Verify Policies

```bash
# List all policies
vault policy list

# Read Terraform policy
vault policy read terraform-policy

# Read Ansible policy
vault policy read ansible-policy

# Read OpenShift policy
vault policy read openshift-policy
```

### 6.2 Test Policy Access

**Test Terraform policy**:
```bash
# Create a token with terraform policy
TERRAFORM_TOKEN=$(vault token create -policy=terraform-policy -ttl=1h -field=token)

# Test access
VAULT_TOKEN=$TERRAFORM_TOKEN vault read aws/creds/terraform-provisioner
# Should succeed

VAULT_TOKEN=$TERRAFORM_TOKEN vault read secret/data/ansible/config
# Should fail (no access)
```

**Test Ansible policy**:
```bash
# Login with AppRole
vault write auth/approle/login \
  role_id="your-role-id" \
  secret_id="your-secret-id"

# Use the returned token to test access
```

---

## Step 7: Configure AppRole for Ansible

### 7.1 Verify AppRole Configuration

```bash
# Check AppRole role
vault read auth/approle/role/ansible

# Get Role ID
vault read auth/approle/role/ansible/role-id

# Generate new Secret ID (if needed)
vault write -f auth/approle/role/ansible/secret-id
```

### 7.2 Test AppRole Authentication

```bash
# Login with AppRole
vault write auth/approle/login \
  role_id="your-role-id" \
  secret_id="your-secret-id"
```

Expected output:
```
Key                     Value
---                     -----
token                   hvs.CAESIJ...
token_accessor          xxxxx
token_duration          1h
token_renewable         true
token_policies          ["ansible-policy" "default"]
```

### 7.3 Test Secret Access with AppRole Token

```bash
# Use the token from previous step
export ANSIBLE_TOKEN="hvs.CAESIJ..."

# Test reading application secrets
VAULT_TOKEN=$ANSIBLE_TOKEN vault kv get secret/applications/demo-app

# Test reading OpenShift secrets
VAULT_TOKEN=$ANSIBLE_TOKEN vault kv get secret/openshift/credentials
```

---

## Step 8: Update HCP Terraform Variables

### 8.1 Update Terraform Workspace

Go to your HCP Terraform workspace and update these variables:

**hcp_vault_address**:
```
https://your-cluster-public-vault-xxxxx.hashicorp.cloud:8200
```

**hcp_vault_namespace**:
```
admin
```

**hcp_vault_token** (mark as sensitive):
```
hvs.CAESIJ... (from setup script output)
```

### 8.2 Verify in Terraform

You can test the connection by running a plan in HCP Terraform. It should now be able to:
1. Connect to Vault
2. Fetch dynamic AWS credentials
3. Use those credentials to plan AWS resources

---

## Step 9: Configure Vault Audit Logging

### 9.1 HCP Vault Audit Logs

**Important:** HCP Vault (managed service) handles audit logging automatically. You **cannot** enable file-based audit devices because you don't have filesystem access.

**Error you might see:**
```
Error enabling audit device: unsupported path
```

This is expected and normal for HCP Vault!

### 9.2 View Audit Logs in HCP Portal

**Important:** Audit log visibility depends on your HCP Vault tier.

**Development Tier (Free):**
- ❌ Audit logs are NOT visible in the UI
- ✅ Audit logging is still happening (HCP manages it)
- ✅ Logs are retained by HashiCorp for compliance
- ℹ️ You'll see: Overview, Replication, Networking tabs only

**Standard/Plus Tiers:**
- ✅ Audit logs visible in "Observability" or "Audit Logs" tab
- ✅ Full audit trail with filtering and search
- ✅ Export capabilities

**For this demo with Development tier:**
You can safely skip viewing audit logs. They're being collected by HCP automatically, but UI access requires upgrading to Standard tier ($0.50/hour).

### 9.3 Verify Audit Configuration

```bash
# Check audit devices (HCP manages these internally)
vault audit list
```

**Expected output:**
```
No audit devices are enabled.
```

**Note:** This is normal for HCP Vault. Audit logging is managed by HCP and visible only in the portal, not via CLI.

---

## Step 10: Create Additional Tokens (Optional)

### 10.1 Create Token for Testing

```bash
# Create a test token with full access
vault token create \
  -policy=default \
  -policy=terraform-policy \
  -policy=ansible-policy \
  -ttl=24h \
  -display-name="demo-testing"
```

### 10.2 Create Token for OpenShift

```bash
# Create token for OpenShift to read secrets
vault token create \
  -policy=openshift-policy \
  -ttl=720h \
  -display-name="openshift-demo"
```

---

## Configuration Summary

### ✅ Checklist

- [ ] HCP Vault cluster created and running
- [ ] Vault CLI installed and configured
- [ ] Environment variables set (VAULT_ADDR, VAULT_TOKEN, VAULT_NAMESPACE)
- [ ] Setup script executed successfully
- [ ] AWS secrets engine configured
- [ ] KV secrets engine enabled
- [ ] AppRole authentication enabled
- [ ] Policies created (terraform, ansible, openshift)
- [ ] Demo secrets seeded
- [ ] Terraform token generated
- [ ] Ansible AppRole credentials generated
- [ ] HCP Terraform variables updated
- [ ] Audit logging enabled

### 📋 Important Credentials

**Save these securely** (use a password manager):

```yaml
# HCP Vault
vault_address: "https://your-cluster.vault.hashicorp.cloud:8200"
vault_namespace: "admin"
vault_admin_token: "hvs.CAESIJ..."

# Terraform
terraform_token: "hvs.CAESIJ..."

# Ansible AppRole
ansible_role_id: "12345678-1234-1234-1234-123456789012"
ansible_secret_id: "87654321-4321-4321-4321-210987654321"

# AWS (for Vault configuration only)
aws_access_key_id: "AKIAIOSFODNN7EXAMPLE"
aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCY..."
```

### 🔐 Secrets Structure

```
secret/
├── applications/
│   └── demo-app
│       ├── database_url
│       ├── api_key
│       └── redis_password
├── ansible/
│   └── config
│       ├── sudo_password
│       └── vault_password
├── openshift/
│   └── credentials
│       ├── admin_user
│       ├── admin_password
│       └── registry_token
├── terraform/
│   └── config
│       ├── aws_region
│       └── ssh_key_name
└── eda/
    └── webhook-tokens
        └── terraform_webhook_token
```

---

## Verification Tests

### Test 1: Vault Connection

```bash
vault status
# Should show: Sealed: false, HA Mode: active
```

### Test 2: AWS Dynamic Credentials

```bash
# Generate credentials
CREDS=$(vault read -format=json aws/creds/terraform-provisioner)
ACCESS_KEY=$(echo $CREDS | jq -r '.data.access_key')
SECRET_KEY=$(echo $CREDS | jq -r '.data.secret_key')

# Test credentials
AWS_ACCESS_KEY_ID=$ACCESS_KEY \
AWS_SECRET_ACCESS_KEY=$SECRET_KEY \
aws sts get-caller-identity
```

### Test 3: AppRole Authentication

```bash
# Login
TOKEN=$(vault write -field=token auth/approle/login \
  role_id="your-role-id" \
  secret_id="your-secret-id")

# Test access
VAULT_TOKEN=$TOKEN vault kv get secret/applications/demo-app
```

### Test 4: Policy Enforcement

```bash
# Terraform token should access AWS creds
VAULT_TOKEN=$TERRAFORM_TOKEN vault read aws/creds/terraform-provisioner
# Should succeed

# Terraform token should NOT access Ansible secrets
VAULT_TOKEN=$TERRAFORM_TOKEN vault kv get secret/ansible/config
# Should fail with "permission denied"
```

---

## Troubleshooting

### Issue: "connection refused"

**Symptoms**: Cannot connect to Vault

**Solutions**:
1. Verify cluster is running in HCP Portal
2. Check VAULT_ADDR is correct (include https:// and :8200)
3. Verify public access is enabled
4. Check firewall/network settings

### Issue: "permission denied"

**Symptoms**: Cannot perform operation

**Solutions**:
1. Verify you're using the correct token
2. Check token hasn't expired: `vault token lookup`
3. Verify policy allows the operation: `vault policy read <policy-name>`
4. Ensure VAULT_NAMESPACE is set to "admin"

### Issue: AWS secrets engine fails

**Symptoms**: Cannot generate AWS credentials

**Solutions**:
1. Verify AWS credentials used to configure Vault are valid
2. Check AWS IAM permissions
3. Reconfigure AWS secrets engine:
   ```bash
   vault write aws/config/root \
     access_key=$AWS_ACCESS_KEY_ID \
     secret_key=$AWS_SECRET_ACCESS_KEY \
     region=us-east-1
   ```

### Issue: AppRole login fails

**Symptoms**: "invalid role_id or secret_id"

**Solutions**:
1. Verify Role ID: `vault read auth/approle/role/ansible/role-id`
2. Generate new Secret ID: `vault write -f auth/approle/role/ansible/secret-id`
3. Check AppRole configuration: `vault read auth/approle/role/ansible`

### Issue: Secrets not found

**Symptoms**: "no value found at secret/data/..."

**Solutions**:
1. List secrets: `vault kv list secret/`
2. Re-run seed script: `./seed-secrets.sh`
3. Manually create secret:
   ```bash
   vault kv put secret/applications/demo-app \
     database_url="postgresql://..." \
     api_key="demo-key"
   ```

---

## Security Best Practices

### 🔒 For Production

1. **Use Standard or Plus tier** for HA and better performance
2. **Enable private networking** instead of public access
3. **Rotate credentials regularly**:
   ```bash
   # Rotate AWS root credentials
   vault write -f aws/config/rotate-root
   ```
4. **Use short-lived tokens**:
   ```bash
   vault token create -ttl=1h  # Not 24h
   ```
5. **Enable MFA** for admin operations
6. **Use namespaces** to separate environments
7. **Monitor audit logs** regularly
8. **Backup Vault data** (automatic in HCP)

### 🔐 Token Management

```bash
# Check token info
vault token lookup

# Renew token
vault token renew

# Revoke token
vault token revoke <token>

# Revoke all tokens for a role
vault token revoke -mode path auth/approle
```

---

## Quick Reference Commands

```bash
# Connection
vault status
vault login

# Secrets
vault kv list secret/
vault kv get secret/path/to/secret
vault kv put secret/path/to/secret key=value
vault kv delete secret/path/to/secret

# AWS Credentials
vault read aws/creds/terraform-provisioner
vault read aws/creds/ansible-configurator

# AppRole
vault read auth/approle/role/ansible/role-id
vault write -f auth/approle/role/ansible/secret-id
vault write auth/approle/login role_id=X secret_id=Y

# Policies
vault policy list
vault policy read policy-name
vault policy write policy-name policy.hcl

# Tokens
vault token create -policy=policy-name
vault token lookup
vault token renew
vault token revoke token-id

# Audit
vault audit list
vault audit enable file file_path=/vault/logs/audit.log
```

---

## Next Steps

✅ **Completed**: HCP Vault is configured and ready!

**Next Guide**: `03-aap-setup.md` - Configure Ansible Automation Platform

**Update Required**: Go back to `01-hcp-terraform-setup.md` and update the Vault variables in your HCP Terraform workspace.

---

## Additional Resources

- [HCP Vault Documentation](https://developer.hashicorp.com/hcp/docs/vault)
- [Vault AWS Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/aws)
- [Vault AppRole Auth](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [Vault CLI Commands](https://developer.hashicorp.com/vault/docs/commands)