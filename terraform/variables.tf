# Colink Slack Clone - Terraform Variables

variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "colink"
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50
}

variable "create_data_volume" {
  description = "Whether to create a separate EBS volume for data"
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size of the data EBS volume in GB"
  type        = number
  default     = 100
}

variable "create_key_pair" {
  description = "Whether to create a new SSH key pair"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key content (required if create_key_pair is true)"
  type        = string
  default     = ""
}

variable "existing_key_name" {
  description = "Name of existing SSH key pair (required if create_key_pair is false)"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_elastic_ip" {
  description = "Whether to create an Elastic IP for the instance"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository URL for the Colink project"
  type        = string
  default     = "https://github.com/darshlukkad/colink-slack-clone.git"
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Admin email for Let's Encrypt certificates and notifications"
  type        = string
  default     = "admin@example.com"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Keycloak Configuration
variable "keycloak_admin_password" {
  description = "Keycloak admin password (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# Database Configuration
variable "postgres_password" {
  description = "PostgreSQL password (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# MinIO Configuration
variable "minio_root_password" {
  description = "MinIO root password (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}
