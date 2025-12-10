#!/bin/bash
# Create Terraform-specific AppRole in HCP Vault

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Create Terraform AppRole${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check required environment variables
if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR environment variable is not set${NC}"
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_TOKEN environment variable is not set${NC}"
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

# Create Terraform AppRole
echo -e "\n${GREEN}Creating Terraform AppRole...${NC}"

# Enable AppRole auth if not already enabled
if ! vault auth list | grep -q "^approle/"; then
    echo -e "${YELLOW}Enabling AppRole auth method...${NC}"
    vault auth enable approle
fi

# Create the Terraform role
vault write auth/approle/role/terraform \
    token_policies="terraform-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    token_num_uses=0 \
    secret_id_ttl=0 \
    secret_id_num_uses=0

echo -e "${GREEN}✓ Terraform AppRole created${NC}"

# Get Role ID
echo -e "\n${GREEN}Getting Role ID...${NC}"
ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
echo -e "${GREEN}✓ Role ID: ${ROLE_ID}${NC}"

# Generate Secret ID
echo -e "\n${GREEN}Generating Secret ID...${NC}"
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/terraform/secret-id)
echo -e "${GREEN}✓ Secret ID generated${NC}"

# Test the AppRole
echo -e "\n${GREEN}Testing AppRole authentication...${NC}"
TEST_TOKEN=$(vault write -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID")

if [ -z "$TEST_TOKEN" ]; then
    echo -e "${RED}ERROR: Failed to authenticate with AppRole${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AppRole authentication successful${NC}"

# Test token creation with the new token
echo -e "\n${GREEN}Testing child token creation...${NC}"
if VAULT_TOKEN=$TEST_TOKEN vault token create -policy=default -ttl=1h > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Child token creation works!${NC}"
else
    echo -e "${RED}✗ Child token creation failed${NC}"
    echo -e "${YELLOW}This may indicate the policy still needs adjustment${NC}"
fi

# Display credentials
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Terraform AppRole Credentials${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Save these credentials securely!${NC}"
echo ""
echo -e "Role ID:   ${GREEN}${ROLE_ID}${NC}"
echo -e "Secret ID: ${GREEN}${SECRET_ID}${NC}"
echo ""
echo -e "${GREEN}=========================================${NC}"

# Save to file
CREDS_FILE="/tmp/terraform-approle-creds.txt"
cat > "$CREDS_FILE" << EOF
Terraform AppRole Credentials
Generated: $(date)

Role ID:   $ROLE_ID
Secret ID: $SECRET_ID

Add these to Terraform Cloud workspace variables:
- vault_role_id = $ROLE_ID (mark as sensitive)
- vault_secret_id = $SECRET_ID (mark as sensitive)
EOF

echo -e "\n${GREEN}Credentials saved to: ${CREDS_FILE}${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "1. Add these credentials to Terraform Cloud:"
echo "   - Go to your workspace: aws-infrastructure"
echo "   - Add variable: vault_role_id = $ROLE_ID (sensitive)"
echo "   - Add variable: vault_secret_id = $SECRET_ID (sensitive)"
echo ""
echo "2. Ensure your terraform/main.tf uses AppRole auth:"
echo "   provider \"vault\" {"
echo "     address   = var.hcp_vault_address"
echo "     namespace = var.hcp_vault_namespace"
echo "     auth_login {"
echo "       path = \"auth/approle/login\""
echo "       parameters = {"
echo "         role_id   = var.vault_role_id"
echo "         secret_id = var.vault_secret_id"
echo "       }"
echo "     }"
echo "   }"
echo ""
echo "3. Run terraform plan - should work now!"
echo ""
echo -e "${GREEN}=========================================${NC}"

# Made with Bob
