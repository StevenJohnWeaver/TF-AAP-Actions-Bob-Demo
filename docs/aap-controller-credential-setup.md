# AAP Controller Credential Setup for EDA Rulebook

This guide provides step-by-step instructions for creating the Red Hat Ansible Automation Platform (AAP) Controller credential that the EDA rulebook needs to trigger job templates.

---

## Overview

The EDA rulebook (`terraform-infrastructure-trigger.yml`) uses the `run_job_template` action to trigger AAP job templates when Terraform events are received. This action requires authentication to the AAP Controller API.

---

## Prerequisites

- [ ] AAP 2.4+ installed and accessible
- [ ] Admin access to AAP Controller
- [ ] Admin access to EDA Controller
- [ ] EDA rulebook activation created (see `03-aap-setup.md`)

---

## Using Built-in AAP Credential Type (Recommended)

EDA Controller includes a built-in "Red Hat Ansible Automation Platform" credential type. Use this instead of creating a custom one.

### Step 1: Create a Personal Access Token in AAP Controller

1. **Log in to AAP Controller**
   - Navigate to: `https://your-aap-controller-host`
   - **Important**: Use the Controller URL, not the EDA URL

2. **Access User Settings**
   - Click on your username in the top-right corner
   - Select **"Users"** from the left menu
   - Click on your username in the user list

3. **Create Token**
   - Go to the **"Tokens"** tab
   - Click **"Add"** button
   - Configure the token:

   **Application**: Leave blank or select `Automation Controller`
   
   **Description**: `EDA Rulebook - Terraform Infrastructure Handler`
   
   **Scope**: `Write`
   
   **Expiration**: (Optional) Set expiration date or leave blank for no expiration

