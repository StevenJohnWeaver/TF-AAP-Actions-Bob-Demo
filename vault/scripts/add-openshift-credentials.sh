#!/bin/bash
# Add OpenShift Sandbox credentials to HCP Vault

set -e

# Check if required environment variables are set
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_NAMESPACE" ]; then
    echo "Error: Required environment variables not set"
    echo "Please set: VAULT_ADDR, VAULT_TOKEN, VAULT_NAMESPACE"
    exit 1
fi

echo "Adding OpenShift Sandbox credentials to HCP Vault..."

# OpenShift Sandbox details
OPENSHIFT_API_URL="https://api.rm2.thpm.p1.openshiftapps.com:6443"
OPENSHIFT_TOKEN="sha256~ZqxpZbeIO_q4TWZ2dGmIUjs5mYyjthnxnzy4Oot76R4"
OPENSHIFT_NAMESPACE="steveweaver-hashi"

# Store OpenShift credentials
vault kv put secret/openshift/credentials \
    api_url="$OPENSHIFT_API_URL" \
    token="$OPENSHIFT_TOKEN" \
    namespace="$OPENSHIFT_NAMESPACE" \
    username="steveweaver-hashi"

echo "✅ OpenShift credentials added successfully!"
echo ""
echo "Stored at: secret/openshift/credentials"
echo "  - api_url: $OPENSHIFT_API_URL"
echo "  - namespace: $OPENSHIFT_NAMESPACE"
echo "  - token: [REDACTED]"
echo ""
echo "Note: OpenShift Sandbox tokens expire after 24 hours."
echo "You'll need to update the token periodically using:"
echo "  vault kv patch secret/openshift/credentials token='<new-token>'"

# Made with Bob
