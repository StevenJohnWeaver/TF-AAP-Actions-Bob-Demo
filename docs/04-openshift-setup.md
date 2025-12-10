# OpenShift Setup Guide - Developer Sandbox

This guide walks you through setting up **Red Hat OpenShift Developer Sandbox** for the Red Hat + HashiCorp demo. The Developer Sandbox provides a FREE, fully-managed OpenShift cluster perfect for demos and development.

---

## Why Developer Sandbox?

✅ **FREE** - No cost, 60-day access (renewable)  
✅ **Fully Managed** - No installation or maintenance  
✅ **Accessible** - Works from anywhere, including AAP  
✅ **Production-like** - Real OpenShift 4.x cluster  
✅ **No Networking Issues** - Public API endpoint  
✅ **Perfect for Demos** - Professional environment

---

## Prerequisites

- [ ] Red Hat account (free to create)
- [ ] Web browser
- [ ] `oc` CLI installed (optional, for command-line access)

---

## Step 1: Sign Up for Developer Sandbox

### 1.1 Access the Sandbox

1. Go to **https://developers.redhat.com/developer-sandbox**
2. Click **"Start your sandbox for free"**
3. Sign in with your Red Hat account (or create one)

### 1.2 Activate Your Sandbox

1. Click **"Start using your sandbox"**
2. Verify your phone number (one-time verification)
3. Wait 1-2 minutes for cluster provisioning
4. You'll see: **"Your Red Hat OpenShift Sandbox is ready!"**

### 1.3 Get Your Cluster Details

Once activated, you'll see:
- **Cluster URL**: `https://console-openshift-console.apps.sandbox-m2.ll9k.p1.openshiftapps.com`
- **API URL**: `https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443`
- **Your username**: (your Red Hat account username)
- **Your namespace**: `{username}-dev` (automatically created)

**Save these details!**

---

## Step 2: Access Your Sandbox

### 2.1 Web Console Access

1. Click **"Launch Console"** from the Developer Sandbox page
2. Or navigate directly to your console URL
3. Login with your Red Hat account credentials

### 2.2 Get Your Login Token

**From Web Console:**
1. Click your username in the top-right corner
2. Select **"Copy login command"**
3. Click **"Display Token"**
4. Copy the **token** (starts with `sha256~`)
5. Copy the **login command** for reference

**Example:**
```bash
oc login --token=sha256~abcd1234... --server=https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443
```

**Save this token** - you'll store it in Vault!

### 2.3 Command Line Access (Optional)

**Install oc CLI:**
```bash
# macOS
brew install openshift-cli

# Linux
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/

# Windows
# Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
```

**Login:**
```bash
oc login --token=sha256~your-token --server=https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443
```

**Verify:**
```bash
oc whoami
oc project
oc get pods
```

---

## Step 3: Store Credentials in Vault

### 3.1 Set Vault Environment

```bash
export VAULT_ADDR="https://your-vault-cluster.vault.hashicorp.cloud:8200"
export VAULT_TOKEN="your-admin-token"
export VAULT_NAMESPACE="admin"
```

### 3.2 Store OpenShift Configuration

```bash
# Store your cluster URLs
vault kv put secret/openshift/config \
  api_url="https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443" \
  console_url="https://console-openshift-console.apps.sandbox-m2.ll9k.p1.openshiftapps.com"
```

**Replace with YOUR actual URLs from Step 1.3!**

### 3.3 Store OpenShift Credentials

```bash
# Store your login token
vault kv put secret/openshift/credentials \
  token="sha256~your-actual-token-here" \
  username="your-redhat-username" \
  namespace="your-username-dev"
```

**Replace with YOUR actual token and username!**

### 3.4 Verify Secrets

```bash
# Read back the secrets
vault kv get secret/openshift/config
vault kv get secret/openshift/credentials
```

---

## Step 4: Test OpenShift Connection

### 4.1 Test with oc CLI

```bash
# Login with your token
oc login --token=sha256~your-token --server=https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443

# Check your project
oc project

# List resources
oc get all

# Check quotas
oc describe quota
```

### 4.2 Test with Ansible

Create a test playbook `test-sandbox-connection.yml`:

