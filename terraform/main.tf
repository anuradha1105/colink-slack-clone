# Colink Slack Clone - Terraform Infrastructure
# This creates an EC2 instance with all required security groups and configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Colink-Slack-Clone"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC (use default or create new based on variable)
data "aws_vpc" "default" {
  default = true
}

# Default subnet
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Colink Application
resource "aws_security_group" "colink_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Colink Slack Clone application"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
  }

  # Frontend (Next.js)
  ingress {
    description = "Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Keycloak
  ingress {
    description = "Keycloak"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Auth Proxy
  ingress {
    description = "Auth Proxy"
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Message Service
  ingress {
    description = "Message Service"
    from_port   = 8002
    to_port     = 8002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Channel Service
  ingress {
    description = "Channel Service"
    from_port   = 8003
    to_port     = 8003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Threads Service
  ingress {
    description = "Threads Service"
    from_port   = 8005
    to_port     = 8005
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Reactions Service
  ingress {
    description = "Reactions Service"
    from_port   = 8006
    to_port     = 8006
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Files Service
  ingress {
    description = "Files Service"
    from_port   = 8007
    to_port     = 8007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Notifications Service
  ingress {
    description = "Notifications Service"
    from_port   = 8008
    to_port     = 8008
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WebSocket Service
  ingress {
    description = "WebSocket Service"
    from_port   = 8009
    to_port     = 8009
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MinIO (Object Storage)
  ingress {
    description = "MinIO API"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MinIO Console (optional)
  ingress {
    description = "MinIO Console"
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr  # Restrict to admin IPs
  }

  # HTTP (for Let's Encrypt or redirect)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# SSH Key Pair
resource "aws_key_pair" "colink_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project_name}-key"
  }
}

# IAM Role for EC2 (for CloudWatch, SSM, etc.)
resource "aws_iam_role" "colink_ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.colink_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.colink_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "colink_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.colink_ec2_role.name
}

# EBS Volume for data persistence (optional)
resource "aws_ebs_volume" "colink_data" {
  count             = var.create_data_volume ? 1 : 0
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-data-volume"
  }
}

# EC2 Instance
resource "aws_instance" "colink" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.colink_key[0].key_name : var.existing_key_name
  vpc_security_group_ids = [aws_security_group.colink_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.colink_profile.name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    project_name     = var.project_name
    github_repo      = var.github_repo
    domain_name      = var.domain_name
    admin_email      = var.admin_email
    environment      = var.environment
  }))

  tags = {
    Name = "${var.project_name}-server"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# Attach data volume to instance
resource "aws_volume_attachment" "colink_data_attachment" {
  count       = var.create_data_volume ? 1 : 0
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.colink_data[0].id
  instance_id = aws_instance.colink.id
}

# Elastic IP for static public IP
resource "aws_eip" "colink_eip" {
  count    = var.create_elastic_ip ? 1 : 0
  instance = aws_instance.colink.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "colink_logs" {
  name              = "/colink/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This alarm fires when CPU exceeds 80%"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.colink.id
  }

  tags = {
    Name = "${var.project_name}-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project_name}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This alarm fires when disk usage exceeds 85%"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.colink.id
    path       = "/"
    fstype     = "xfs"
  }

  tags = {
    Name = "${var.project_name}-disk-alarm"
  }
}
