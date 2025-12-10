#!/bin/bash
# Fix script for AWS Secrets Engine configuration
# Run this if the initial setup didn't configure AWS properly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}AWS Secrets Engine Fix Script${NC}"
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

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${RED}ERROR: AWS credentials not set${NC}"
    echo "Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
fi

echo -e "\n${GREEN}Configuration:${NC}"
echo "  Vault Address: $VAULT_ADDR"
echo "  Vault Namespace: $VAULT_NAMESPACE"
echo "  AWS Region: ${AWS_REGION:-us-east-1}"

# Test Vault connection
echo -e "\n${GREEN}Testing Vault connection...${NC}"
if ! vault status > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to Vault${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Vault successfully${NC}"

# Check if AWS secrets engine is enabled
echo -e "\n${GREEN}Checking AWS secrets engine...${NC}"
if ! vault secrets list | grep -q "^aws/"; then
    echo -e "${YELLOW}AWS secrets engine not enabled, enabling now...${NC}"
    vault secrets enable -path=aws aws
    echo -e "${GREEN}✓ AWS secrets engine enabled${NC}"
else
    echo -e "${GREEN}✓ AWS secrets engine already enabled${NC}"
fi

# Configure AWS Secrets Engine root credentials
echo -e "\n${GREEN}Configuring AWS secrets engine root credentials...${NC}"
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=${AWS_REGION:-us-east-1}
echo -e "${GREEN}✓ AWS root credentials configured${NC}"

# Verify root configuration
echo -e "\n${GREEN}Verifying AWS root configuration...${NC}"
if vault read aws/config/root > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AWS root configuration verified${NC}"
else
    echo -e "${RED}ERROR: Could not verify AWS root configuration${NC}"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICIES_DIR="$SCRIPT_DIR/../policies"

# Create Terraform role
echo -e "\n${GREEN}Creating Terraform AWS role...${NC}"
if [ ! -f "$POLICIES_DIR/terraform-aws-policy.json" ]; then
    echo -e "${RED}ERROR: terraform-aws-policy.json not found at $POLICIES_DIR${NC}"
    exit 1
fi

vault write aws/roles/terraform-provisioner \
    credential_type=iam_user \
    policy_document=@"$POLICIES_DIR/terraform-aws-policy.json"
echo -e "${GREEN}✓ Terraform AWS role created${NC}"

# Verify Terraform role
echo -e "\n${GREEN}Verifying Terraform role...${NC}"
if vault read aws/roles/terraform-provisioner > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform role verified${NC}"
else
    echo -e "${RED}ERROR: Could not verify Terraform role${NC}"
    exit 1
fi

# Create Ansible role
echo -e "\n${GREEN}Creating Ansible AWS role...${NC}"
if [ ! -f "$POLICIES_DIR/ansible-aws-policy.json" ]; then
    echo -e "${RED}ERROR: ansible-aws-policy.json not found at $POLICIES_DIR${NC}"
    exit 1
fi

vault write aws/roles/ansible-configurator \
    credential_type=iam_user \
    policy_document=@"$POLICIES_DIR/ansible-aws-policy.json"
echo -e "${GREEN}✓ Ansible AWS role created${NC}"

# Verify Ansible role
echo -e "\n${GREEN}Verifying Ansible role...${NC}"
if vault read aws/roles/ansible-configurator > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ansible role verified${NC}"
else
    echo -e "${RED}ERROR: Could not verify Ansible role${NC}"
    exit 1
fi

# Test credential generation
echo -e "\n${GREEN}Testing credential generation...${NC}"
echo -e "${YELLOW}Generating test credentials for Terraform role...${NC}"
if vault read aws/creds/terraform-provisioner > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Successfully generated test credentials${NC}"
    echo -e "${YELLOW}Note: Test credentials were generated but not displayed for security${NC}"
else
    echo -e "${RED}ERROR: Could not generate test credentials${NC}"
    echo -e "${YELLOW}This might be due to AWS IAM permissions or rate limiting${NC}"
    exit 1
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}AWS Secrets Engine Configuration Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nYou can now:"
echo -e "1. Test with: ${YELLOW}vault read aws/config/root${NC}"
echo -e "2. List roles: ${YELLOW}vault list aws/roles${NC}"
echo -e "3. Generate creds: ${YELLOW}vault read aws/creds/terraform-provisioner${NC}"

# Made with Bob