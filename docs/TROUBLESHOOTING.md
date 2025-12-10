# Troubleshooting Guide

This guide helps resolve common issues when setting up the Red Hat + HashiCorp demo.

## Table of Contents
- [HCP Vault Issues](#hcp-vault-issues)
- [HCP Terraform Issues](#hcp-terraform-issues)
- [AAP/EDA Issues](#aapeda-issues)
- [AWS Issues](#aws-issues)

---

## HCP Vault Issues

### Issue: "No value found at aws/config/root"

**Symptoms:**
```bash
vault read aws/config/root
No value found at aws/config/root
```

**Cause:** The AWS secrets engine wasn't configured with root credentials during setup.

**Solution:**

1. Verify your AWS credentials are set:
```bash
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

2. Run the fix script:
```bash
cd vault/scripts
./fix-aws-secrets.sh
```

3. Verify the configuration:
```bash
vault read aws/config/root
```

### Issue: "Role 'terraform-provisioner' not found"

**Symptoms:**
```bash
vault read aws/creds/terraform-provisioner
Error: Role "terraform-provisioner" not found
```

**Cause:** The AWS role wasn't created during setup.

**Solution:**

1. Run the fix script (it will create both roles):
```bash
cd vault/scripts
./fix-aws-secrets.sh
```

2. Verify roles exist:
```bash
vault list aws/roles
```

You should see:
- `terraform-provisioner`
- `ansible-configurator`

3. Test credential generation:
```bash
vault read aws/creds/terraform-provisioner
```

### Issue: "Permission denied" when creating AWS credentials

**Symptoms:**
```bash
vault read aws/creds/terraform-provisioner
Error making API request.
Code: 403. Errors:
* permission denied
```

**Cause:** Your Vault token doesn't have the necessary permissions.

**Solution:**

1. Check your current token's policies:
```bash
vault token lookup
```

2. If using the admin token, ensure you're in the correct namespace:
```bash
export VAULT_NAMESPACE="admin"
```

3. If using a generated token, ensure it has the `terraform-policy`:
```bash
vault token create -policy=terraform-policy -ttl=24h
```

### Issue: AWS IAM errors when generating credentials

**Symptoms:**
```bash
vault read aws/creds/terraform-provisioner
Error: error creating IAM user: AccessDenied
```

**Cause:** The AWS credentials provided to Vault don't have sufficient IAM permissions.

**Solution:**

1. Verify your AWS user has these IAM permissions:
   - `iam:CreateUser`
   - `iam:CreateAccessKey`
   - `iam:PutUserPolicy`
   - `iam:DeleteUser`
   - `iam:DeleteAccessKey`
   - `iam:DeleteUserPolicy`

2. Update the AWS root credentials in Vault:
```bash
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=us-east-1
```

### Issue: "Namespace not found"

**Symptoms:**
```bash
Error making API request.
Namespace: admin/
Code: 404. Errors:
* namespace not found
```

**Cause:** HCP Vault uses the `admin` namespace by default, but it might not be set.

**Solution:**

1. Set the namespace environment variable:
```bash
export VAULT_NAMESPACE="admin"
```

2. Add it to your shell profile for persistence:
```bash
echo 'export VAULT_NAMESPACE="admin"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc
```

---

## HCP Terraform Issues

### Issue: "Invalid resource type: aap_eda_eventstream_post"

**Symptoms:**
```
Error: Invalid resource type
on main.tf line X:
resource "aap_eda_eventstream_post" "infrastructure_ready" {
```

**Cause:** Using old syntax - this should be an `action` block, not a `resource`.

**Solution:** This has been fixed in the latest code. Pull the latest changes:
```bash
git pull origin main
```

### Issue: "No valid credential sources found"

**Symptoms:**
```
Error: No valid credential sources found
with provider["registry.terraform.io/hashicorp/aws"]
```

**Cause:** Terraform can't authenticate to AWS via Vault.

**Solution:**

1. Verify Vault token is set in HCP Terraform workspace variables:
   - Variable name: `hcp_vault_token`
   - Value: Your Terraform token from Vault setup
   - Mark as sensitive: Yes

2. Verify Vault address is correct:
   - Variable name: `hcp_vault_addr`
   - Value: Your HCP Vault cluster URL

3. Test Vault connection manually:
```bash
export VAULT_ADDR="https://your-cluster.vault.hashicorp.cloud:8200"
export VAULT_TOKEN="your-terraform-token"
export VAULT_NAMESPACE="admin"
vault read aws/creds/terraform-provisioner
```

### Issue: Terraform Actions not triggering AAP

**Symptoms:** Terraform completes successfully but AAP job template doesn't run.

**Cause:** Multiple possible causes:
1. AAP credentials incorrect
2. Event stream name mismatch
3. Network connectivity issues

**Solution:**

1. Verify AAP variables in HCP Terraform:
   - `aap_host`: Should be your AAP controller URL (no trailing slash)
   - `aap_username`: AAP admin username
   - `aap_password`: AAP admin password (marked sensitive)
   - `eda_event_stream_name`: Should match the event stream in AAP (default: `terraform-infrastructure-events`)

2. Test AAP connectivity:
```bash
curl -k -u admin:password https://your-aap-host/api/v2/ping/
```

3. Check EDA event stream exists:
```bash
curl -k -u admin:password https://your-aap-host/api/eda/v1/event-streams/
```

---

## AAP/EDA Issues

### Issue: EDA rulebook not activating

**Symptoms:** Rulebook shows as "stopped" or "failed" in AAP.

**Cause:** Configuration error in the rulebook or missing event stream.

**Solution:**

1. Check EDA controller logs in AAP UI:
   - Navigate to Event-Driven Ansible → Rulebook Activations
   - Click on your activation
   - Check the "Output" tab for errors

2. Verify event stream exists:
   - Navigate to Event-Driven Ansible → Event Streams
   - Ensure `terraform-infrastructure-events` exists
   - Note the exact name (case-sensitive)

3. Verify rulebook syntax:
```bash
ansible-rulebook --rulebook extensions/eda/rulebooks/terraform-infrastructure-trigger.yml --check
```

### Issue: "Job template not found"

**Symptoms:** EDA activation fails with "Job template 'Configure AWS Infrastructure' not found"

**Cause:** The job template referenced in the rulebook doesn't exist in AAP.

**Solution:**

1. Create the job template in AAP:
   - Name: `Configure AWS Infrastructure`
   - Project: Your project with the playbooks
   - Playbook: `playbooks/configure-infrastructure.yml`
   - Inventory: Create a blank inventory (will be populated dynamically)
   - Credentials: Add Vault credentials

2. Verify the name matches exactly (case-sensitive) in:
   - AAP job template name
   - EDA rulebook (`job_template_name`)
   - Terraform action config (`job_template_name`)

### Issue: Vault authentication fails in playbook

**Symptoms:** Playbook fails with "Unable to authenticate to Vault"

**Cause:** Vault credentials not configured in AAP.

**Solution:**

1. Create Vault credential in AAP:
   - Credential Type: HashiCorp Vault Secret Lookup
   - Vault Server URL: Your HCP Vault URL
   - Namespace: `admin`
   - Authentication Method: AppRole
   - Role ID: From Vault setup output
   - Secret ID: From Vault setup output

2. Attach credential to job template:
   - Edit job template
   - Add the Vault credential
   - Save

---

## AWS Issues

### Issue: "UnauthorizedOperation" errors

**Symptoms:**
```
Error: UnauthorizedOperation: You are not authorized to perform this operation
```

**Cause:** AWS credentials don't have sufficient permissions.

**Solution:**

1. Verify the IAM user/role has the required permissions from `vault/policies/terraform-aws-policy.json`

2. Test AWS credentials directly:
```bash
aws sts get-caller-identity
aws ec2 describe-vpcs --region us-east-1
```

3. If using Vault-generated credentials, verify the role policy:
```bash
vault read aws/roles/terraform-provisioner
```

### Issue: "Rate limit exceeded"

**Symptoms:**
```
Error: Error creating IAM User: LimitExceeded: Cannot exceed quota for UsersPerAccount
```

**Cause:** Too many IAM users created by Vault (AWS has a default limit of 5000).

**Solution:**

1. List and clean up old Vault-generated users:
```bash
aws iam list-users | grep vault-token
```

2. Delete old users (be careful!):
```bash
# List users created by Vault
aws iam list-users --query 'Users[?starts_with(UserName, `vault-token`)].UserName' --output text

# Delete specific user (replace USERNAME)
aws iam delete-user --user-name USERNAME
```

3. Consider using STS credentials instead of IAM users:
```bash
vault write aws/roles/terraform-provisioner \
    credential_type=assumed_role \
    role_arns=arn:aws:iam::ACCOUNT_ID:role/TerraformRole
```

---

## General Debugging Tips

### Enable Verbose Logging

**Vault:**
```bash
export VAULT_LOG_LEVEL=debug
vault read aws/creds/terraform-provisioner
```

**Terraform:**
```bash
export TF_LOG=DEBUG
terraform plan
```

**Ansible:**
```bash
ansible-playbook playbooks/configure-infrastructure.yml -vvv
```

### Check Connectivity

**Test Vault:**
```bash
vault status
vault token lookup
```

**Test AAP:**
```bash
curl -k https://your-aap-host/api/v2/ping/
```

**Test AWS:**
```bash
aws sts get-caller-identity
```

### Verify Environment Variables

Create a script to check all required variables:

```bash
#!/bin/bash
echo "=== Vault ==="
echo "VAULT_ADDR: ${VAULT_ADDR:-NOT SET}"
echo "VAULT_TOKEN: ${VAULT_TOKEN:+SET (hidden)}"
echo "VAULT_NAMESPACE: ${VAULT_NAMESPACE:-NOT SET}"

echo -e "\n=== AWS ==="
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:+SET (hidden)}"
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:+SET (hidden)}"
echo "AWS_REGION: ${AWS_REGION:-NOT SET}"

echo -e "\n=== AAP ==="
echo "AAP_HOST: ${AAP_HOST:-NOT SET}"
echo "AAP_USERNAME: ${AAP_USERNAME:-NOT SET}"
echo "AAP_PASSWORD: ${AAP_PASSWORD:+SET (hidden)}"
```

---

## Getting Help

If you're still experiencing issues:

1. Check the logs in each component:
   - HCP Vault: Audit logs in HCP Portal
   - HCP Terraform: Run logs in workspace
   - AAP: Job output and EDA activation logs
   - AWS: CloudTrail for API calls

2. Review the documentation:
   - `docs/01-hcp-terraform-setup.md`
   - `docs/02-hcp-vault-setup.md`
   - `docs/03-aap-setup.md`

3. Verify all prerequisites are met:
   - HCP Terraform workspace created and configured
   - HCP Vault cluster running and accessible
   - AAP controller accessible and configured
   - AWS credentials valid and have required permissions

4. Test each integration point separately:
   - Vault → AWS (generate credentials manually)
   - Terraform → Vault (test in local Terraform first)
   - Terraform → AAP (test event stream posting manually)
   - AAP → Vault (test playbook with Vault lookup)

---

**Last Updated:** 2025-12-09
**Version:** 1.0.0