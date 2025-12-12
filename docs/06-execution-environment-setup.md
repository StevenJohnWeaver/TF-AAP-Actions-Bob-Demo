# Execution Environment Setup for OpenShift Deployment

The default AAP execution environment doesn't include the `kubernetes.core` collection needed for OpenShift deployments.

## Option 1: Use Red Hat's Supported EE (Recommended)

Red Hat provides execution environments with kubernetes support:

### Available Execution Environments:

1. **Automation Hub EE** (Recommended for production):
   - `registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest`
   - Includes: kubernetes.core, openshift, and other certified collections
   - Requires Red Hat registry authentication

2. **Community EE with Kubernetes**:
   - `quay.io/ansible/awx-ee:latest`
   - Includes kubernetes.core collection
   - No authentication required

3. **Minimal EE with Kubernetes**:
   - `quay.io/ansible/creator-ee:latest`
   - Lighter weight, includes kubernetes.core

## Setup Steps:

### Step 1: Add Execution Environment to AAP

1. **Go to AAP Web UI**: https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com

2. **Navigate to**: Administration → Execution Environments

3. **Click**: Add

4. **Configure**:
   - **Name**: `AWX EE with Kubernetes`
   - **Image**: `quay.io/ansible/awx-ee:latest`
   - **Pull**: Always pull container before running
   - **Description**: Execution environment with kubernetes.core collection

5. **Click**: Save

### Step 2: Update Job Template

1. **Go to**: Resources → Templates

2. **Find**: "Deploy to OpenShift" template

3. **Click**: Edit

4. **Change**:
   - **Execution Environment**: Select `AWX EE with Kubernetes`

5. **Click**: Save

### Step 3: Test the Deployment

1. **Launch** the "Deploy to OpenShift" job template

2. **Verify** it now finds the kubernetes.core collection

## Option 2: Create Custom Execution Environment

If you need additional collections or customizations:

### Create execution-environment.yml:

```yaml
---
version: 3

images:
  base_image:
    name: quay.io/ansible/ansible-runner:latest

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  append_final:
    - RUN pip3 install kubernetes openshift
```

### Create requirements.yml:

```yaml
---
collections:
  - name: kubernetes.core
    version: ">=2.4.0"
  - name: community.general
  - name: ansible.posix
```

### Build and Push:

```bash
# Install ansible-builder
pip install ansible-builder

# Build the EE
ansible-builder build -t my-custom-ee:latest

# Tag for your registry
podman tag my-custom-ee:latest quay.io/your-username/my-custom-ee:latest

# Push to registry
podman push quay.io/your-username/my-custom-ee:latest
```

### Add to AAP:
Follow Step 1 above, using your custom image URL.

## Verification

After setting up the execution environment, verify it has the required collections:

### Method 1: Check in AAP Job Output

The job output will show:
```
Using execution environment: quay.io/ansible/awx-ee:latest
```

And won't show the "couldn't resolve module/action" error.

### Method 2: Test with a Simple Playbook

Create a test playbook:

```yaml
---
- hosts: localhost
  gather_facts: no
  tasks:
    - name: List available collections
      shell: ansible-galaxy collection list
      register: collections
    
    - name: Display collections
      debug:
        var: collections.stdout_lines
```

Look for `kubernetes.core` in the output.

## Troubleshooting

### Issue: Can't pull image from registry.redhat.io

**Solution**: Add registry credentials in AAP:
1. Go to: Administration → Credential Types
2. Create: Container Registry credential
3. Add: Red Hat registry credentials
4. Attach to Execution Environment

### Issue: Image pull takes too long

**Solution**: 
- Use a smaller image like `creator-ee`
- Or pre-pull the image on AAP nodes:
  ```bash
  podman pull quay.io/ansible/awx-ee:latest
  ```

### Issue: Collection version conflicts

**Solution**: Specify exact versions in custom EE requirements.yml

## Recommended Setup for This Demo

For the OpenShift deployment in this demo:

1. **Use**: `quay.io/ansible/awx-ee:latest`
2. **Why**: 
   - Includes kubernetes.core collection
   - No authentication required
   - Well-maintained by Ansible team
   - Works with OpenShift Sandbox

3. **Alternative**: Use the simplified playbook (`deploy-to-openshift-simple.yml`) that uses `oc` CLI instead of kubernetes.core collection

## Next Steps

After setting up the execution environment:

1. Update the "Deploy to OpenShift" job template to use the new EE
2. Sync your project to get the latest playbooks
3. Launch the job
4. Verify deployment to OpenShift Sandbox

The kubernetes.core collection will now be available, and the playbook will work correctly!