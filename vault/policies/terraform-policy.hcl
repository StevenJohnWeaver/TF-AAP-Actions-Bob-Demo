# Vault Policy for Terraform
# Allows Terraform to read AWS credentials and Terraform-specific secrets

# Allow reading AWS credentials for provisioning
path "aws/creds/terraform-provisioner" {
  capabilities = ["read"]
}

# Allow reading Terraform configuration secrets
path "secret/data/terraform/*" {
  capabilities = ["read", "list"]
}

# Allow reading metadata
path "secret/metadata/terraform/*" {
  capabilities = ["read", "list"]
}