4. **Save and Copy Token**
   - Click **"Save"**
   - **IMPORTANT**: Copy the token immediately - you won't see it again!
   - Store it securely (you'll need it in the next step)

### Step 2: Identify the Correct Controller URL

The controller URL must point to the **Automation Controller API**, not the EDA Controller.

**Common URL patterns:**

| Environment | Controller URL Format | Example |
|-------------|----------------------|---------|
| OpenShift | `https://[controller-route]/` | `https://sandbox-aap-controller.apps.example.com/` |
| Standalone | `https://[controller-hostname]/` | `https://aap-controller.example.com/` |
| All-in-One | `https://[hostname]/` | `https://aap.example.com/` |

**How to find your Controller URL:**

1. **From AAP Controller UI:**
   - Log in to AAP Controller
   - Copy the URL from your browser (without `/api/v2/...`)
   - Example: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`

2. **From OpenShift (if using OpenShift):**
   ```bash
   # Get the controller route
   oc get route -n ansible-automation-platform | grep controller
   
   # Example output:
   # sandbox-aap-controller   sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com
   ```

3. **Test the URL:**
   ```bash
   # Should return 200 OK with config data
   curl -k https://your-controller-url/api/v2/config/
   ```

**⚠️ Common Mistakes:**

- ❌ Using EDA URL: `https://sandbox-aap-eda.apps.example.com/`
- ❌ Using full API path: `https://controller.example.com/api/v2/config/`
- ❌ Missing trailing slash: `https://controller.example.com`
- ✅ Correct: `https://sandbox-aap-controller.apps.example.com/`

### Step 3: Create AAP Controller Credential in EDA

1. **Navigate to EDA Controller**
   - Go to: `https://your-eda-host/eda`

2. **Create Credential**
   - Go to **"Credentials"**
   - Click **"Create credential"**
   - Configure:

   **Name**: `AAP Controller - Demo`
   
   **Description**: `AAP Controller credentials for triggering job templates`
   
   **Organization**: `Default` (or your organization)
   
   **Credential Type**: `Red Hat Ansible Automation Platform` (built-in type)
   
   **Red Hat Ansible Automation Platform**: `https://your-controller-url/`
   - Example: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`
   - **Must include trailing slash!**
   - **Must be Controller URL, not EDA URL!**
   
   **OAuth Token**: `<paste the token you copied earlier>`
   
   **Verify SSL**: ✅ Yes (or No if using self-signed certificates)

3. **Save Credential**
   - Click **"Create credential"**

### Step 4: Update EDA Rulebook Activation

1. **Edit Rulebook Activation**
   - Go to **"Rulebook Activations"**
   - Click on **"Terraform Infrastructure Handler"**
   - Click **"Edit"**

2. **Add Controller Credential**
   - In the **"Credentials"** section, click **"Add"**
   - Select: `AAP Controller - Demo`
   - You should now have two credentials:
     - `HCP Vault - Demo`
     - `AAP Controller - Demo`

3. **Save and Restart**
   - Click **"Save"**
   - The activation will automatically restart with the new credential

### Step 5: Verify the Configuration

1. **Check Activation Logs**
   - Go to **"Rulebook Activations"**
   - Click on **"Terraform Infrastructure Handler"**
   - Check the **"History"** or **"Logs"** tab
   - Look for successful startup (no 404 errors)

2. **Expected Log Output:**
   ```
   Creating Job
   Job activation-job-1-X is running
   Listening to event stream: terraform-infrastructure-events
   ```

3. **If you see 404 errors:**
   - Double-check the Controller URL
   - Verify it ends with `/`
   - Test the URL: `curl -k https://your-controller-url/api/v2/config/`

---

## Troubleshooting

### Issue: "404, message='Not Found', url=URL('https://...api/v2/config/')"

**This is the error you're seeing!**

**Root Cause**: Incorrect Controller URL in the credential

**Solutions:**

1. **Verify Controller URL Format:**
   ```bash
   # Test the URL (should return JSON config)
   curl -k https://your-controller-url/api/v2/config/
   
   # If 404, try without /api/v2/config/
   curl -k https://your-controller-url/
   ```

2. **Common Fixes:**
   - Add trailing slash: `https://controller.example.com/`
   - Use Controller route, not EDA route
   - Remove `/api/v2/` from URL
   - Check for typos in hostname

3. **For OpenShift Deployments:**
   ```bash
   # Get correct controller route
   oc get route -n ansible-automation-platform | grep -E "controller|automation-controller"
   
   # Use the route hostname with https://
   # Example: https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/
   ```

4. **Update Credential:**
   - Edit the `AAP Controller - Demo` credential
   - Update the **"Red Hat Ansible Automation Platform"** field
   - Ensure trailing slash is present
   - Save and restart the activation

### Issue: "Authentication failed" or "401 Unauthorized"

**Symptoms**: Rulebook activation shows authentication errors

**Solutions:**
1. Verify token is still valid:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        https://your-controller-url/api/v2/me/
   ```
2. Check token hasn't expired
3. Regenerate token if needed
4. Verify token has "Write" scope

### Issue: "SSL certificate verification fails"

**Symptoms**: "SSL: CERTIFICATE_VERIFY_FAILED" error

**Solutions:**
1. Set `Verify SSL: No` in credential (for testing only)
2. Add CA certificate to EDA controller trust store
3. Use proper SSL certificates in production

### Issue: "Permission denied" when launching job

**Symptoms**: Authentication succeeds but job launch fails

**Solutions**:
1. Verify user has permission to launch the job template
2. Check organization access
3. Ensure token user has "Execute" permission on job template
4. Add user to appropriate team/role

---

## Verification Steps

### Test 1: Verify Controller URL

```bash
# Should return 200 OK with JSON config
curl -k https://your-controller-url/api/v2/config/

# Example response:
# {
#   "time_zone": "UTC",
#   "license_info": {...},
#   "version": "4.4.0",
#   ...
# }
```

### Test 2: Verify Token Authentication

```bash
# Should return your user info
curl -k -H "Authorization: Bearer YOUR_TOKEN" \
     https://your-controller-url/api/v2/me/

# Example response:
# {
#   "id": 1,
#   "username": "admin",
#   "email": "admin@example.com",
#   ...
# }
```

### Test 3: Check Rulebook Activation Logs

1. Go to **"Rulebook Activations"**
2. Click on **"Terraform Infrastructure Handler"**
3. Check the **"History"** or **"Logs"** tab
4. Should see successful startup, no 404 errors

### Test 4: Send Test Event

Send a test event to verify end-to-end:

```bash
# Get your EDA API token (different from controller token!)
EDA_TOKEN="your-eda-api-token"

# Post test event
curl -X POST https://your-eda-host/api/eda/v1/event-streams/terraform-infrastructure-events/post/ \
  -H "Authorization: Bearer $EDA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "terraform",
    "event_type": "infrastructure_provisioned",
    "timestamp": "2024-12-10T17:00:00Z",
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

### Test 5: Verify Job Launch

1. After sending test event, check **"Jobs"** in AAP Controller
2. You should see a new job for **"Configure AWS Infrastructure"**
3. If the job appears, everything is working correctly!

---

## Quick Fix for Your Current Error

Based on your log showing:
```
url=URL('https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/')
```

**The issue**: This URL appears to be the EDA route, not the Controller route.

**Fix:**

1. **Find the correct Controller URL:**
   ```bash
   oc get route -n ansible-automation-platform | grep controller
   ```

2. **Look for a route like:**
   - `sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com`
   - NOT `sandbox-aap-steveweaver-hashi-dev` (this looks like EDA)

3. **Update your credential:**
   - Edit `AAP Controller - Demo` credential in EDA
   - Change URL to: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`
   - Save and restart activation

4. **Verify:**
   ```bash
   # Should return config, not 404
   curl -k https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/
   ```

---

## Security Best Practices

### Token Management

1. **Use Tokens Instead of Passwords**
   - Tokens can be revoked without changing passwords
   - Tokens can have limited scope
   - Tokens can have expiration dates

2. **Rotate Tokens Regularly**
   - Set expiration dates on tokens
   - Rotate tokens every 90 days
   - Revoke unused tokens

3. **Limit Token Scope**
   - Use "Write" scope (not "Admin")
   - Create service accounts for automation
   - Don't use personal admin accounts

### Credential Storage

1. **Never Commit Credentials**
   - Don't store tokens in Git
   - Use AAP's credential management
   - Encrypt credentials at rest

2. **Use RBAC**
   - Limit who can view credentials
   - Use separate credentials per environment
   - Audit credential access

---

## Configuration Summary

### ✅ Checklist

- [ ] Personal access token created in AAP **Controller** (not EDA)
- [ ] Token copied and stored securely
- [ ] Correct Controller URL identified (test with curl)
- [ ] AAP Controller credential created in EDA using built-in type
- [ ] Controller URL includes trailing slash
- [ ] Credential attached to rulebook activation
- [ ] Rulebook activation restarted successfully
- [ ] No 404 errors in activation logs
- [ ] Test event sent successfully
- [ ] Job template launched successfully

### 📋 Important Values

Record these for reference:

```yaml
# AAP Controller Credential
credential_name: "AAP Controller - Demo"
credential_type: "Red Hat Ansible Automation Platform" (built-in)
controller_url: "https://sandbox-aap-controller.apps.example.com/"
token_description: "EDA Rulebook - Terraform Infrastructure Handler"
token_scope: "Write"

# Rulebook Activation
activation_name: "Terraform Infrastructure Handler"
credentials:
  - "HCP Vault - Demo"
  - "AAP Controller - Demo"

# URL Examples
eda_url: "https://sandbox-aap-eda.apps.example.com/"
controller_url: "https://sandbox-aap-controller.apps.example.com/"
```

---

## Next Steps

✅ **Completed**: AAP Controller credential configured!

**Continue with**: Testing the full integration (see `03-aap-setup.md` Step 10)

---

## Additional Resources

- [AAP API Authentication](https://docs.ansible.com/automation-controller/latest/html/userguide/security.html#authentication)
- [Personal Access Tokens](https://docs.ansible.com/automation-controller/latest/html/userguide/applications_auth.html#tokens)
- [EDA Credentials](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4/html/event-driven_ansible_controller_user_guide/eda-credentials)
- [OpenShift Routes](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)

---

**Made with Bob** 🤖