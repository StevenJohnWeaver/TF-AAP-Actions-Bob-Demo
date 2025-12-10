# OpenShift Setup Guide

This guide covers OpenShift setup options for the Red Hat + HashiCorp demo.

---

## Overview

You have **two options** for OpenShift in this demo:

### Option 1: Use Existing OpenShift Cluster (Recommended)
- ✅ Production-like environment
- ✅ Real-world scenario
- ✅ Better for customer demos
- ⚠️ Requires access to OpenShift cluster

### Option 2: OpenShift Local (Development)
- ✅ Quick setup for testing
- ✅ No external dependencies
- ✅ Good for learning the workflow
- ⚠️ Resource intensive (9GB RAM, 35GB disk)

---

## Option 1: Using Existing OpenShift Cluster

### Prerequisites

- [ ] Access to an OpenShift cluster (4.x or later)
- [ ] Cluster admin or project admin permissions
- [ ] `oc` CLI installed
- [ ] Cluster API URL and credentials

### Step 1: Get Cluster Information

```bash
# Login to your OpenShift cluster
oc login <your-cluster-api-url> -u <username>

# Get cluster info
oc cluster-info

# Get API URL
oc whoami --show-server
```

**Save these details:**
- API URL: `https://api.your-cluster.example.com:6443`
- Console URL: `https://console.your-cluster.example.com`
- Your credentials

### Step 2: Create Service Account for Ansible

```bash
# Create a new project for the demo
oc new-project demo-app

# Create service account
oc create serviceaccount ansible-deployer -n demo-app

# Grant necessary permissions
oc adm policy add-role-to-user edit system:serviceaccount:demo-app:ansible-deployer -n demo-app

# For cluster-wide operations (if needed)
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:demo-app:ansible-deployer

# Get the service account token
oc create token ansible-deployer -n demo-app --duration=24h
```

**Save this token** - you'll store it in Vault.

### Step 3: Store OpenShift Credentials in Vault

```bash
# Set Vault environment
export VAULT_ADDR="https://your-vault-cluster.vault.hashicorp.cloud:8200"
export VAULT_TOKEN="your-admin-token"
export VAULT_NAMESPACE="admin"

# Store OpenShift configuration
vault kv put secret/openshift/config \
  api_url="https://api.your-cluster.example.com:6443" \
  console_url="https://console.your-cluster.example.com"

# Store service account credentials
vault kv put secret/openshift/credentials \
  token="<paste-token-from-step-2>" \
  service_account="ansible-deployer" \
  namespace="demo-app"

# Verify
vault kv get secret/openshift/config
vault kv get secret/openshift/credentials
```

### Step 4: Update Playbook Variables

The `deploy-to-openshift.yml` playbook needs to use your cluster's API URL instead of the hardcoded local one.

**Option A: Update the playbook** (edit `playbooks/deploy-to-openshift.yml`):

Change line 11 from:
```yaml
openshift_api_url: "https://api.crc.testing:6443"
```

To:
```yaml
openshift_api_url: "{{ lookup('env', 'OPENSHIFT_API_URL') | default('https://api.your-cluster.example.com:6443') }}"
```

**Option B: Pass as extra variable** (in AAP job template):

Add extra variables:
```yaml
openshift_api_url: "https://api.your-cluster.example.com:6443"
```

### Step 5: Test Connection

Create a test playbook `test-openshift-connection.yml`:

```yaml
---
- name: Test OpenShift Connection
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
    
    - name: Get OpenShift config from Vault
      uri:
        url: "{{ vault_address }}/v1/secret/data/openshift/config"
        method: GET
        headers:
          X-Vault-Token: "{{ vault_login.json.auth.client_token }}"
          X-Vault-Namespace: "{{ vault_namespace }}"
        status_code: 200
      register: ocp_config
    
    - name: Test OpenShift API connection
      kubernetes.core.k8s_cluster_info:
        host: "{{ ocp_config.json.data.data.api_url }}"
        api_key: "{{ ocp_creds.json.data.data.token }}"
        validate_certs: false
      register: cluster_info
    
    - name: Display cluster information
      debug:
        msg:
          - "✅ Successfully connected to OpenShift!"
          - "Cluster API: {{ ocp_config.json.data.data.api_url }}"
          - "Kubernetes Version: {{ cluster_info.version.server.kubernetes.gitVersion }}"
          - "OpenShift Version: {{ cluster_info.version.server.openshift | default('N/A') }}"
```

Run the test:

```bash
# Set Vault credentials
export VAULT_ADDR="https://your-vault-cluster.vault.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"
export VAULT_ROLE_ID="<your-role-id>"
export VAULT_SECRET_ID="<your-secret-id>"

# Run test
ansible-playbook test-openshift-connection.yml
```

### Step 6: Configure AAP Job Template

When you create the "Deploy to OpenShift" job template in AAP:

