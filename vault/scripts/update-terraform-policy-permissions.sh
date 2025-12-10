#!/bin/bash
# Update Terraform policy in HCP Vault to allow child token creation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Update Terraform Policy Permissions${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check required environment variables
if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR environment variable is not set${NC}"
    echo "Example: export VAULT_ADDR='https://your-cluster.vault.hashicorp.cloud:8200'"
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_TOKEN environment variable is not set${NC}"
    echo "Please set your admin token"
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

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="$SCRIPT_DIR/../policies/terraform-policy.hcl"

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}ERROR: Policy file not found: $POLICY_FILE${NC}"
    exit 1
fi

# Update the policy
echo -e "\n${GREEN}Updating terraform-policy in Vault...${NC}"
vault policy write terraform-policy "$POLICY_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Policy updated successfully${NC}"
else
    echo -e "${RED}ERROR: Failed to update policy${NC}"
    exit 1
fi

# Show the updated policy
echo -e "\n${GREEN}Current terraform-policy:${NC}"
vault policy read terraform-policy

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "The terraform-policy has been updated with permissions to create child tokens."
echo ""
echo "If you're using AppRole authentication:"
echo "  - The AppRole should already be using this policy"
echo "  - Try running terraform plan again"
echo ""
echo "If you're using token authentication:"
echo "  - You may need to create a new token with this policy"
echo "  - Run: vault token create -policy=terraform-policy -ttl=720h"
echo ""
echo -e "${GREEN}=========================================${NC}"

# Made with Bob