```yaml
---
- name: Test OpenShift Sandbox Connection
  hosts: localhost
  gather_facts: false
  
  vars:
    vault_address: "{{ lookup('env', 'VAULT_ADDR') }}"
    vault_namespace: "{{ lookup('env', 'VAULT_NAMESPACE') | default('admin') }}"
  
  tasks:
    - name: Authenticate to Vault
      uri:
        url: "{{ vault_address }}/v1/auth/approle/login"
        method: POST
        body_format: json
        headers:
          X-Vault-Namespace: "{{ vault_namespace }}"
        body:
          role_id: "{{ lookup('env', 'VAULT_ROLE_ID') }}"
          secret_id: "{{ lookup('env', 'VAULT_SECRET_ID') }}"
        status_code: 200
      register: vault_login
      no_log: true
    
    - name: Get OpenShift config from Vault
      uri:
        url: "{{ vault_address }}/v1/secret/data/openshift/config"
        method: GET
        headers:
          X-Vault-Token: "{{ vault_login.json.auth.client_token }}"
          X-Vault-Namespace: "{{ vault_namespace }}"
        status_code: 200
      register: ocp_config
    
    - name: Get OpenShift credentials from Vault
      uri:
        url: "{{ vault_address }}/v1/secret/data/openshift/credentials"
        method: GET
        headers:
          X-Vault-Token: "{{ vault_login.json.auth.client_token }}"
          X-Vault-Namespace: "{{ vault_namespace }}"
        status_code: 200
      register: ocp_creds
      no_log: true
    
    - name: Test OpenShift API connection
      kubernetes.core.k8s_cluster_info:
        host: "{{ ocp_config.json.data.data.api_url }}"
        api_key: "{{ ocp_creds.json.data.data.token }}"
        validate_certs: true
      register: cluster_info
    
    - name: Display cluster information
      debug:
        msg:
          - "✅ Successfully connected to OpenShift Sandbox!"
          - "Cluster API: {{ ocp_config.json.data.data.api_url }}"
          - "Kubernetes Version: {{ cluster_info.version.server.kubernetes.gitVersion }}"
          - "OpenShift Version: {{ cluster_info.version.server.openshift }}"
          - "Your namespace: {{ ocp_creds.json.data.data.namespace }}"
```

**Run the test:**
```bash
# Set Vault credentials
export VAULT_ADDR="https://your-vault-cluster.vault.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"
export VAULT_ROLE_ID="your-role-id"
export VAULT_SECRET_ID="your-secret-id"

# Run test
ansible-playbook test-sandbox-connection.yml
```

---

## Step 5: Configure for Demo Workflow

### 5.1 Update Playbook Variables

The `deploy-to-openshift.yml` playbook will automatically use the Vault-stored credentials. No changes needed if you stored them correctly in Step 3!

**The playbook will:**
1. Authenticate to Vault
2. Fetch OpenShift credentials
3. Connect to your Sandbox cluster
4. Deploy the application

### 5.2 Verify Playbook Configuration

Check that `playbooks/deploy-to-openshift.yml` has:

```yaml
vars:
  openshift_api_url: "{{ lookup('env', 'OPENSHIFT_API_URL') | default('https://api.crc.testing:6443') }}"
```

**For Sandbox, set environment variable in AAP:**
```yaml
# In AAP job template extra vars:
openshift_api_url: "https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443"
```

Or it will read from Vault automatically!

---

## Step 6: Understand Sandbox Limitations

### 6.1 Resource Quotas

Developer Sandbox has resource limits:
- **CPU**: 7 cores
- **Memory**: 15 GB
- **Storage**: 15 GB
- **Pods**: 50 pods max
- **Services**: 20 services max

**Check your quotas:**
```bash
oc describe quota
```

### 6.2 Namespace Restrictions

- You have ONE namespace: `{username}-dev`
- You cannot create additional namespaces
- You cannot access cluster-admin functions
- Some operators may not be available

### 6.3 Duration

- **60 days** of access
- Can be **renewed** before expiration
- Automatic email reminders
- Data persists between sessions

---

## Step 7: Deploy Test Application

### 7.1 Deploy Sample App

```bash
# Create a simple deployment
oc new-app nginx:latest --name=test-app

# Expose the service
oc expose svc/test-app

# Get the route
oc get route test-app
```

### 7.2 Access Your Application

```bash
# Get the URL
ROUTE_URL=$(oc get route test-app -o jsonpath='{.spec.host}')
echo "Application URL: https://$ROUTE_URL"

# Test it
curl https://$ROUTE_URL
```

### 7.3 Clean Up

```bash
# Delete the test app
oc delete all -l app=test-app
```

---

## Step 8: Configure AAP Integration

### 8.1 AAP Job Template Configuration

