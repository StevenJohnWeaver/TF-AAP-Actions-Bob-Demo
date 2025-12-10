# Finding AAP Controller URL Without OpenShift Permissions

If you don't have permissions to list routes in the `ansible-automation-platform` namespace, you can still find the Controller URL using these alternative methods.

---

## Method 1: Use the AAP Console URL Directly (Easiest)

**The URL you use to access AAP Controller IS the Controller URL!**

1. **Open your browser and go to AAP Controller**
   - This is where you see Jobs, Templates, Inventories, Projects
   - NOT the EDA interface (which shows Rulebook Activations)

2. **Copy the URL from your browser's address bar**
   - Example: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`
   - This is your Controller URL!

3. **Verify it's the Controller (not EDA)**
   - Controller shows: Jobs, Templates, Inventories, Projects, Credentials
   - EDA shows: Rulebook Activations, Event Streams, Decision Environments

4. **Use this URL in your EDA credential**
   - Make sure it ends with `/`
   - Example: `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`

---

## Method 2: Check Your Browser Bookmarks/History

If you've accessed AAP Controller before:

1. **Check browser history**
   - Look for URLs containing "controller" or "aap"
   - Avoid URLs with "eda" in them

2. **Common patterns:**
   - `https://sandbox-aap-controller.apps.DOMAIN/`
   - `https://aap-controller.apps.DOMAIN/`
   - `https://automation-controller.apps.DOMAIN/`

---

## Method 3: Ask Your OpenShift/AAP Administrator

Contact your cluster administrator and ask for:

1. **The AAP Controller URL**
   - They can provide the exact URL
   - Or grant you view permissions for the namespace

2. **Request permissions (if needed):**
   ```
   Please grant me view access to routes in the ansible-automation-platform namespace
   ```

---

## Method 4: Try Common URL Patterns

Based on your error message showing you're on a cluster with domain `*.apps.rm2.thpm.p1.openshiftapps.com`, try these URLs:

### Test these URLs in your browser:

1. `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`
2. `https://aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`
3. `https://automation-controller.apps.rm2.thpm.p1.openshiftapps.com/`

### How to test:

```bash
# Test if URL is accessible
curl -k https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/

# If you get JSON response (not 404), that's the correct URL!
```

---

## Method 5: Check OpenShift Web Console (If You Have Access)

Even without CLI permissions, you might have web console access:

1. **Log in to OpenShift Web Console**
   - URL format: `https://console-openshift-console.apps.rm2.thpm.p1.openshiftapps.com`

2. **Navigate to Routes**
   - Click **"Networking"** → **"Routes"**
   - Select project: `ansible-automation-platform`

3. **Find Controller Route**
   - Look for routes with "controller" in the name
   - Click to see the full URL

---

## Method 6: Check Your EDA Error Message

Looking at your original error:
```
url=URL('https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/')
```

This URL appears to be the **EDA** route (notice "steveweaver-hashi-dev").

The **Controller** URL is likely:
- `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`

Or possibly:
- `https://sandbox-aap.apps.rm2.thpm.p1.openshiftapps.com/`

---

## Verification Steps

Once you think you have the Controller URL, verify it:

### Test 1: Check the API endpoint

```bash
# Should return JSON config (not 404)
curl -k https://YOUR-CONTROLLER-URL/api/v2/config/

# Example:
curl -k https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/
```

**Expected response:**
```json
{
  "time_zone": "UTC",
  "license_info": {...},
  "version": "4.4.0",
  ...
}
```

**If you get 404:** Wrong URL, try another pattern

### Test 2: Open in Browser

1. Open the URL in your browser
2. You should see the AAP Controller login page
3. After login, you should see:
   - Jobs
   - Templates
   - Inventories
   - Projects
   - Credentials

**If you see Rulebook Activations:** That's EDA, not Controller!

---

## Quick Fix for Your Situation

Based on your error message, try this:

### Step 1: Test the likely Controller URL

```bash
# Test this URL
curl -k https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/api/v2/config/
```

### Step 2: If that works, update your EDA credential

1. Go to EDA Controller: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/eda`
2. Navigate to **Credentials**
3. Edit **"AAP Controller - Demo"**
4. Update **"Red Hat Ansible Automation Platform"** field to:
   ```
   https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/
   ```
5. Save and restart your rulebook activation

### Step 3: Verify the fix

Check the rulebook activation logs - the 404 error should be gone!

---

## Alternative: Get URL from AAP Team

If you're working with a team, ask them:

**Question to ask:**
> "What is the AAP Controller URL for our cluster? I need it to configure EDA credentials."

**They should provide something like:**
> `https://sandbox-aap-controller.apps.rm2.thpm.p1.openshiftapps.com/`

---

## Summary

**You don't need OpenShift CLI permissions to find the Controller URL!**

**Easiest methods:**
1. ✅ Use the URL you access AAP Controller with in your browser
2. ✅ Test common URL patterns based on your cluster domain
3. ✅ Ask your AAP/OpenShift administrator

**The key difference:**
- ❌ EDA URL: `https://sandbox-aap-steveweaver-hashi-dev.apps...` (has your username or "eda")
- ✅ Controller URL: `https://sandbox-aap-controller.apps...` (has "controller")

---

## Next Steps

Once you have the correct Controller URL:

1. Update your EDA credential with the correct URL
2. Restart the rulebook activation
3. Check logs - no more 404 errors!
4. Test with a sample event

See `docs/aap-controller-credential-setup.md` for complete credential setup instructions.

---

**Made with Bob** 🤖