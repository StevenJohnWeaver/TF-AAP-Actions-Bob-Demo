#!/bin/bash
# Setup script for HCP Vault configuration
# This script configures HCP Vault for the Red Hat + HashiCorp demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}HCP Vault Configuration Script${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check required environment variables
if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR environment variable is not set${NC}"
    echo "Example: export VAULT_ADDR='https://your-cluster.vault.hashicorp.cloud:8200'"
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_TOKEN environment variable is not set${NC}"
    echo "Example: export VAULT_TOKEN='your-admin-token'"
    exit 1
fi

if [ -z "$VAULT_NAMESPACE" ]; then
    echo -e "${YELLOW}WARNING: VAULT_NAMESPACE not set, using 'admin'${NC}"
    export VAULT_NAMESPACE="admin"
fi

echo -e "\n${GREEN}Configuration:${NC}"
echo "  Vault Address: $VAULT_ADDR"
echo "  Vault Namespace: $VAULT_NAMESPACE"

# Test Vault connection
echo -e "\n${GREEN}Testing Vault connection...${NC}"
if ! vault status > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Vault${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Vault successfully${NC}"

# Enable AWS Secrets Engine
echo -e "\n${GREEN}Configuring AWS Secrets Engine...${NC}"
if vault secrets list | grep -q "^aws/"; then
    echo -e "${YELLOW}AWS secrets engine already enabled${NC}"
else
    vault secrets enable -path=aws aws
    echo -e "${GREEN}✓ AWS secrets engine enabled${NC}"
fi

# Configure AWS Secrets Engine
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${YELLOW}WARNING: AWS credentials not set. Skipping AWS configuration.${NC}"
    echo "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to configure AWS secrets engine."
else
    echo -e "${GREEN}Configuring AWS secrets engine with credentials...${NC}"
    vault write aws/config/root \
        access_key=$AWS_ACCESS_KEY_ID \
        secret_key=$AWS_SECRET_ACCESS_KEY \
        region=us-east-1
    echo -e "${GREEN}✓ AWS secrets engine configured${NC}"
    
    # Create Terraform role
    echo -e "${GREEN}Creating Terraform AWS role...${NC}"
    vault write aws/roles/terraform-provisioner \
        credential_type=iam_user \
        policy_document=@../policies/terraform-aws-policy.json
    echo -e "${GREEN}✓ Terraform AWS role created${NC}"
    
    # Create Ansible role
    echo -e "${GREEN}Creating Ansible AWS role...${NC}"
    vault write aws/roles/ansible-configurator \
        credential_type=iam_user \
        policy_document=@../policies/ansible-aws-policy.json
    echo -e "${GREEN}✓ Ansible AWS role created${NC}"
fi

# Enable KV v2 Secrets Engine
echo -e "\n${GREEN}Configuring KV v2 Secrets Engine...${NC}"
if vault secrets list | grep -q "^secret/"; then
    echo -e "${YELLOW}KV v2 secrets engine already enabled${NC}"
else
    vault secrets enable -path=secret kv-v2
    echo -e "${GREEN}✓ KV v2 secrets engine enabled${NC}"
fi

# Enable AppRole Auth Method
echo -e "\n${GREEN}Configuring AppRole Authentication...${NC}"
if vault auth list | grep -q "^approle/"; then
    echo -e "${YELLOW}AppRole auth method already enabled${NC}"
else
    vault auth enable approle
    echo -e "${GREEN}✓ AppRole auth method enabled${NC}"
fi

# Create Policies
echo -e "\n${GREEN}Creating Vault policies...${NC}"

echo -e "${GREEN}Creating Terraform policy...${NC}"
vault policy write terraform-policy ../policies/terraform-policy.hcl
echo -e "${GREEN}✓ Terraform policy created${NC}"

echo -e "${GREEN}Creating Ansible policy...${NC}"
vault policy write ansible-policy ../policies/ansible-policy.hcl
echo -e "${GREEN}✓ Ansible policy created${NC}"

echo -e "${GREEN}Creating OpenShift policy...${NC}"
vault policy write openshift-policy ../policies/openshift-policy.hcl
echo -e "${GREEN}✓ OpenShift policy created${NC}"

# Create AppRole for Ansible
echo -e "\n${GREEN}Creating AppRole for Ansible...${NC}"
vault write auth/approle/role/ansible \
    token_policies="ansible-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h
echo -e "${GREEN}✓ Ansible AppRole created${NC}"

# Get RoleID and SecretID
echo -e "\n${GREEN}Retrieving Ansible AppRole credentials...${NC}"
ROLE_ID=$(vault read -field=role_id auth/approle/role/ansible/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/ansible/secret-id)

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Ansible AppRole Credentials:${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "Role ID: ${YELLOW}$ROLE_ID${NC}"
echo -e "Secret ID: ${YELLOW}$SECRET_ID${NC}"
echo -e "\n${YELLOW}Save these credentials securely!${NC}"
echo -e "Set them as environment variables in AAP:"
echo -e "  VAULT_ROLE_ID=$ROLE_ID"
echo -e "  VAULT_SECRET_ID=$SECRET_ID"

# Create Token for Terraform
echo -e "\n${GREEN}Creating token for Terraform...${NC}"
TF_TOKEN=$(vault token create \
    -policy=terraform-policy \
    -ttl=24h \
    -display-name="hcp-terraform" \
    -field=token)

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Terraform Token:${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "Token: ${YELLOW}$TF_TOKEN${NC}"
echo -e "\n${YELLOW}Save this token securely!${NC}"
echo -e "Set it in HCP Terraform workspace variables:"
echo -e "  hcp_vault_token=$TF_TOKEN"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}HCP Vault Configuration Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Run ${YELLOW}./seed-secrets.sh${NC} to populate secrets"
echo -e "2. Configure AAP with Vault credentials"
echo -e "3. Configure HCP Terraform with Vault token"

# Made with Bob
