#!/bin/bash
# User data script for EC2 instance initialization

set -e

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system packages
yum update -y

# Install basic utilities
yum install -y \
    wget \
    curl \
    git \
    vim \
    htop \
    jq \
    unzip

# Install Python 3 and pip
yum install -y python3 python3-pip

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create application directory
mkdir -p /opt/demo-app
chown ec2-user:ec2-user /opt/demo-app

# Create log directory
mkdir -p /var/log/demo-app
chown ec2-user:ec2-user /var/log/demo-app

# Set up CloudWatch agent (optional)
# wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
# rpm -U ./amazon-cloudwatch-agent.rpm

# Signal completion
echo "User data script completed successfully" > /var/log/user-data-complete.log

# Made with Bob
