# Troubleshooting AAP Job Failures

## "Task was marked as running at system start up" Error

This error occurs when AAP services restart while a job is running, leaving the job in a "stuck" state.

### Quick Fix - Clear Stuck Jobs

```bash
# SSH into your AAP controller
ssh <your-aap-controller>

# Check AAP services status
sudo systemctl status automation-controller

# Check for stuck jobs in the database
sudo -u awx awx-manage list_instances

# Clear stuck jobs (this resets jobs marked as running)
sudo -u awx awx-manage cleanup_jobs --days=0

# Restart AAP services
sudo systemctl restart automation-controller
```

### Alternative - Using AAP CLI

```bash
# Install awxkit if not already installed
pip3 install awxkit

# Set environment variables
export CONTROLLER_HOST=https://your-aap-controller.com
export CONTROLLER_USERNAME=admin
export CONTROLLER_PASSWORD=your-password

# List running jobs
awx jobs list --status running

# Cancel stuck jobs
awx jobs cancel <job-id>
```

### Root Causes and Solutions

#### 1. **Execution Environment Issues**
**Symptom**: Jobs fail immediately or hang
**Solution**:
```bash
# Check execution environment logs
podman logs <container-id>

# Verify EE can pull images
podman pull quay.io/ansible/awx-ee:latest

# Check disk space (EE needs space for containers)
df -h
```

#### 2. **Database Connection Issues**
**Symptom**: Jobs start but never complete
**Solution**:
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Restart database if needed
sudo systemctl restart postgresql
sudo systemctl restart automation-controller
```

#### 3. **Resource Constraints**
**Symptom**: Jobs timeout or system becomes unresponsive
**Solution**:
```bash
# Check system resources
free -h
top
df -h

# Check AAP capacity
awx-manage list_instances

# Adjust job concurrency in AAP UI:
# Settings → Jobs → Job Execution → Capacity Adjustment
```

#### 4. **Network/Firewall Issues**
**Symptom**: Jobs hang when connecting to external resources
**Solution**:
```bash
# Test connectivity from AAP controller
curl -v https://api.rm2.thpm.p1.openshiftapps.com:6443
curl -v https://vault.example.com

# Check firewall rules
sudo firewall-cmd --list-all

# Test from execution environment
podman run --rm -it quay.io/ansible/awx-ee:latest bash
curl -v https://api.rm2.thpm.p1.openshiftapps.com:6443
```

### Debugging Job Failures

#### 1. **Enable Verbose Logging**
In your Job Template:
- Set "Verbosity" to 3 (Debug) or 4 (Connection Debug)
- Enable "Show Changes"

#### 2. **Check Job Output**
```bash
# View job output in real-time
awx jobs monitor <job-id>

# Get job events
awx job_events list --job <job-id>

# Export job output
awx jobs stdout <job-id> > job-output.txt
```

#### 3. **Check AAP Logs**
```bash
# Controller logs
sudo journalctl -u automation-controller -f

# Dispatcher logs
sudo tail -f /var/log/tower/dispatcher.log

# Task manager logs
sudo tail -f /var/log/tower/task_system.log

# Receptor logs (for execution environments)
sudo journalctl -u receptor -f
```

#### 4. **Test Playbook Manually**
```bash
# SSH to AAP controller
ssh <aap-controller>

# Run playbook manually with same credentials
ansible-playbook -i inventory playbooks/configure-infrastructure.yml \
  -e "terraform_run_id=test" \
  -e "vpc_id=vpc-123" \
  -vvv
```

### Preventive Measures

#### 1. **Set Job Timeouts**
In Job Template settings:
- Set reasonable timeout values (e.g., 30 minutes)
- Enable "Timeout" option

#### 2. **Configure Job Slicing**
For large inventories:
- Enable "Job Slicing" in Job Template
- Set slice count based on inventory size

#### 3. **Monitor System Health**
```bash
# Create monitoring script
cat > /usr/local/bin/aap-health-check.sh << 'EOF'
#!/bin/bash
echo "=== AAP Health Check ==="
echo "Services:"
systemctl is-active automation-controller receptor postgresql
echo ""
echo "Disk Space:"
df -h | grep -E '(Filesystem|/var)'
echo ""
echo "Memory:"
free -h
echo ""
echo "Running Jobs:"
sudo -u awx awx-manage list_instances
EOF

chmod +x /usr/local/bin/aap-health-check.sh

# Run periodically
watch -n 60 /usr/local/bin/aap-health-check.sh
```

### Common Issues with This Demo

#### Issue: Vault Authentication Fails
**Check**:
```bash
# Verify Vault credentials in AAP
# Settings → Credentials → HCP Vault - Demo

# Test Vault connection
curl -H "X-Vault-Namespace: admin" \
     -H "X-Vault-Token: $VAULT_TOKEN" \
     $VAULT_ADDR/v1/sys/health
```

#### Issue: AWS Dynamic Inventory Returns 0 Hosts
**Check**:
```bash
# Verify AWS credentials
# Settings → Credentials → AWS

# Test AWS connection
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:ManagedBy,Values=terraform"

# Check inventory source sync
awx inventory_sources list
awx inventory_sources update <source-id>
```

#### Issue: SSH Connection to EC2 Fails
**Check**:
```bash
# Verify EC2 instances are in public subnets
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].SubnetId'

# Verify security group allows SSH from AAP
aws ec2 describe-security-groups --group-ids <sg-id>

# Test SSH manually
ssh -i /path/to/key ec2-user@<public-ip>
```

#### Issue: OpenShift Deployment Fails
**Check**:
```bash
# Verify OpenShift token is valid
oc login --token=$OPENSHIFT_TOKEN --server=$OPENSHIFT_API_URL

# Check token expiration (Sandbox tokens expire after 24 hours)
oc whoami -t

# Verify namespace exists
oc get namespace steveweaver-hashi

# Check kubernetes.core collection is installed in EE
podman run --rm quay.io/ansible/awx-ee:latest \
  ansible-galaxy collection list | grep kubernetes
```

### Getting Help

If issues persist:

1. **Check AAP Logs**: Most detailed information is in the logs
2. **Review Job Output**: Look for the last successful task before failure
3. **Test Components Individually**: Vault, AWS, OpenShift separately
4. **Simplify Playbook**: Comment out sections to isolate the problem
5. **Check AAP Documentation**: https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/

### Emergency Recovery

If AAP becomes completely unresponsive:

```bash
# Stop all services
sudo systemctl stop automation-controller receptor

# Clear stuck jobs
sudo -u awx awx-manage cleanup_jobs --days=0

# Clear old job artifacts
sudo find /var/lib/awx/job_status -type f -mtime +1 -delete

# Restart services
sudo systemctl start postgresql
sudo systemctl start receptor
sudo systemctl start automation-controller

# Verify services are running
sudo systemctl status automation-controller