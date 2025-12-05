# Colink Slack Clone - Terraform Infrastructure

This directory contains Terraform scripts to deploy the Colink Slack Clone application infrastructure on AWS.

## Prerequisites

1. **Terraform** >= 1.0 installed
2. **AWS CLI** configured with appropriate credentials
3. **SSH Key Pair** (existing or will be created)

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Create your variables file

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
aws_region        = "ap-south-1"
project_name      = "colink"
environment       = "production"
instance_type     = "t3.large"
existing_key_name = "your-ssh-key-name"  # Your existing AWS key pair name
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Deploy the infrastructure

```bash
terraform apply
```

### 5. Access the application

After deployment completes (wait 5-10 minutes for initialization):

```bash
# Get the outputs
terraform output

# SSH into the instance
ssh -i your-key.pem ec2-user@<PUBLIC_IP>

# Check deployment status
sudo tail -f /var/log/cloud-init-output.log

# View saved credentials
sudo cat /opt/colink/.credentials
```

## Infrastructure Components

| Resource | Description |
|----------|-------------|
| EC2 Instance | Runs all Docker containers |
| Security Group | Opens required ports (3000, 8001-8009, 8080, 9000-9001) |
| Elastic IP | Static public IP address |
| IAM Role | For SSM and CloudWatch access |
| CloudWatch Logs | Application logging |
| CloudWatch Alarms | CPU and disk usage monitoring |

## Ports Opened

| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP (for future HTTPS redirect) |
| 443 | HTTPS |
| 3000 | Frontend (Next.js) |
| 8001 | Auth Proxy |
| 8002 | Message Service |
| 8003 | Channel Service |
| 8005 | Threads Service |
| 8006 | Reactions Service |
| 8007 | Files Service |
| 8008 | Notifications Service |
| 8009 | WebSocket Service |
| 8080 | Keycloak |
| 9000 | MinIO API |
| 9001 | MinIO Console |

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `ap-south-1` |
| `project_name` | Project name for resource naming | `colink` |
| `environment` | Environment (dev/staging/production) | `production` |
| `instance_type` | EC2 instance type | `t3.large` |
| `root_volume_size` | Root EBS volume size in GB | `50` |
| `create_elastic_ip` | Create Elastic IP | `true` |
| `ssh_allowed_cidr` | CIDR blocks for SSH access | `["0.0.0.0/0"]` |
| `existing_key_name` | Existing SSH key pair name | `""` |

## Post-Deployment Setup

After the infrastructure is deployed, you need to configure Keycloak:

1. **Access Keycloak Admin Console**
   ```
   http://<PUBLIC_IP>:8080
   ```
   Login with credentials from `/opt/colink/.credentials`

2. **Create Realm**
   - Create a new realm named `colink`

3. **Create Client**
   - Client ID: `web-app`
   - Client Protocol: `openid-connect`
   - Access Type: `public`
   - Valid Redirect URIs: `http://<PUBLIC_IP>:3000/*`
   - Web Origins: `+` or `http://<PUBLIC_IP>:3000`

4. **Create Users**
   - Add users as needed
   - Set passwords

5. **Access the Application**
   ```
   http://<PUBLIC_IP>:3000
   ```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Customization

### Using a Custom Domain

1. Set `domain_name` variable in `terraform.tfvars`
2. After deployment, configure DNS to point to the Elastic IP
3. Set up SSL certificates (Let's Encrypt recommended)

### Scaling

For production workloads, consider:
- Use `t3.xlarge` or larger instance type
- Enable `create_data_volume` for data persistence
- Set up regular backups
- Configure CloudWatch Alarms with SNS notifications

## Troubleshooting

### Check cloud-init logs
```bash
sudo tail -f /var/log/cloud-init-output.log
```

### Check Docker services
```bash
cd /opt/colink
sudo docker-compose ps
sudo docker-compose logs -f
```

### Restart services
```bash
cd /opt/colink
sudo docker-compose restart
```

## Security Recommendations

1. **Restrict SSH access**: Update `ssh_allowed_cidr` to your IP only
2. **Use HTTPS**: Set up SSL certificates for production
3. **Rotate credentials**: Regularly rotate Keycloak and database passwords
4. **Enable backups**: Set up automated EBS snapshots
5. **Monitor**: Configure CloudWatch alarms with notifications

## Support

For issues, please check:
1. Cloud-init logs: `/var/log/cloud-init-output.log`
2. Application logs: `docker-compose logs -f`
3. Project documentation: Main README.md
