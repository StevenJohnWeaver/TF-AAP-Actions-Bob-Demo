#!/bin/bash
# Get or regenerate AppRole credentials for Ansible
# Run this to retrieve the Role ID and Secret ID for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}AppRole Credentials Helper${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check Vault connection
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR and VAULT_TOKEN must be set${NC}"
    exit 1
fi

if [ -z "$VAULT_NAMESPACE" ]; then
    export VAULT_NAMESPACE="admin"
fi

echo -e "\n${GREEN}Checking AppRole configuration...${NC}"

# Check if AppRole auth method is enabled
if ! vault auth list | grep -q "^approle/"; then
    echo -e "${RED}ERROR: AppRole auth method is not enabled${NC}"
    echo -e "${YELLOW}Run the setup script first: ./setup-hcp-vault.sh${NC}"
    exit 1
fi

# Check if ansible role exists
if ! vault read auth/approle/role/ansible > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Ansible AppRole does not exist${NC}"
    echo -e "${YELLOW}Creating Ansible AppRole...${NC}"
    
    vault write auth/approle/role/ansible \
        token_policies="ansible-policy" \
        token_ttl=1h \
        token_max_ttl=4h \
        secret_id_ttl=24h
    
    echo -e "${GREEN}✓ Ansible AppRole created${NC}"
fi

# Get Role ID
echo -e "\n${GREEN}Retrieving Role ID...${NC}"
ROLE_ID=$(vault read -field=role_id auth/approle/role/ansible/role-id)
echo -e "${GREEN}✓ Role ID retrieved${NC}"

# Generate new Secret ID
echo -e "\n${GREEN}Generating new Secret ID...${NC}"
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/ansible/secret-id)
echo -e "${GREEN}✓ Secret ID generated${NC}"

# Display credentials
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Ansible AppRole Credentials${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\n${BLUE}Role ID:${NC}"
echo -e "${YELLOW}$ROLE_ID${NC}"
echo -e "\n${BLUE}Secret ID:${NC}"
echo -e "${YELLOW}$SECRET_ID${NC}"

# Test login
echo -e "\n${GREEN}Testing AppRole login...${NC}"
if vault write auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AppRole login successful!${NC}"
else
    echo -e "${RED}✗ AppRole login failed${NC}"
    exit 1
fi

# Create export commands
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Export Commands for AAP${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\n${YELLOW}Copy and paste these into your AAP credential configuration:${NC}\n"
echo -e "${BLUE}VAULT_ROLE_ID${NC}=${YELLOW}$ROLE_ID${NC}"
echo -e "${BLUE}VAULT_SECRET_ID${NC}=${YELLOW}$SECRET_ID${NC}"

# Create test command
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Test Command${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\n${YELLOW}To test the login manually, run:${NC}\n"
echo -e "${BLUE}vault write auth/approle/login \\${NC}"
echo -e "${BLUE}  role_id=\"$ROLE_ID\" \\${NC}"
echo -e "${BLUE}  secret_id=\"$SECRET_ID\"${NC}"

# Save to file (optional)
echo -e "\n${YELLOW}Would you like to save these credentials to a file? (y/n)${NC}"
read -r save_choice

if [ "$save_choice" = "y" ] || [ "$save_choice" = "Y" ]; then
    CREDS_FILE="$HOME/.vault-ansible-approle"
    cat > "$CREDS_FILE" << EOF
# Ansible AppRole Credentials
# Generated: $(date)
# WARNING: Keep this file secure!

export VAULT_ROLE_ID="$ROLE_ID"
export VAULT_SECRET_ID="$SECRET_ID"

# To use these credentials:
# source $CREDS_FILE
EOF
    chmod 600 "$CREDS_FILE"
    echo -e "${GREEN}✓ Credentials saved to: ${YELLOW}$CREDS_FILE${NC}"
    echo -e "${YELLOW}To load them: ${BLUE}source $CREDS_FILE${NC}"
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "1. Copy the credentials above"
echo -e "2. Configure them in AAP as custom credentials"
echo -e "3. Test the Ansible playbook with Vault integration"

# Made with Bob