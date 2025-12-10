#!/bin/bash
# Fix AWS policy size issue by using compact policy or assumed role
# Run this after getting the "Maximum policy size exceeded" error

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}AWS Policy Size Fix${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}The AWS inline policy is too large (>2048 bytes).${NC}"
echo -e "${YELLOW}Choose a solution:${NC}\n"
echo -e "${BLUE}1)${NC} Use compact policy (wildcards like ec2:*, s3:*)"
echo -e "${BLUE}2)${NC} Use AWS assumed role (recommended for production)"
echo -e "${BLUE}3)${NC} Use AWS managed policies (PowerUserAccess)"
echo ""
read -p "Enter choice (1-3): " choice

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

case $choice in
    1)
        echo -e "\n${GREEN}Option 1: Using compact policy${NC}"
        echo -e "${YELLOW}Note: This uses wildcards (ec2:*, s3:*, etc.) - less secure but works for demos${NC}"
        
        # Delete existing role
        echo -e "\n${GREEN}Removing old role...${NC}"
        vault delete aws/roles/terraform-provisioner 2>/dev/null || true
        
        # Create new role with compact policy
        echo -e "${GREEN}Creating role with compact policy...${NC}"
        vault write aws/roles/terraform-provisioner \
            credential_type=iam_user \
            policy_document=@"$SCRIPT_DIR/../policies/terraform-aws-policy-compact.json"
        
        echo -e "${GREEN}✓ Role created with compact policy${NC}"
        ;;
        
    2)
        echo -e "\n${GREEN}Option 2: Using AWS assumed role${NC}"
        echo -e "${YELLOW}This requires an IAM role to be created in AWS first.${NC}\n"
        
        read -p "Enter the ARN of your IAM role (e.g., arn:aws:iam::123456789012:role/TerraformRole): " role_arn
        
        if [ -z "$role_arn" ]; then
            echo -e "${RED}ERROR: Role ARN is required${NC}"
            exit 1
        fi
        
        # Delete existing role
        echo -e "\n${GREEN}Removing old role...${NC}"
        vault delete aws/roles/terraform-provisioner 2>/dev/null || true
        
        # Create new role with assumed role
        echo -e "${GREEN}Creating role with assumed role...${NC}"
        vault write aws/roles/terraform-provisioner \
            credential_type=assumed_role \
            role_arns="$role_arn" \
            default_sts_ttl=3600 \
            max_sts_ttl=7200
        
        echo -e "${GREEN}✓ Role created with assumed role${NC}"
        echo -e "\n${YELLOW}Note: The IAM role must have a trust policy allowing Vault to assume it${NC}"
        ;;
        
    3)
        echo -e "\n${GREEN}Option 3: Using AWS managed policy${NC}"
        echo -e "${YELLOW}This uses AWS's PowerUserAccess managed policy${NC}"
        
        # Delete existing role
        echo -e "\n${GREEN}Removing old role...${NC}"
        vault delete aws/roles/terraform-provisioner 2>/dev/null || true
        
        # Create new role with managed policy ARN
        echo -e "${GREEN}Creating role with managed policy...${NC}"
        vault write aws/roles/terraform-provisioner \
            credential_type=iam_user \
            policy_arns="arn:aws:iam::aws:policy/PowerUserAccess"
        
        echo -e "${GREEN}✓ Role created with managed policy${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Test credential generation
echo -e "\n${GREEN}Testing credential generation...${NC}"
echo -e "${YELLOW}Generating test credentials...${NC}"

if vault read aws/creds/terraform-provisioner; then
    echo -e "\n${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ Success! Credentials generated${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "\n${RED}=========================================${NC}"
    echo -e "${RED}✗ Failed to generate credentials${NC}"
    echo -e "${RED}=========================================${NC}"
    echo -e "\n${YELLOW}Troubleshooting tips:${NC}"
    echo -e "1. Check AWS root credentials: ${BLUE}vault read aws/config/root${NC}"
    echo -e "2. Verify IAM permissions of the AWS user"
    echo -e "3. Check Vault logs for detailed errors"
    exit 1
fi

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Update Ansible role if needed: ${BLUE}vault write aws/roles/ansible-configurator ...${NC}"
echo -e "2. Continue with HCP Terraform setup"
echo -e "3. Test the full workflow"

# Made with Bob