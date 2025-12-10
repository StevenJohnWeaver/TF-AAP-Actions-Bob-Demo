# Fix Terraform Credential Issues

Guide to resolve Vault and AAP authentication errors in Terraform.

---

## Error 1: Vault Token Invalid (403 Permission Denied)

**Error**:
```
Error: failed to lookup token, err=Error making API request.
URL: GET https://demo-vault-cluster-public-vault-28ca0cf3.a5871bc5.z1.hashicorp.cloud:8200/v1/auth/token/lookup-self
Code: 403. Errors: * permission denied * invalid token
```

### Solution: Regenerate Vault Token

#### Option 1: Use AppRole Instead of Token (Recommended)

Update `terraform/main.tf` to use AppRole authentication:

```hcl
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
```

Then add to `terraform/variables.tf`:

```hcl
variable "vault_role_id" {
  description = "Vault AppRole Role ID"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Vault AppRole Secret ID"
  type        = string
  sensitive   = true
}
```

#### Option 2: Generate New Vault Token

If you prefer to keep using tokens:

```bash
# Login to HCP Vault
vault login -method=userpass username=your-username

# Or use existing token
export VAULT_TOKEN="your-admin-token"
export VAULT_ADDR="https://demo-vault-cluster-public-vault-28ca0cf3.a5871bc5.z1.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"

# Create a new token with appropriate policies
vault token create \
  -policy=terraform-policy \
  -ttl=24h \
  -renewable=true \
  -display-name="terraform-demo"

# Copy the token and update your Terraform Cloud workspace variable
```

#### Option 3: Get AppRole Credentials from Setup Script

If you ran the Vault setup script, get the credentials:

```bash
# Run the script to get AppRole credentials
cd vault/scripts
./get-approle-credentials.sh

# Output will show:
# Role ID: xxxxx
# Secret ID: yyyyy

# Add these to Terraform Cloud workspace variables:
# - vault_role_id
# - vault_secret_id
```

---

## Error 2: AAP Provider Authentication (401 Invalid Credentials)

**Error**:
```
Error: Unexpected HTTP status code received for GET request to path 
https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/
Expected one of ([200]), got (401). Response details: map[detail:Invalid username/password.]
```

### Issue

The AAP provider is trying to access `/api/` which doesn't exist in AAP 2.5+ Unified Gateway. It should use `/api/controller/v2/` or use token authentication.

### Solution: Use Token Authentication

#### Step 1: Create AAP Token for Terraform

1. **Log in to AAP Controller**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
   - Click **"Automation Controller"**

2. **Create Token**
   - Go to **Access** → **Users**
   - Click your username
   - Go to **Tokens** tab
   - Click **"Create token"**
   - Configure:
     - **Description**: `Terraform Provider Token`
     - **Application**: Leave blank
     - **Scope**: `Write`
   - Click **"Save"**
   - **Copy the token immediately!**

#### Step 2: Update Terraform Configuration

Update `terraform/main.tf`:

```hcl
# Configure AAP Provider for EDA integration
provider "aap" {
  host  = var.aap_host
  token = var.aap_token
  
  # Remove username/password authentication
  # username = var.aap_username
  # password = var.aap_password
}
```

#### Step 3: Update Variables

In `terraform/variables.tf`, update:

```hcl
variable "aap_token" {
  description = "AAP API token for authentication"
  type        = string
  sensitive   = true
}

# Comment out or remove these:
# variable "aap_username" {
#   description = "AAP username"
#   type        = string
#   sensitive   = true
# }
# 
# variable "aap_password" {
#   description = "AAP password"
#   type        = string
#   sensitive   = true
# }
```

#### Step 4: Update Terraform Cloud Workspace Variables

1. **Go to Terraform Cloud**
   - Navigate to your workspace: `aws-infrastructure`

2. **Add/Update Variables**
   - Add: `aap_token` = (paste your token)
   - Mark as **Sensitive**
   - Remove or update: `aap_username` and `aap_password`

---

## Complete Fix Checklist

### For Vault:

- [ ] Choose authentication method (AppRole recommended)
- [ ] If using AppRole:
  - [ ] Get Role ID and Secret ID from setup script
  - [ ] Update `main.tf` to use AppRole auth
  - [ ] Add variables to Terraform Cloud
- [ ] If using token:
  - [ ] Generate new token with correct policies
  - [ ] Update token in Terraform Cloud

### For AAP:

- [ ] Create AAP token in Controller
- [ ] Update `main.tf` to use token authentication
- [ ] Update `variables.tf` to use `aap_token`
- [ ] Add `aap_token` to Terraform Cloud workspace
- [ ] Remove username/password variables

---

## Testing the Fix

### Test 1: Verify Vault Authentication

```bash
# Test Vault connection
export VAULT_ADDR="https://demo-vault-cluster-public-vault-28ca0cf3.a5871bc5.z1.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"

# If using token:
export VAULT_TOKEN="your-token"
vault token lookup

# If using AppRole:
vault write auth/approle/login \
  role_id="your-role-id" \
  secret_id="your-secret-id"
```

### Test 2: Verify AAP Authentication

```bash
# Test AAP token
curl -k -H "Authorization: Bearer YOUR_AAP_TOKEN" \
  https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/controller/v2/me/

# Should return your user info (not 401)
```

### Test 3: Run Terraform Plan

```bash
# In Terraform Cloud, trigger a new plan
# Or locally:
terraform init
terraform plan

# Should not see authentication errors
```

---

## Recommended Configuration

### main.tf (Vault Provider)

```hcl
provider "vault" {
  address   = var.hcp_vault_address
  namespace = var.hcp_vault_namespace
  
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}
```

### main.tf (AAP Provider)

```hcl
provider "aap" {
  host  = var.aap_host
  token = var.aap_token
}
```

### Terraform Cloud Variables

```
# Vault
vault_role_id    = "xxxxx" (sensitive)
vault_secret_id  = "yyyyy" (sensitive)
hcp_vault_address   = "https://demo-vault-cluster-public-vault-28ca0cf3.a5871bc5.z1.hashicorp.cloud:8200"
hcp_vault_namespace = "admin"

# AAP
aap_host  = "https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com"
aap_token = "zzzzz" (sensitive)

# EDA Event Stream
eda_event_stream_name     = "terraform-infrastructure-events"
eda_event_stream_username = "your-eda-username" (sensitive)
eda_event_stream_password = "your-eda-password" (sensitive)
```

---

## Troubleshooting

### Issue: "AppRole not found"

**Solution**: Run the Vault setup script:
```bash
cd vault/scripts
./setup-hcp-vault.sh
```

### Issue: "Token expired"

**Solution**: Tokens expire. Use AppRole for auto-renewal or create longer-lived tokens:
```bash
vault token create -policy=terraform-policy -ttl=720h -renewable=true
```

### Issue: AAP token doesn't work

**Solutions**:
1. Verify token scope is "Write"
2. Check token hasn't expired
3. Ensure user has appropriate permissions
4. Try creating a new token

---

## Security Best Practices

1. **Use AppRole for Vault** - Tokens expire, AppRole auto-renews
2. **Use Tokens for AAP** - More secure than username/password
3. **Store in Terraform Cloud** - Mark all credentials as sensitive
4. **Rotate Regularly** - Update tokens/secrets every 90 days
5. **Least Privilege** - Only grant necessary permissions

---

**Made with Bob** 🤖