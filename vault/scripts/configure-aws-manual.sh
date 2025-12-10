#!/bin/bash
# Manual AWS Secrets Engine Configuration
# Run this step-by-step if the automated script fails

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Manual AWS Configuration${NC}"
echo -e "${GREEN}=========================================${NC}"

# Step 1: Check Vault connection
echo -e "\n${GREEN}Step 1: Testing Vault connection...${NC}"
vault status
echo -e "${GREEN}✓ Vault connection OK${NC}"

# Step 2: Enable AWS secrets engine (if needed)
echo -e "\n${GREEN}Step 2: Checking AWS secrets engine...${NC}"
if vault secrets list | grep -q "^aws/"; then
    echo -e "${YELLOW}AWS secrets engine already enabled${NC}"
else
    echo -e "${GREEN}Enabling AWS secrets engine...${NC}"
    vault secrets enable -path=aws aws
    echo -e "${GREEN}✓ AWS secrets engine enabled${NC}"
fi

# Step 3: Configure AWS root credentials
echo -e "\n${GREEN}Step 3: Configuring AWS root credentials...${NC}"
echo -e "${YELLOW}You will be prompted to enter your AWS credentials${NC}"
echo -e "${YELLOW}Press Enter to continue...${NC}"
read

echo -e "\nEnter your AWS Access Key ID:"
read -r AWS_KEY

echo -e "\nEnter your AWS Secret Access Key:"
read -rs AWS_SECRET
echo

echo -e "\nEnter AWS Region (default: us-east-1):"
read -r AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

echo -e "\n${GREEN}Writing AWS root configuration to Vault...${NC}"
vault write aws/config/root \
    access_key="$AWS_KEY" \
    secret_key="$AWS_SECRET" \
    region="$AWS_REGION"

echo -e "${GREEN}✓ AWS root credentials configured${NC}"

# Step 4: Verify root configuration
echo -e "\n${GREEN}Step 4: Verifying AWS root configuration...${NC}"
vault read aws/config/root
echo -e "${GREEN}✓ Configuration verified${NC}"

# Step 5: Create Terraform role
echo -e "\n${GREEN}Step 5: Creating Terraform AWS role...${NC}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="$SCRIPT_DIR/../policies/terraform-aws-policy.json"

if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}ERROR: Policy file not found at: $POLICY_FILE${NC}"
    exit 1
fi

echo -e "Using policy file: $POLICY_FILE"
vault write aws/roles/terraform-provisioner \
    credential_type=iam_user \
    policy_document=@"$POLICY_FILE"

echo -e "${GREEN}✓ Terraform role created${NC}"

# Step 6: Create Ansible role
echo -e "\n${GREEN}Step 6: Creating Ansible AWS role...${NC}"
ANSIBLE_POLICY="$SCRIPT_DIR/../policies/ansible-aws-policy.json"

if [ ! -f "$ANSIBLE_POLICY" ]; then
    echo -e "${RED}ERROR: Policy file not found at: $ANSIBLE_POLICY${NC}"
    exit 1
fi

vault write aws/roles/ansible-configurator \
    credential_type=iam_user \
    policy_document=@"$ANSIBLE_POLICY"

echo -e "${GREEN}✓ Ansible role created${NC}"

# Step 7: List roles
echo -e "\n${GREEN}Step 7: Listing AWS roles...${NC}"
vault list aws/roles

# Step 8: Test credential generation
echo -e "\n${GREEN}Step 8: Testing credential generation...${NC}"
echo -e "${YELLOW}Generating test credentials (this may take a moment)...${NC}"
vault read aws/creds/terraform-provisioner

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}AWS Configuration Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nYou can now:"
echo -e "1. Generate Terraform credentials: ${YELLOW}vault read aws/creds/terraform-provisioner${NC}"
echo -e "2. Generate Ansible credentials: ${YELLOW}vault read aws/creds/ansible-configurator${NC}"
echo -e "3. Continue with HCP Terraform setup"

# Made with Bob