1. **Extra Variables:**
```yaml
openshift_api_url: "https://api.your-cluster.example.com:6443"
openshift_namespace: "demo-app"
application_name: "demo-app"
replicas: 2
environment: "demo"
```

2. **Credentials:**
   - Add Vault credential (AppRole)
   - Ensure VAULT_ROLE_ID and VAULT_SECRET_ID are set

3. **Survey (Optional):**
   - Add survey questions for dynamic values
   - Application name
   - Number of replicas
   - Environment

---

## Option 2: OpenShift Local (For Testing)

### When to Use This

- Testing the workflow locally
- No access to external OpenShift cluster
- Learning the integration
- Development environment

### Quick Setup

```bash
# Install OpenShift Local
# Download from: https://console.redhat.com/openshift/create/local

# Setup
crc setup

# Start (takes 5-10 minutes)
crc start

# Get credentials
crc console --credentials

# Set up oc command
eval $(crc oc-env)

# Login
oc login -u kubeadmin https://api.crc.testing:6443
```

### Configure for Demo

```bash
# Create project
oc new-project demo-app

# Create service account
oc create serviceaccount ansible-deployer

# Grant permissions
oc adm policy add-role-to-user edit system:serviceaccount:demo-app:ansible-deployer

# Get token
oc create token ansible-deployer --duration=24h

# Store in Vault (same as Option 1, but with local URLs)
vault kv put secret/openshift/config \
  api_url="https://api.crc.testing:6443" \
  console_url="https://console-openshift-console.apps-crc.testing"

vault kv put secret/openshift/credentials \
  token="<token>" \
  service_account="ansible-deployer" \
  namespace="demo-app"
```

---

## Common Configuration (Both Options)

### Install Required Python Packages

On your Ansible control node (or AAP execution environment):

```bash
pip3 install openshift kubernetes
```

Or add to `requirements.txt`:
```
openshift>=0.13.1
kubernetes>=12.0.0
```

### Create Application Secrets in Vault

```bash
# Store application secrets
vault kv put secret/applications/demo-app \
  database_url="postgresql://demo:password@db.example.com:5432/demo" \
  api_key="demo-api-key-12345"

# Verify
vault kv get secret/applications/demo-app
```

### Update OpenShift Policy in Vault

The policy already exists at `vault/policies/openshift-policy.hcl`. Verify it's applied:

```bash
# Check if policy exists
vault policy read openshift-policy

# If not, apply it
vault policy write openshift-policy vault/policies/openshift-policy.hcl
```

---

## Troubleshooting

### Issue: Cannot connect to OpenShift API

**Check:**
```bash
# Test API connectivity
curl -k https://api.your-cluster.example.com:6443/version

# Test with oc
oc whoami --show-server
oc cluster-info
```

**Solution:**
- Verify API URL is correct
- Check network connectivity
- Ensure firewall allows access
- Verify token hasn't expired

### Issue: Permission denied when creating resources

**Check:**
```bash
# Check service account permissions
oc describe sa ansible-deployer -n demo-app

# Check role bindings
oc get rolebindings -n demo-app | grep ansible-deployer
```

**Solution:**
```bash
# Grant additional permissions
oc adm policy add-role-to-user edit system:serviceaccount:demo-app:ansible-deployer -n demo-app

# Or cluster-admin for full access
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:demo-app:ansible-deployer
```

### Issue: Token expired

**Solution:**
```bash
# Generate new token
oc create token ansible-deployer -n demo-app --duration=24h

# Update in Vault
vault kv put secret/openshift/credentials \
  token="<new-token>" \
  service_account="ansible-deployer" \
  namespace="demo-app"
```

### Issue: Playbook uses wrong API URL

**Solution:**

Update `playbooks/deploy-to-openshift.yml` line 11:

```yaml
# Change from:
openshift_api_url: "https://api.crc.testing:6443"

# To:
openshift_api_url: "{{ lookup('env', 'OPENSHIFT_API_URL') | default(lookup('hashi_vault', 'secret=secret/data/openshift/config:api_url')) }}"
```

Or pass as extra variable in AAP job template.

---

## Next Steps

✅ **OpenShift is configured!**

Now you can:
1. **Complete AAP setup** - Follow `docs/03-aap-setup.md`
2. **Test the full workflow** - Terraform → Vault → AAP → OpenShift
3. **Run the demo** - Execute end-to-end automation

---

## Quick Reference

### Essential Commands

```bash
# Check cluster status
oc cluster-info
oc get nodes

# Check project resources
oc project demo-app
oc get all

# Check deployments
oc get deployments
oc get pods
oc get routes

# View logs
oc logs -l app=demo-app

# Scale application
oc scale deployment/demo-app --replicas=3

# Delete resources
oc delete all -l app=demo-app
```

### Important Vault Paths

- `secret/openshift/config` - API URL, console URL
- `secret/openshift/credentials` - Service account token
- `secret/applications/demo-app` - Application secrets

---

**Last Updated:** 2025-12-09  
**Version:** 1.0.0