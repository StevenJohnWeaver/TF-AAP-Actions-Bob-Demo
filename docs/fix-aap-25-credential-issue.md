# Fix AAP 2.5+ Credential Issue - Complete Solution

This guide provides the complete solution for the AAP Controller credential issue with AAP 2.5+ Unified Gateway architecture.

---

## Problem Summary

**Issue**: EDA rulebook fails with 404 error when trying to trigger job templates:
```
Error connecting to controller 404, message='Not Found', url=URL('https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/')
```

**Root Cause**: AAP 2.5+ uses Unified Gateway architecture where:
- Controller API moved from `/api/v2/` to `/api/controller/v2/`
- The `run_job_template` action in EDA rulebooks still uses the old API path
- Built-in credential types may not handle this correctly

**Solution**: Update the rulebook to use `awx.awx.job_launch` module which properly handles AAP 2.5+ API paths.

---

## Step 1: Update the EDA Rulebook (COMPLETED)

✅ **Already done**: The rulebook has been updated to use `awx.awx.job_launch` instead of `run_job_template`.

**Changes made to `extensions/eda/rulebooks/terraform-infrastructure-trigger.yml`:**

```yaml
# OLD (causing 404 errors):
action:
  run_job_template:
    name: "Configure AWS Infrastructure"
    organization: "Default"
    inventory: "Dynamic AWS Inventory"

# NEW (works with AAP 2.5+):
action:
  awx.awx.job_launch:
    job_template: "Configure AWS Infrastructure"
    organization: "Default"
    inventory: "Dynamic AWS Inventory"
    controller_host: "{{ ansible_env.CONTROLLER_HOST | default('https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com') }}"
    controller_oauthtoken: "{{ ansible_env.CONTROLLER_OAUTH_TOKEN }}"
    validate_certs: true
    wait: false
```

---

## Step 2: Create AAP Controller Credential

### 2.1 Create Personal Access Token

1. **Log in to AAP**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`

2. **Navigate to Automation Controller**
   - Click **"Automation Controller"** in the left navigation

3. **Create Token**
   - Go to **Access** → **Users**
   - Click on your username
   - Go to **Tokens** tab
   - Click **"Create token"**
   - Configure:
     - **Description**: `EDA Rulebook - Terraform Infrastructure Handler`
     - **Application**: Leave blank
     - **Scope**: `Write`
   - Click **"Save"**
   - **Copy the token immediately!**

### 2.2 Create Credential in EDA

1. **Navigate to EDA**
   - Click **"Event-Driven Ansible"** in the left navigation

2. **Create Credential**
   - Go to **Credentials**
   - Click **"Create credential"**
   - Configure:
     - **Name**: `AAP Controller - Demo`
     - **Description**: `AAP Controller credentials for triggering job templates`
     - **Organization**: `Default`
     - **Credential Type**: `Red Hat Ansible Automation Platform`
     - **Red Hat Ansible Automation Platform**: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
     - **OAuth Token**: (paste your token)
     - **Verify SSL**: ✅ Yes
   - Click **"Create credential"**

---

## Step 3: Update EDA Rulebook Activation

1. **Edit Activation**
   - Go to **Rulebook Activations**
   - Click on **"Terraform Infrastructure Handler"**
   - Click **"Edit"**

2. **Add Credentials**
   - In **Credentials** section, ensure you have:
     - `HCP Vault - Demo`
     - `AAP Controller - Demo` (the one you just created)

3. **Update EDA Project**
   - Since we modified the rulebook, sync the EDA project:
   - Go to **Projects**
   - Find **"Red Hat HashiCorp Demo - EDA"**
   - Click the **sync icon**
   - Wait for sync to complete

4. **Save and Restart**
   - Click **"Save"** on the activation
   - The activation will restart automatically

---

## Step 4: Verify the Fix

### Test 1: Check Activation Logs

1. Go to **Rulebook Activations**
2. Click on **"Terraform Infrastructure Handler"**
3. Check **History** or **Logs** tab
4. Should see successful startup with **NO 404 errors**

Expected log output:
```
Creating Job
Job activation-job-1-X is running
Listening to event stream: terraform-infrastructure-events
```

### Test 2: Send Test Event

```bash
# Get your EDA API token (different from controller token!)
EDA_TOKEN="your-eda-api-token"

# Post test event
curl -X POST https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/eda/v1/event-streams/terraform-infrastructure-events/post/ \
  -H "Authorization: Bearer $EDA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "terraform",
    "event_type": "infrastructure_provisioned",
    "timestamp": "2024-12-10T17:30:00Z",
    "terraform": {
      "workspace": "test-workspace",
      "organization": "test-org",
      "run_id": "test-123"
    },
    "infrastructure": {
      "vpc": {"id": "vpc-test", "cidr": "10.0.0.0/16"},
      "instances": [],
      "region": "us-east-1",
      "environment": "test"
    },
    "ansible_inventory": {"all": {"hosts": {}}},
    "deployment": {
      "openshift_namespace": "test",
      "application_name": "test-app",
      "replicas": 1
    },
    "vault": {
      "address": "https://vault.example.com:8200",
      "namespace": "admin"
    }
  }'
