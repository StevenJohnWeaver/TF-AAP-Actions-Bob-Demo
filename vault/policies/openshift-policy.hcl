# Vault Policy for OpenShift
# Allows OpenShift to read application secrets

# Allow reading application secrets
path "secret/data/applications/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/applications/*" {
  capabilities = ["read", "list"]
}

# Allow reading OpenShift-specific secrets
path "secret/data/openshift/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/openshift/*" {
  capabilities = ["read", "list"]
}