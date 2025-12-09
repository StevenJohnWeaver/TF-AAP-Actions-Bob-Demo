# Vault Policy for Ansible
# Allows Ansible to read application secrets and AWS credentials

# Allow reading Ansible configuration secrets
path "secret/data/ansible/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/ansible/*" {
  capabilities = ["read", "list"]
}

# Allow reading application secrets
path "secret/data/applications/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/applications/*" {
  capabilities = ["read", "list"]
}

# Allow reading OpenShift secrets
path "secret/data/openshift/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/openshift/*" {
  capabilities = ["read", "list"]
}

# Allow reading AWS credentials for configuration tasks
path "aws/creds/ansible-configurator" {
  capabilities = ["read"]
}

# Allow reading EDA webhook tokens
path "secret/data/eda/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/eda/*" {
  capabilities = ["read", "list"]
}