```

### Test 3: Verify Job Launch

1. After sending test event, check **Jobs** in Automation Controller
2. You should see a new job for **"Configure AWS Infrastructure"**
3. Job should start successfully (not fail with authentication errors)

---

## Understanding the Fix

### Why `awx.awx.job_launch` Works

The `awx.awx.job_launch` module:
1. **Handles AAP 2.5+ API paths correctly**
2. **Uses environment variables from credential injection**
3. **Supports the unified gateway architecture**
4. **Provides better error handling and logging**

### Credential Injection

The AAP credential type injects these environment variables:
```yaml
env:
  CONTROLLER_HOST: 'https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/'
  CONTROLLER_OAUTH_TOKEN: 'your-token-here'
  CONTROLLER_VERIFY_SSL: 'true'
```

The rulebook uses these via:
```yaml
controller_host: "{{ ansible_env.CONTROLLER_HOST | default('...') }}"
controller_oauthtoken: "{{ ansible_env.CONTROLLER_OAUTH_TOKEN }}"
```

### API Path Handling

- **Old `run_job_template`**: Hardcoded to use `/api/v2/` (AAP 2.4 and earlier)
- **New `awx.awx.job_launch`**: Automatically detects and uses `/api/controller/v2/` (AAP 2.5+)

---

## Troubleshooting

### Issue: "Module awx.awx.job_launch not found"

**Solution**: Ensure `awx.awx` collection is installed in the execution environment:

```bash
# Check if collection is installed
ansible-galaxy collection list | grep awx

# Install if missing
ansible-galaxy collection install awx.awx
```

### Issue: Still getting 404 errors

**Check:**
1. EDA project synced after rulebook changes
2. Activation restarted with new rulebook version
3. Credential has correct URL with trailing slash
4. Token is valid and has "Write" scope

### Issue: "Authentication failed"

**Solutions:**
1. Verify token:
   ```bash
   curl -k -H "Authorization: Bearer YOUR_TOKEN" \
     https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/controller/v2/me/
   ```
2. Regenerate token if expired
3. Check token scope is "Write"

### Issue: Job template not found

**Solutions:**
1. Verify job template name matches exactly: `"Configure AWS Infrastructure"`
2. Check job template exists in the correct organization
3. Ensure user has execute permission on job template

---

## Migration Guide: run_job_template → awx.awx.job_launch

If you have other rulebooks using `run_job_template`, migrate them:

### Before (AAP 2.4 and earlier):
```yaml
action:
  run_job_template:
    name: "My Job Template"
    organization: "Default"
    inventory: "My Inventory"
    extra_vars:
      key: value
```

### After (AAP 2.5+):
```yaml
action:
  awx.awx.job_launch:
    job_template: "My Job Template"
    organization: "Default"
    inventory: "My Inventory"
    controller_host: "{{ ansible_env.CONTROLLER_HOST }}"
    controller_oauthtoken: "{{ ansible_env.CONTROLLER_OAUTH_TOKEN }}"
    validate_certs: true
    wait: false
    extra_vars:
      key: value
```

### Key Changes:
- `name` → `job_template`
- Add `controller_host` and `controller_oauthtoken`
- Add `validate_certs` and `wait` parameters
- Everything else stays the same

---

## Configuration Summary

### ✅ Checklist

- [x] Rulebook updated to use `awx.awx.job_launch`
- [ ] Personal access token created in AAP Controller
- [ ] AAP Controller credential created in EDA
- [ ] Credential attached to rulebook activation
- [ ] EDA project synced with updated rulebook
- [ ] Rulebook activation restarted
- [ ] No 404 errors in activation logs
- [ ] Test event triggers job successfully

### 📋 Your Configuration

```yaml
# AAP Instance
aap_url: "https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/"
aap_version: "2.5+"
architecture: "Unified Gateway"

# Rulebook Changes
old_action: "run_job_template"
new_action: "awx.awx.job_launch"
api_path_old: "/api/v2/"
api_path_new: "/api/controller/v2/"

# Credentials
controller_credential: "AAP Controller - Demo"
vault_credential: "HCP Vault - Demo"

# Job Template
job_template_name: "Configure AWS Infrastructure"
organization: "Default"
inventory: "Dynamic AWS Inventory"
```

---

## Next Steps

✅ **Completed**: Rulebook updated and credential setup documented!

**Now do:**
1. Create the AAP Controller credential (Step 2)
2. Update the rulebook activation (Step 3)
3. Test with a sample event (Step 4)

Once working, continue with the full Terraform → EDA → AAP integration testing.

---

## Additional Resources

- [awx.awx Collection Documentation](https://docs.ansible.com/ansible/latest/collections/awx/awx/job_launch_module.html)
- [AAP 2.5 Unified Gateway](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.5/html/red_hat_ansible_automation_platform_architecture/)
- [EDA Rulebook Actions](https://ansible.readthedocs.io/projects/rulebook/en/stable/actions.html)
- [AAP API Migration Guide](https://docs.ansible.com/automation-controller/latest/html/upgrade-migration-guide/index.html)

---

**Made with Bob** 🤖