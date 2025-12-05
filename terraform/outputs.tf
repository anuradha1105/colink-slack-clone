# Colink Slack Clone - Terraform Outputs

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.colink.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.colink.public_dns
}

output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.colink_sg.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ec2-user@${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}"
}

output "application_urls" {
  description = "URLs to access the application"
  value = {
    frontend      = "http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:3000"
    keycloak      = "http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:8080"
    auth_proxy    = "http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:8001"
    minio_console = "http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:9001"
  }
}

output "service_ports" {
  description = "Ports for all services"
  value = {
    frontend      = 3000
    keycloak      = 8080
    auth_proxy    = 8001
    message       = 8002
    channel       = 8003
    threads       = 8005
    reactions     = 8006
    files         = 8007
    notifications = 8008
    websocket     = 8009
    minio_api     = 9000
    minio_console = 9001
  }
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.colink_logs.name
}

output "iam_role_arn" {
  description = "IAM Role ARN for the EC2 instance"
  value       = aws_iam_role.colink_ec2_role.arn
}

output "deployment_instructions" {
  description = "Next steps after terraform apply"
  value       = <<-EOT
    
    ========================================
    Colink Slack Clone Deployment Complete!
    ========================================
    
    1. Wait 5-10 minutes for the instance to initialize and install dependencies.
    
    2. SSH into the instance:
       ssh -i <your-key.pem> ec2-user@${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}
    
    3. Check the deployment status:
       sudo tail -f /var/log/cloud-init-output.log
    
    4. Once ready, access the application:
       Frontend: http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:3000
       Keycloak: http://${var.create_elastic_ip ? aws_eip.colink_eip[0].public_ip : aws_instance.colink.public_ip}:8080
    
    5. Configure Keycloak:
       - Create 'colink' realm
       - Create 'web-app' client
       - Add users as needed
    
    6. Update frontend environment variables if needed:
       sudo vim /opt/colink/frontend/.env.local
    
    For detailed setup instructions, see the project README.md
    
  EOT
}
