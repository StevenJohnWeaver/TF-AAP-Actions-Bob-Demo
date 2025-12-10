# Compute Module - Creates EC2 instances

# Get latest Amazon Linux 2 AMI if not specified
data "aws_ami" "amazon_linux_2" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create EC2 instances
resource "aws_instance" "app" {
  count = var.instance_count
  
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2[0].id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  
  # User data for initial setup
  user_data = templatefile("${path.module}/user_data.sh", {
    hostname = "app-server-${count.index + 1}"
  })
  
  # Enable detailed monitoring
  monitoring = var.enable_detailed_monitoring
  
  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = merge(
      var.tags,
      {
        Name = "${var.environment}-app-server-${count.index + 1}-root"
      }
    )
  }
  
  # Instance metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  tags = merge(
    var.tags,
    {
      Name  = "app-server-${count.index + 1}"
      Index = count.index + 1
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create Elastic IPs for instances (optional)
resource "aws_eip" "app" {
  count = var.assign_public_ip ? var.instance_count : 0
  
  instance = aws_instance.app[count.index].id
  domain   = "vpc"
  
  tags = merge(
    var.tags,
    {
      Name = "app-server-${count.index + 1}-eip"
    }
  )
  
  depends_on = [aws_instance.app]
}