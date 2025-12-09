# Security Improvements Plan for Terraform-AAP Integration

## Executive Summary

This document outlines critical security vulnerabilities identified in the current Terraform configuration and provides actionable recommendations to improve the security posture of your EC2-AAP infrastructure.

---

## 🔴 Critical Security Issues Identified

### 1. Overly Permissive Security Group Rules

**Current Issue (Lines 98-109 in [`main.tf`](terraform/main.tf:98-109)):**
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ⚠️ CRITICAL: Allows SSH from anywhere
}
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ⚠️ WARNING: Allows HTTP from anywhere
}
```

**Risk Level:** 🔴 **CRITICAL**

**Impact:**
- SSH port 22 exposed to the entire internet increases attack surface for brute force attacks
- Potential unauthorized access to EC2 instances
- Compliance violations (PCI-DSS, SOC 2, HIPAA)
- Increased vulnerability to zero-day exploits

---

### 2. Disabled TLS Certificate Verification

**Current Issue (Lines 23, 165 in [`main.tf`](terraform/main.tf:23)):**
```hcl
provider "aap" {
  host     = var.aap_host
  insecure_skip_verify = true  # ⚠️ CRITICAL: Disables TLS verification
  username = var.aap_username
  password = var.aap_password
}

event_stream_config = {
  url = var.aap_eventstream_url
  insecure_skip_verify = true  # ⚠️ CRITICAL: Disables TLS verification
  username = var.tf-es-username
  password = var.tf-es-password
}
```

**Risk Level:** 🔴 **CRITICAL**

**Impact:**
- Vulnerable to Man-in-the-Middle (MITM) attacks
- Credentials transmitted without proper certificate validation
- Potential for credential interception
- Compliance violations

---

### 3. Inconsistent Variable Naming

**Current Issue (Lines 52-62 in [`main.tf`](terraform/main.tf:52-62)):**
```hcl
variable "tf-es-username" {  # ⚠️ Uses hyphens (non-standard)
  description = "The username for the AAP instance"
  type        = string
  sensitive   = true
}

variable "tf-es-password" {  # ⚠️ Uses hyphens (non-standard)
  description = "The username for the AAP instance"  # ⚠️ Copy-paste error in description
  type        = string
  sensitive   = true
}
```

**Risk Level:** 🟡 **MEDIUM**

**Impact:**
- Harder to reference in HCL expressions
- Inconsistent with Terraform naming conventions
- Copy-paste error in description could lead to confusion

---

## ✅ Recommended Security Improvements

### Priority 1: Restrict Security Group Access

#### Option A: AAP-Only SSH Access (Recommended for Production)

```hcl
# Data source to get AAP server IP
data "external" "aap_ip" {
  program = ["bash", "-c", "echo '{\"ip\":\"'$(dig +short ${var.aap_host} | head -n1)'\"}'"]
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "web-server-sg"
  description = "Allow SSH from AAP, HTTP from anywhere, all outbound traffic"

  # SSH access restricted to AAP server only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.aap_ip.result.ip}/32"]
    description = "SSH access from AAP server only"
  }

  # HTTP access from anywhere (for web traffic)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  # HTTPS access (recommended to add)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "web-server-sg"
    ManagedBy = "Terraform"
  }
}
```

#### Option B: AWS Systems Manager Session Manager (Best Practice)

**Benefits:**
- No SSH port exposure required
- Centralized access logging via CloudTrail
- IAM-based access control
- No need to manage SSH keys

```hcl
# IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# Update EC2 instance to use SSM
resource "aws_instance" "web_server" {
  count                       = 3
  ami                         = "ami-0dfc569a8686b9320"
  instance_type               = "t2.micro"
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.allow_http_ssh.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name  # Add this
  
  # ... rest of configuration
}

# Security group without SSH port
resource "aws_security_group" "allow_http_ssh" {
  name        = "web-server-sg"
  description = "Allow HTTP/HTTPS inbound and all outbound traffic"

  # Remove SSH ingress rule entirely
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}
```

#### Option C: Parameterized CIDR Blocks (Flexible Approach)

```hcl
variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = []  # Empty by default, must be explicitly set
  
  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "At least one CIDR block must be specified for SSH access."
  }
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "web-server-sg"
  description = "Allow SSH from specified CIDRs, HTTP from anywhere"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access from approved sources"
  }

  # ... rest of configuration
}
```

---

### Priority 2: Enable TLS Certificate Verification

#### Step 1: Obtain Valid TLS Certificates for AAP

**Options:**
1. Use Let's Encrypt for free, automated certificates
2. Use your organization's internal CA
3. Purchase commercial certificates

#### Step 2: Update Terraform Configuration

```hcl
provider "aap" {
  host     = var.aap_host
  # Remove insecure_skip_verify or set to false
  insecure_skip_verify = false  # Enable TLS verification
  username = var.aap_username
  password = var.aap_password
}

