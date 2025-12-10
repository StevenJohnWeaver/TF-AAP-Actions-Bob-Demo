#!/bin/bash
# Update Terraform policy in Vault and regenerate token
# Run this after modifying the terraform-policy.hcl file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Update Terraform Policy${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check Vault connection
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR and VAULT_TOKEN must be set${NC}"
    exit 1
fi

if [ -z "$VAULT_NAMESPACE" ]; then
    export VAULT_NAMESPACE="admin"
fi

echo -e "\n${GREEN}Configuration:${NC}"
echo "  Vault Address: $VAULT_ADDR"
echo "  Vault Namespace: $VAULT_NAMESPACE"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="$SCRIPT_DIR/../policies/terraform-policy.hcl"

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}ERROR: Policy file not found at: $POLICY_FILE${NC}"
    exit 1
fi

# Update the policy
echo -e "\n${GREEN}Updating Terraform policy in Vault...${NC}"
vault policy write terraform-policy "$POLICY_FILE"
echo -e "${GREEN}✓ Policy updated${NC}"

# Show the policy
echo -e "\n${GREEN}Current policy:${NC}"
vault policy read terraform-policy

# Revoke old tokens (optional)
echo -e "\n${YELLOW}Do you want to revoke existing Terraform tokens? (y/n)${NC}"
echo -e "${YELLOW}(This will invalidate any tokens currently in use)${NC}"
read -r revoke_choice

if [ "$revoke_choice" = "y" ] || [ "$revoke_choice" = "Y" ]; then
    echo -e "\n${YELLOW}Listing tokens with terraform-policy...${NC}"
    # Note: This requires root or sudo permissions
    echo -e "${YELLOW}Skipping automatic revocation - revoke manually if needed${NC}"
fi

# Generate new token
echo -e "\n${GREEN}Generating new Terraform token...${NC}"
TF_TOKEN=$(vault token create \
    -policy=terraform-policy \
    -ttl=24h \
    -display-name="hcp-terraform-updated" \
    -field=token)

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}New Terraform Token${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\n${BLUE}Token:${NC}"
echo -e "${YELLOW}$TF_TOKEN${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "1. Update HCP Terraform workspace variable:"
echo -e "   ${BLUE}hcp_vault_token${NC} = ${YELLOW}$TF_TOKEN${NC}"
echo -e ""
echo -e "2. In HCP Terraform workspace:"
echo -e "   - Go to Variables"
echo -e "   - Find ${BLUE}hcp_vault_token${NC}"
echo -e "   - Click Edit"
echo -e "   - Paste the new token"
echo -e "   - Mark as Sensitive"
echo -e "   - Save"
echo -e ""
echo -e "3. Run ${BLUE}terraform plan${NC} again"

# Save to file (optional)
echo -e "\n${YELLOW}Would you like to save this token to a file? (y/n)${NC}"
read -r save_choice

if [ "$save_choice" = "y" ] || [ "$save_choice" = "Y" ]; then
    TOKEN_FILE="$HOME/.vault-terraform-token"
    cat > "$TOKEN_FILE" << EOF
# Terraform Vault Token
# Generated: $(date)
# WARNING: Keep this file secure!

export VAULT_TOKEN="$TF_TOKEN"

# To use this token:
# source $TOKEN_FILE
EOF
    chmod 600 "$TOKEN_FILE"
    echo -e "${GREEN}✓ Token saved to: ${YELLOW}$TOKEN_FILE${NC}"
fi

echo -e "\n${GREEN}Policy update complete!${NC}"

# Made with Bob