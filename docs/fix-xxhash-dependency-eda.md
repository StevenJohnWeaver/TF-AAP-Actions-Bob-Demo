# Fix xxhash Dependency in EDA Decision Environment

The EDA rulebook requires the `xxhash` Python module for the `ansible.eda.generic` source plugin to work with event streams.

---

## Problem

**Error**: `No module named 'xxhash'`

**Root Cause**: The default EDA decision environment doesn't include the `xxhash` Python package, which is required by the PostgreSQL listener that backs the event stream functionality.

---

## Solution Options

### Option 1: Use Custom Decision Environment (Recommended)

Create a custom decision environment with the required dependencies.

#### Step 1: Create Execution Environment Definition

Create a file `execution-environment.yml`:

```yaml
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/de-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_final:
    - RUN pip3 install --upgrade pip
  append_final:
    - RUN pip3 install xxhash psycopg2-binary

options:
  package_manager_path: /usr/bin/microdnf
```

#### Step 2: Build Custom Decision Environment

```bash
# Install ansible-builder if not already installed
pip install ansible-builder

# Build the custom decision environment
ansible-builder build \
  --tag quay.io/your-org/custom-eda-de:latest \
  --container-runtime podman

# Push to registry
podman push quay.io/your-org/custom-eda-de:latest
```

#### Step 3: Create Decision Environment in EDA

1. **Navigate to EDA Controller**
   - Go to: `https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com/`
   - Click **"Event-Driven Ansible"**

2. **Create Decision Environment**
   - Go to **"Decision Environments"**
   - Click **"Create decision environment"**
   - Configure:
     - **Name**: `Custom EDA DE with xxhash`
     - **Description**: `Custom decision environment with xxhash and psycopg2`
     - **Image**: `quay.io/your-org/custom-eda-de:latest`
     - **Pull Policy**: `Always`

3. **Update Rulebook Activation**
   - Go to **"Rulebook Activations"**
   - Edit **"Terraform Infrastructure Handler"**
   - Change **"Decision Environment"** to: `Custom EDA DE with xxhash`
   - Save and restart

---

### Option 2: Request Admin to Install Dependencies

If you don't have access to build custom images, ask your AAP administrator to:

#### Install xxhash in Default Decision Environment

```bash
# SSH to AAP cluster or use oc exec
oc exec -it deployment/eda-api -- bash

# Install xxhash in the decision environment
pip3 install xxhash psycopg2-binary

# Or modify the decision environment image
```

#### Update Default Decision Environment

The admin can update the default decision environment to include these dependencies.

---

### Option 3: Use Alternative Source Plugin (Temporary)

While waiting for the dependency fix, you can temporarily use a different source:

#### Update Rulebook to Use File Source

```yaml
sources:
  - name: Listen to Terraform event stream
    ansible.eda.file:
      path: /tmp/terraform-events.json
      format: json
```

This requires manually placing event files, so it's only for testing.

---

## Verification Steps

### Test 1: Check if xxhash is Available

```bash
# In the decision environment container
python3 -c "import xxhash; print('xxhash available')"
```

### Test 2: Check Rulebook Activation Logs

After updating the decision environment:

1. Restart the rulebook activation
2. Check logs for:
   - ✅ **Good**: `Job activation-job-X-Y is running` (no xxhash errors)
   - ❌ **Bad**: `No module named 'xxhash'`

### Test 3: Test Event Stream Connection

The activation should successfully connect to the event stream without dependency errors.

---

## Troubleshooting

### Issue: Can't build custom decision environment

**Solutions:**
1. **Use Podman/Docker locally**:
   ```bash
   # Install podman or docker
   # Build locally and push to accessible registry
   ```

2. **Use OpenShift BuildConfig**:
   ```yaml
   apiVersion: build.openshift.io/v1
   kind: BuildConfig
   metadata:
     name: custom-eda-de
   spec:
     source:
       dockerfile: |
         FROM registry.redhat.io/ansible-automation-platform-24/de-supported-rhel8:latest
         RUN pip3 install xxhash psycopg2-binary
     strategy:
       dockerStrategy: {}
     output:
       to:
         kind: ImageStreamTag
         name: custom-eda-de:latest
   ```

### Issue: Permission denied to create decision environment

**Solutions:**
1. Ask AAP administrator for permissions
2. Use existing decision environment with dependencies pre-installed
3. Request admin to install dependencies in default DE

### Issue: Image pull fails

**Solutions:**
1. Verify image registry is accessible from AAP cluster
2. Check image pull secrets are configured
3. Use internal registry if external registry is blocked

---

## Alternative: Modify Existing Decision Environment

If you have cluster admin access:

### Step 1: Create Custom Image with Dependencies

```dockerfile
FROM registry.redhat.io/ansible-automation-platform-24/de-supported-rhel8:latest

USER root

# Install xxhash and psycopg2
RUN pip3 install --upgrade pip && \
    pip3 install xxhash psycopg2-binary

USER 1000
```

### Step 2: Build and Push

```bash
podman build -t quay.io/your-org/eda-de-with-xxhash:latest .
podman push quay.io/your-org/eda-de-with-xxhash:latest
```

### Step 3: Update EDA Configuration

Update the EDA deployment to use the new image:

```bash
# Edit the EDA deployment
oc edit deployment eda-api -n ansible-automation-platform

# Update the image reference
spec:
  template:
    spec:
      containers:
      - name: eda-api
        image: quay.io/your-org/eda-de-with-xxhash:latest
```

---

## Quick Fix for Testing

If you need a quick test and have cluster access:

```bash
# Install xxhash directly in running pod
oc exec -it $(oc get pods -l app=eda-api -o name | head -1) -- pip3 install xxhash psycopg2-binary

# Restart the activation
# This is temporary - will be lost when pod restarts
```

---

## Configuration Summary

### ✅ Checklist

- [ ] Custom decision environment created with xxhash
- [ ] Decision environment pushed to accessible registry
- [ ] Decision environment created in EDA Controller
- [ ] Rulebook activation updated to use custom DE
- [ ] Activation restarted successfully
- [ ] No xxhash errors in logs
- [ ] Event stream connection working

### 📋 Required Dependencies

```txt
# Python packages needed
xxhash>=3.0.0
psycopg2-binary>=2.9.0

# System packages (if needed)
postgresql-devel
gcc
python3-devel
```

---

## Next Steps

1. **Choose your approach** (custom DE, admin request, or temporary fix)
2. **Implement the solution**
3. **Sync EDA project** to get latest rulebook
4. **Restart rulebook activation** with proper decision environment
5. **Test event stream integration**

Once the xxhash dependency is resolved, the EDA rulebook should successfully connect to the event stream and be ready to receive events from Terraform Actions.

---

## Additional Resources

- [Ansible Builder Documentation](https://ansible-builder.readthedocs.io/)
- [EDA Decision Environments](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4/html/event-driven_ansible_controller_user_guide/eda-decision-environments)
- [Container Image Building](https://docs.openshift.com/container-platform/latest/cicd/builds/understanding-image-builds.html)

---

**Made with Bob** 🤖