# OpenShift Deployment Setup

Since AAP doesn't support `import_playbook` in job templates, we need to create a separate job template for OpenShift deployment.

## Step 1: Create OpenShift Deployment Job Template

1. **Go to AAP Web UI**: https://sandbox-aap-steveweaver-hashi-dev.apps.rm2.thpm.p1.openshiftapps.com

2. **Navigate to**: Resources → Templates

3. **Click**: "Add" → "Add job template"

4. **Configure the template**:
   - **Name**: `Deploy to OpenShift`
   - **Job Type**: Run
   - **Inventory**: `AWS Dynamic Inventory` (same as main job)
   - **Project**: `TF-AAP-Actions-Bob-Demo` (your project)
   - **Playbook**: `playbooks/deploy-to-openshift.yml`
   - **Credentials**: 
     - Add: `HCP Vault - Demo` (Custom credential type)
     - Add: `EC2 SSH Key` (Machine credential) - if needed
   - **Variables**: Enable "Prompt on launch" for Extra Variables
   - **Options**: 
     - ✅ Enable Privilege Escalation (if needed)
     - ✅ Enable Concurrent Jobs

5. **Click**: Save

## Step 2: Test OpenShift Deployment Manually

1. **Go to**: Resources → Templates

2. **Find**: "Deploy to OpenShift" template

3. **Click**: Launch (rocket icon)

4. **Provide Extra Variables** (if prompted):
```yaml
---
terraform_run_id: "manual-test"
terraform_workspace: "default"
terraform_organization: "your-org"
vpc_id: "vpc-xxxxx"
vpc_cidr: "10.0.0.0/16"
aws_region: "us-east-1"
instances:
  - name: "app-server-1"
    id: "i-09f3d99096d308fdd"
    private_ip: "10.0.1.170"
    public_ip: "98.94.232.242"
  - name: "app-server-2"
    id: "i-0f9ef1a5717ed5481"
    private_ip: "10.0.2.xxx"
    public_ip: "54.xxx.xxx.xxx"
vault_address: "https://your-vault-url.com"
vault_namespace: "admin"
openshift_namespace: "steveweaver-hashi"
application_name: "terraform-demo"
replicas: 1
environment: "demo"
```

5. **Click**: Next → Launch

6. **Watch the job run** - it should:
   - Authenticate to Vault
   - Get OpenShift credentials
   - Deploy nginx to OpenShift
   - Create route and display URL

## Step 3: Get the Application URL

After successful deployment, the job output will show:
```
Application URL: https://terraform-demo-steveweaver-hashi.apps.rm2.thpm.p1.openshiftapps.com
```

Access this URL in your browser to see the OpenShift-deployed application!

## Step 4: Automate with Workflow (Optional)

To run both jobs automatically:

1. **Create a Workflow Template**:
   - Go to: Resources → Templates → Add → Add workflow template
   - Name: `Full Infrastructure Deployment`

2. **Add Nodes**:
   - Node 1: "Configure AWS Infrastructure" (on success →)
   - Node 2: "Deploy to OpenShift"

3. **Configure Node 2** to use output from Node 1:
   - Pass variables from first job to second job
   - Use "Extra Variables" to pass instance details

## Troubleshooting

### Issue: OpenShift token expired
**Solution**: Update token in Vault
```bash
vault kv patch secret/openshift/credentials token='<new-token>'
```

### Issue: Namespace doesn't exist
**Solution**: OpenShift Sandbox uses pre-created namespace `steveweaver-hashi`

### Issue: kubernetes.core collection not found
**Solution**: Ensure execution environment has kubernetes.core collection installed

### Issue: Can't connect to OpenShift API
**Solution**: 
- Verify token is valid: `oc login --token=$TOKEN --server=$API_URL`
- Check firewall allows connection to OpenShift API
- Verify API URL is correct

## Verification

After deployment, verify:

1. **Check OpenShift Console**:
   - Go to: https://console.redhat.com/openshift/sandbox
   - Navigate to your namespace: `steveweaver-hashi`
   - See the deployment, pods, and route

2. **Check via CLI**:
```bash
oc login --token=<your-token> --server=https://api.rm2.thpm.p1.openshiftapps.com:6443
oc get pods -n steveweaver-hashi
oc get route -n steveweaver-hashi
```

3. **Access the application**:
   - Get route URL from job output or: `oc get route terraform-demo -n steveweaver-hashi`
   - Open in browser
   - Should see similar page to EC2 version but with OpenShift details

## Complete Integration Flow

```
Terraform Cloud
    ↓ (provisions infrastructure)
AWS EC2 Instances
    ↓ (triggers via aap_job_launch)
AAP Job: "Configure AWS Infrastructure"
    ↓ (configures instances)
EC2 Running nginx
    ↓ (manual trigger or workflow)
AAP Job: "Deploy to OpenShift"
    ↓ (deploys to OpenShift)
OpenShift Running nginx
    ✅ Complete!
```

Both EC2 and OpenShift now serve the demo application with secrets from Vault!