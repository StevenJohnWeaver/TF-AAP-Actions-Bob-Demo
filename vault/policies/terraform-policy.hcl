# Vault Policy for Terraform
# Allows Terraform to read AWS credentials and Terraform-specific secrets

# Allow creating child tokens (required by Vault provider)
path "auth/token/create" {
  capabilities = ["create", "update"]
}

# Allow renewing tokens
path "auth/token/renew" {
  capabilities = ["update"]
}

# Allow renewing self token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow looking up token information
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

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