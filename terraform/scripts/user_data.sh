#!/bin/bash
# Colink Slack Clone - EC2 User Data Script
# This script runs on first boot to set up the application

set -e

# Variables from Terraform
PROJECT_NAME="${project_name}"
GITHUB_REPO="${github_repo}"
DOMAIN_NAME="${domain_name}"
ADMIN_EMAIL="${admin_email}"
ENVIRONMENT="${environment}"

# Log file
LOG_FILE="/var/log/colink-setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "=========================================="
echo "Colink Slack Clone Setup Script"
echo "Started at: $(date)"
echo "=========================================="

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y git docker htop vim wget curl jq unzip

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.0"
curl -L "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Start and enable Docker
echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/colink
cd /opt/colink

# Clone repository
echo "Cloning repository..."
git clone $GITHUB_REPO .

# Generate secure passwords
echo "Generating secure passwords..."
KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
MINIO_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
KC_DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

# Get instance public IP
echo "Getting instance public IP..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Public IP: $PUBLIC_IP"

# Create .env file
echo "Creating .env file..."
cat > /opt/colink/.env << EOF
# Environment
ENVIRONMENT=$ENVIRONMENT
NODE_ENV=production

# PostgreSQL Configuration
POSTGRES_USER=colink_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=colink_db
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Kafka/Redpanda Configuration
REDPANDA_BROKERS=redpanda:9092

# Keycloak Configuration
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD
KC_DB=postgres
KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db
KC_DB_USERNAME=keycloak_user
KC_DB_PASSWORD=$KC_DB_PASSWORD
KC_HOSTNAME=$PUBLIC_IP
KC_HOSTNAME_STRICT=false
KC_HOSTNAME_STRICT_HTTPS=false

# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_ENDPOINT=minio:9000
MINIO_BUCKET=colink-files

# JWT Configuration
JWT_SECRET=$JWT_SECRET

# Service Configuration
SUPERADMIN_USERNAME=admin
SUPERADMIN_EMAIL=admin@colink.local
SUPERADMIN_PASSWORD=Admin@123456

# CORS Configuration
CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000

# Frontend Configuration
NEXT_PUBLIC_KEYCLOAK_URL=http://$PUBLIC_IP:8080
NEXT_PUBLIC_KEYCLOAK_REALM=colink
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=web-app
NEXT_PUBLIC_AUTH_PROXY_URL=http://$PUBLIC_IP:8001
NEXT_PUBLIC_CHANNEL_SERVICE_URL=http://$PUBLIC_IP:8003
NEXT_PUBLIC_MESSAGE_SERVICE_URL=http://$PUBLIC_IP:8002
NEXT_PUBLIC_THREADS_SERVICE_URL=http://$PUBLIC_IP:8005
NEXT_PUBLIC_REACTIONS_SERVICE_URL=http://$PUBLIC_IP:8006
NEXT_PUBLIC_FILES_SERVICE_URL=http://$PUBLIC_IP:8007
NEXT_PUBLIC_NOTIFICATIONS_SERVICE_URL=http://$PUBLIC_IP:8008
NEXT_PUBLIC_WEBSOCKET_URL=http://$PUBLIC_IP:8009
EOF

# Create frontend .env.local
echo "Creating frontend .env.local..."
cat > /opt/colink/frontend/.env.local << EOF
NEXT_PUBLIC_KEYCLOAK_URL=http://$PUBLIC_IP:8080
NEXT_PUBLIC_KEYCLOAK_REALM=colink
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=web-app
NEXT_PUBLIC_AUTH_PROXY_URL=http://$PUBLIC_IP:8001
NEXT_PUBLIC_CHANNEL_SERVICE_URL=http://$PUBLIC_IP:8003
NEXT_PUBLIC_MESSAGE_SERVICE_URL=http://$PUBLIC_IP:8002
NEXT_PUBLIC_THREADS_SERVICE_URL=http://$PUBLIC_IP:8005
NEXT_PUBLIC_REACTIONS_SERVICE_URL=http://$PUBLIC_IP:8006
NEXT_PUBLIC_FILES_SERVICE_URL=http://$PUBLIC_IP:8007
NEXT_PUBLIC_NOTIFICATIONS_SERVICE_URL=http://$PUBLIC_IP:8008
NEXT_PUBLIC_WEBSOCKET_URL=http://$PUBLIC_IP:8009
EOF

# Update docker-compose.yml for production settings
echo "Updating docker-compose.yml..."

# Add CORS_ORIGINS to services that need it
sed -i "/- SERVICE_NAME=message/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml
sed -i "/- SERVICE_NAME=channel/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml
sed -i "/- SERVICE_NAME=threads/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml
sed -i "/- SERVICE_NAME=reactions/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml
sed -i "/- SERVICE_NAME=files/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml
sed -i "/- SERVICE_NAME=websocket/a\\      - CORS_ORIGINS=http://$PUBLIC_IP:3000,http://localhost:3000" docker-compose.yml

# Update MinIO public endpoint
sed -i "s|MINIO_PUBLIC_ENDPOINT=http://localhost:9000|MINIO_PUBLIC_ENDPOINT=http://$PUBLIC_IP:9000|g" docker-compose.yml

# Add Keycloak hostname settings
sed -i "/KC_DB_PASSWORD/a\\      - KC_HOSTNAME=$PUBLIC_IP" docker-compose.yml
sed -i "/KC_HOSTNAME=$PUBLIC_IP/a\\      - KC_HOSTNAME_STRICT=false" docker-compose.yml
sed -i "/KC_HOSTNAME_STRICT=false/a\\      - KC_HOSTNAME_STRICT_HTTPS=false" docker-compose.yml

# Build and start services
echo "Building Docker images..."
docker-compose build

echo "Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 60

# Check services status
echo "Checking services status..."
docker-compose ps

# Configure MinIO bucket permissions
echo "Configuring MinIO..."
sleep 30
docker exec colink-minio mc alias set local http://localhost:9000 minioadmin $MINIO_ROOT_PASSWORD || true
docker exec colink-minio mc anonymous set download local/colink || true
docker exec colink-minio mc anonymous set download local/colink-thumbnails || true

# Save credentials to a secure file
echo "Saving credentials..."
cat > /opt/colink/.credentials << EOF
# Colink Credentials - KEEP THIS FILE SECURE!
# Generated on: $(date)

PUBLIC_IP=$PUBLIC_IP

# Keycloak Admin
KEYCLOAK_URL=http://$PUBLIC_IP:8080
KEYCLOAK_ADMIN_USER=admin
KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD

# PostgreSQL
POSTGRES_USER=colink_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_CONSOLE=http://$PUBLIC_IP:9001

# Application URLs
FRONTEND_URL=http://$PUBLIC_IP:3000
EOF

chmod 600 /opt/colink/.credentials
chown root:root /opt/colink/.credentials

# Set proper ownership
chown -R ec2-user:ec2-user /opt/colink

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Access the application at:"
echo "  Frontend: http://$PUBLIC_IP:3000"
echo "  Keycloak: http://$PUBLIC_IP:8080"
echo ""
echo "Credentials saved to: /opt/colink/.credentials"
echo "View with: sudo cat /opt/colink/.credentials"
echo ""
echo "Next steps:"
echo "1. Configure Keycloak realm 'colink'"
echo "2. Create web-app client"
echo "3. Add users"
echo ""
echo "Completed at: $(date)"
