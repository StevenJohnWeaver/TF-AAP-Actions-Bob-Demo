#!/bin/bash
# Seed HCP Vault with demo secrets
# This script populates Vault with sample secrets for the demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}HCP Vault Secrets Seeding Script${NC}"
echo -e "${GREEN}=========================================${NC}"

# Check required environment variables
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}ERROR: VAULT_ADDR and VAULT_TOKEN must be set${NC}"
    exit 1
fi

if [ -z "$VAULT_NAMESPACE" ]; then
    export VAULT_NAMESPACE="admin"
fi

echo -e "\n${GREEN}Seeding application secrets...${NC}"

# Application secrets
vault kv put secret/applications/demo-app \
    database_url="postgresql://demo:demo-password@db.example.com:5432/demo" \
    api_key="demo-api-key-$(date +%s)" \
    redis_password="redis-secret-password"

echo -e "${GREEN}✓ Application secrets created${NC}"

# Ansible secrets
echo -e "\n${GREEN}Seeding Ansible secrets...${NC}"
vault kv put secret/ansible/config \
    sudo_password="ansible-sudo-pass" \
    vault_password="ansible-vault-pass"

echo -e "${GREEN}✓ Ansible secrets created${NC}"

# OpenShift secrets
echo -e "\n${GREEN}Seeding OpenShift secrets...${NC}"
vault kv put secret/openshift/credentials \
    admin_user="kubeadmin" \
    admin_password="$(openssl rand -base64 32)" \
    registry_token="openshift-registry-token-$(date +%s)"

echo -e "${GREEN}✓ OpenShift secrets created${NC}"

# Terraform secrets
echo -e "\n${GREEN}Seeding Terraform secrets...${NC}"
vault kv put secret/terraform/config \
    aws_region="us-east-1" \
    ssh_key_name="demo-key"

echo -e "${GREEN}✓ Terraform secrets created${NC}"

# EDA webhook tokens
echo -e "\n${GREEN}Seeding EDA webhook tokens...${NC}"
vault kv put secret/eda/webhook-tokens \
    terraform_webhook_token="$(openssl rand -hex 32)"

echo -e "${GREEN}✓ EDA webhook tokens created${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Secrets Seeding Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nSeeded secrets:"
echo -e "  - secret/applications/demo-app"
echo -e "  - secret/ansible/config"
echo -e "  - secret/openshift/credentials"
echo -e "  - secret/terraform/config"
echo -e "  - secret/eda/webhook-tokens"
echo -e "\n${YELLOW}Note: These are demo secrets. Use real secrets in production!${NC}"

# Made with Bob
