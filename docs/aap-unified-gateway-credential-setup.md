# AAP Controller Credential Setup for Unified Gateway (AAP 2.5+)

**IMPORTANT**: Your AAP instance uses the **Unified Gateway** architecture (AAP 2.5+), where EDA and Controller share the same URL but use different API paths.

---

## Key Information for Your Setup

**Your AAP URL**: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`

**API Paths:**
- EDA API: `/api/eda/v1/`
- Controller API: `/api/controller/v2/`

**This is correct!** Both services use the same base URL.

---

## Step 1: Create Personal Access Token in AAP Controller

1. **Log in to AAP**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`

2. **Navigate to Automation Controller**
   - Click on **"Automation Controller"** in the left navigation
   - Or go directly to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/#/controller`

3. **Access User Settings**
   - Click your username in the top-right corner
   - Select **"Users"**
   - Click on your username

4. **Create Token**
   - Go to the **"Tokens"** tab
   - Click **"Create token"** or **"Add"**
   - Configure:

   **Application**: Leave blank or select `Automation Controller`
   
   **Description**: `EDA Rulebook - Terraform Infrastructure Handler`
   
   **Scope**: `Write`
   
   **Expiration**: (Optional) Leave blank for no expiration

5. **Save and Copy Token**
   - Click **"Save"**
   - **IMPORTANT**: Copy the token immediately!
   - Store it securely

---

## Step 2: Create AAP Controller Credential in EDA

1. **Navigate to EDA Controller**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
   - Click on **"Event-Driven Ansible"** in the left navigation

2. **Create Credential**
   - Go to **"Credentials"**
   - Click **"Create credential"**
   - Configure:

   **Name**: `AAP Controller - Demo`
   
   **Description**: `AAP Controller credentials for triggering job templates`
   
   **Organization**: `Default` (or your organization)
   
   **Credential Type**: `Red Hat Ansible Automation Platform` (built-in type)
   
   **Red Hat Ansible Automation Platform**: 
   ```
   https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/
   ```
   **IMPORTANT**: Use the SAME URL for both EDA and Controller!
   
   **OAuth Token**: `<paste the token you copied>`
   
   **Verify SSL**: ✅ Yes

3. **Save Credential**
   - Click **"Create credential"**

---

## Step 3: Update EDA Rulebook Activation

1. **Edit Rulebook Activation**
   - Go to **"Rulebook Activations"**
   - Click on **"Terraform Infrastructure Handler"**
   - Click **"Edit"**

2. **Add Controller Credential**
   - In the **"Credentials"** section, click **"Add"**
   - Select: `AAP Controller - Demo`
   - You should now have:
     - `HCP Vault - Demo`
     - `AAP Controller - Demo`

3. **Save and Restart**
   - Click **"Save"**
   - The activation will restart automatically

---

## Step 4: Verify the Configuration

### Test 1: Check API Endpoint

```bash
# Should return authentication error (not 404!)
curl -k https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/controller/v2/config/

# Expected response:
# {"detail":"Authentication credentials were not provided..."}
```

✅ This is correct! The endpoint exists and is asking for authentication.

### Test 2: Test with Token

```bash
# Replace YOUR_TOKEN with your actual token
curl -k -H "Authorization: Bearer YOUR_TOKEN" \
  https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/controller/v2/me/

# Should return your user info
```

### Test 3: Check Rulebook Activation Logs

1. Go to **"Rulebook Activations"**
2. Click on **"Terraform Infrastructure Handler"**
3. Check the **"History"** or **"Logs"** tab
4. Should see successful startup, **NO 404 errors**

---

## Understanding AAP 2.5+ Unified Gateway

### Architecture

```
https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/
│
├── /api/controller/v2/    ← Automation Controller API
│   ├── /config/
│   ├── /me/
│   ├── /job_templates/
│   └── ...
│
├── /api/eda/v1/           ← Event-Driven Ansible API
│   ├── /activations/
│   ├── /event-streams/
│   └── ...
│
├── /api/gateway/v1/       ← Gateway API
│
└── /#/                    ← Web UI
    ├── /controller        ← Controller UI
    └── /eda              ← EDA UI
```

### Key Points

1. **Same Base URL**: Both EDA and Controller use the same URL
2. **Different API Paths**: 
   - Controller: `/api/controller/v2/`
   - EDA: `/api/eda/v1/`
3. **Unified Authentication**: Single token works for both
4. **Shared Web UI**: Navigate between services in the same interface

---

## Why Your Original Error Occurred

**Original Error:**
```
404, message='Not Found', url=URL('https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/')
```

**Problem**: The rulebook was trying to access `/api/v2/config/` (old AAP 2.4 path)

**Solution**: AAP 2.5+ uses `/api/controller/v2/config/` instead

**Good News**: The built-in EDA credential type handles this automatically! You just need to:
1. Use the correct base URL (which you now have)
2. Provide a valid token
3. The credential type will use the correct API path

---

## Troubleshooting

### Issue: Still getting 404 errors

**Check:**
1. Verify you're using the base URL without `/api/v2/`:
   - ✅ Correct: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
   - ❌ Wrong: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/v2/`

2. Ensure trailing slash is present:
   - ✅ Correct: `https://...com/`
   - ❌ Wrong: `https://...com`

### Issue: Authentication failed

**Solutions:**
1. Verify token is valid:
   ```bash
   curl -k -H "Authorization: Bearer YOUR_TOKEN" \
     https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/controller/v2/me/
   ```

2. Check token hasn't expired
3. Regenerate token if needed
4. Verify token has "Write" scope

### Issue: Permission denied when launching job

**Solutions:**
1. Verify user has permission to execute the job template
2. Check organization access
3. Ensure user is in appropriate team/role

---

## Configuration Summary

### ✅ Checklist

- [ ] Personal access token created in AAP Controller
- [ ] Token copied and stored securely
- [ ] AAP Controller credential created in EDA
- [ ] Credential uses correct URL: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
- [ ] Credential attached to rulebook activation
- [ ] Rulebook activation restarted successfully
- [ ] No 404 errors in activation logs
- [ ] Test event sent successfully
- [ ] Job template launched successfully

### 📋 Your Configuration

```yaml
# AAP Unified Gateway
aap_url: "https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/"
aap_version: "2.5+"
architecture: "Unified Gateway"

# API Endpoints
controller_api: "/api/controller/v2/"
eda_api: "/api/eda/v1/"

# Credential
credential_name: "AAP Controller - Demo"
credential_type: "Red Hat Ansible Automation Platform"
controller_url: "https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/"

# Rulebook Activation
activation_name: "Terraform Infrastructure Handler"
credentials:
  - "HCP Vault - Demo"
  - "AAP Controller - Demo"
```

---

## Next Steps

✅ **Completed**: AAP Controller credential configured for Unified Gateway!

**Test the integration:**
1. Send a test event to the EDA event stream
2. Verify job template is triggered
3. Check job execution in Controller

See `docs/03-aap-setup.md` Step 10 for testing instructions.

---

## Additional Resources

- [AAP 2.5 Release Notes](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.5)
- [Unified Gateway Architecture](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.5/html/red_hat_ansible_automation_platform_architecture/index)
- [EDA Controller User Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.5/html/event-driven_ansible_controller_user_guide/)

---

**Made with Bob** 🤖