When creating the "Deploy to OpenShift" job template in AAP:

**Extra Variables:**
```yaml
openshift_api_url: "https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443"
openshift_namespace: "your-username-dev"
application_name: "demo-app"
replicas: 2
environment: "sandbox"
```

**Credentials:**
- Add Vault credential (AppRole)
- Ensure `VAULT_ROLE_ID` and `VAULT_SECRET_ID` are set

**Execution Environment:**
- Ensure it has `kubernetes` and `openshift` Python packages
- Or add to requirements: `kubernetes>=12.0.0`, `openshift>=0.13.1`

### 8.2 Test from AAP

1. Run the job template manually
2. Watch the output
3. Verify deployment in OpenShift console
4. Check the application route

---

## Troubleshooting

### Issue: Token expired

**Symptoms:**
```
Error: Unauthorized
```

**Solution:**
```bash
# Get new token from web console
# Copy login command → Display Token

# Update in Vault
vault kv put secret/openshift/credentials \
  token="sha256~new-token" \
  username="your-username" \
  namespace="your-username-dev"
```

### Issue: Quota exceeded

**Symptoms:**
```
Error: exceeded quota
```

**Solution:**
```bash
# Check current usage
oc describe quota

# Delete unused resources
oc delete all -l app=old-app

# Scale down deployments
oc scale deployment/demo-app --replicas=1
```

### Issue: Cannot create resources

**Symptoms:**
```
Error: User cannot create resource
```

**Solution:**
- Sandbox has restrictions on certain resources
- Use standard Kubernetes resources (Deployment, Service, Route)
- Avoid cluster-scoped resources
- Check if resource type is allowed in Sandbox

### Issue: Sandbox expired

**Solution:**
1. Go to https://developers.redhat.com/developer-sandbox
2. Click "Renew your sandbox"
3. Get new token
4. Update Vault credentials

---

## Best Practices

### Security

✅ **Store tokens in Vault** - Never commit to Git  
✅ **Use short-lived tokens** - Regenerate regularly  
✅ **Limit permissions** - Use service accounts when possible  
✅ **Validate certificates** - Set `validate_certs: true` in production

### Resource Management

✅ **Clean up regularly** - Delete unused resources  
✅ **Monitor quotas** - Check `oc describe quota`  
✅ **Use resource limits** - Define in deployments  
✅ **Scale appropriately** - Start with 1-2 replicas

### Demo Preparation

✅ **Test before demo** - Verify everything works  
✅ **Have backup plan** - Know how to troubleshoot  
✅ **Document URLs** - Save cluster and route URLs  
✅ **Check expiration** - Renew sandbox if needed

---

## Quick Reference

### Essential Commands

```bash
# Login
oc login --token=sha256~... --server=https://api.sandbox...

# Check status
oc whoami
oc project
oc get all

# Deploy application
oc new-app <image>
oc expose svc/<service>
oc get route

# Monitor
oc get pods
oc logs <pod-name>
oc describe pod <pod-name>

# Clean up
oc delete all -l app=<name>

# Check quotas
oc describe quota
```

### Important URLs

- **Sandbox Portal**: https://developers.redhat.com/developer-sandbox
- **Documentation**: https://developers.redhat.com/learn/openshift/develop-on-openshift
- **oc CLI Downloads**: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

### Vault Paths

- `secret/openshift/config` - API URL, console URL
- `secret/openshift/credentials` - Token, username, namespace

---

## Next Steps

✅ **Sandbox is configured!**

Now you can:
1. **Complete AAP setup** - Follow `docs/03-aap-setup.md`
2. **Test the full workflow** - Terraform → Vault → AAP → OpenShift
3. **Run the demo** - Execute end-to-end automation

---

## Advantages Over Local OpenShift

| Feature | Developer Sandbox | OpenShift Local |
|---------|------------------|-----------------|
| Cost | FREE | FREE |
| Setup Time | 2 minutes | 30+ minutes |
| Resources | 7 CPU, 15GB RAM | 9GB RAM minimum |
| Accessibility | From anywhere | Local only |
| AAP Integration | ✅ Works perfectly | ⚠️ Networking issues |
| Maintenance | None | Manual updates |
| Production-like | ✅ Real cluster | ⚠️ Single node |
| Best For | **Demos, Development** | Local testing |

---

**Last Updated:** 2025-12-09  
**Version:** 2.0.0 - Developer Sandbox Focus  
**Recommended for:** Demos, Development, Testing