action "aap_eda_eventstream_post" "create" {
  config {
    limit = "tfademo"
    template_type = "job"
    job_template_name = "New AWS Provisioning Workflow"
    organization_name = "Default"

    event_stream_config = {
      url = var.aap_eventstream_url
      insecure_skip_verify = false  # Enable TLS verification
      username = var.tf_es_username
      password = var.tf_es_password
    }
  }
}
```

#### Step 3: If Using Self-Signed Certificates (Development Only)

```hcl
variable "aap_ca_cert_path" {
  description = "Path to AAP CA certificate for TLS verification"
  type        = string
  default     = ""
}

provider "aap" {
  host     = var.aap_host
  ca_cert  = var.aap_ca_cert_path != "" ? file(var.aap_ca_cert_path) : null
  username = var.aap_username
  password = var.aap_password
}
```

---

### Priority 3: Fix Variable Naming and Documentation

```hcl
# Rename variables to use underscores (Terraform convention)
variable "tf_es_username" {  # Changed from tf-es-username
  description = "The username for the AAP Event Stream"  # Fixed description
  type        = string
  sensitive   = true
}

variable "tf_es_password" {  # Changed from tf-es-password
  description = "The password for the AAP Event Stream"  # Fixed description
  type        = string
  sensitive   = true
}

# Update references in action block
action "aap_eda_eventstream_post" "create" {
  config {
    # ... other config ...
    event_stream_config = {
      url = var.aap_eventstream_url
      insecure_skip_verify = false
      username = var.tf_es_username  # Updated reference
      password = var.tf_es_password  # Updated reference
    }
  }
}
```

---

### Priority 4: Additional Security Enhancements

#### 4.1: Add Security Group Tagging

```hcl
resource "aws_security_group" "allow_http_ssh" {
  name        = "web-server-sg"
  description = "Allow SSH from AAP, HTTP from anywhere, all outbound traffic"

  # ... ingress/egress rules ...

  tags = {
    Name        = "web-server-sg"
    Environment = "production"
    ManagedBy   = "Terraform"
    Purpose     = "Web server security group"
    Owner       = "sjweaver"
  }
}
```

#### 4.2: Implement Least Privilege for Egress

```hcl
# Instead of allowing all outbound traffic, restrict to necessary ports
egress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTPS for package updates"
}

egress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTP for package updates"
}

egress {
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "DNS resolution"
}
```

#### 4.3: Use AWS Secrets Manager for Credentials

```hcl
# Store AAP credentials in AWS Secrets Manager
data "aws_secretsmanager_secret_version" "aap_credentials" {
  secret_id = "aap/terraform-credentials"
}

locals {
  aap_creds = jsondecode(data.aws_secretsmanager_secret_version.aap_credentials.secret_string)
}

provider "aap" {
  host     = var.aap_host
  username = local.aap_creds.username
  password = local.aap_creds.password
  insecure_skip_verify = false
}
```

---

## 📋 Implementation Checklist

### Phase 1: Immediate Actions (Critical)
- [ ] Restrict SSH access in security group to AAP server IP only
- [ ] Enable TLS certificate verification for AAP provider
- [ ] Enable TLS certificate verification for event stream
- [ ] Fix variable naming conventions (tf-es-* to tf_es_*)

### Phase 2: Short-term Improvements (1-2 weeks)
- [ ] Implement AWS Systems Manager Session Manager
- [ ] Remove SSH key requirement from EC2 instances
- [ ] Add security group tagging
- [ ] Restrict egress rules to necessary ports only

### Phase 3: Long-term Enhancements (1 month)
- [ ] Migrate credentials to AWS Secrets Manager
- [ ] Implement VPC endpoints for SSM (if using private subnets)
- [ ] Add CloudTrail logging for all API calls
- [ ] Implement AWS Config rules for security compliance
- [ ] Add automated security scanning (e.g., AWS Inspector)

---

## 🔍 Security Testing Recommendations

After implementing changes, verify security improvements:

1. **Port Scanning Test:**
   ```bash
   nmap -p 22,80,443 <ec2-public-ip>
   ```
   Expected: Port 22 should be filtered or closed

2. **TLS Verification Test:**
   ```bash
   openssl s_client -connect <aap-host>:443 -showcerts
   ```
   Expected: Valid certificate chain

3. **IAM Policy Validation:**
   ```bash
   aws iam simulate-principal-policy \
     --policy-source-arn <instance-role-arn> \
     --action-names ssm:StartSession
   ```

4. **Security Group Audit:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <sg-id> \
     --query 'SecurityGroups[0].IpPermissions'
   ```

---

## 📚 Additional Resources

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform Security Best Practices](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AAP Security Hardening Guide](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)

---

## 🎯 Expected Outcomes

After implementing these security improvements:

1. **Reduced Attack Surface:** SSH port no longer exposed to internet
2. **Encrypted Communications:** All AAP communications use verified TLS
3. **Compliance Ready:** Meets common security framework requirements
4. **Audit Trail:** All access logged via CloudTrail (if using SSM)
5. **Maintainable Code:** Consistent naming and clear documentation

---

## ⚠️ Migration Notes

When implementing these changes:

1. **Test in non-production first**
2. **Update AAP inventory** to use SSM connection if switching from SSH
3. **Update Ansible playbooks** if connection method changes
4. **Coordinate with team** on credential rotation
5. **Document changes** in runbooks and procedures

---

*Generated: 2025-11-26*
*Priority: Security improvements should be implemented immediately*