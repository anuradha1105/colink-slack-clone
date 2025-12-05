#!/bin/bash
################################################################################
# Colink Quick Deploy Script for AWS
# Simplified version for direct copy-paste
################################################################################

set -e

echo "=========================================="
echo "Colink Quick Deploy Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run with sudo"
    exit 1
fi

# Update system
echo "1/9 Updating system..."
yum update -y > /dev/null 2>&1

# Install Docker
echo "2/9 Installing Docker..."
yum install -y docker > /dev/null 2>&1
systemctl start docker
systemctl enable docker > /dev/null 2>&1

# Install Docker Compose
echo "3/9 Installing Docker Compose..."
curl -SL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose > /dev/null 2>&1
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install Git
echo "4/9 Installing Git..."
yum install -y git > /dev/null 2>&1

# Get repository URL
echo ""
echo "5/9 Repository Setup"
read -p "Enter your GitHub repository URL (e.g., https://github.com/user/repo.git): " REPO_URL
if [ -z "$REPO_URL" ]; then
    echo "ERROR: Repository URL is required"
    exit 1
fi

# Clone repository
echo "6/9 Cloning repository..."
INSTALL_DIR="/opt/colink"
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory exists, pulling latest..."
    cd $INSTALL_DIR
    git pull
else
    git clone $REPO_URL $INSTALL_DIR
    cd $INSTALL_DIR
fi

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Detected public IP: $PUBLIC_IP"

# Create .env file
echo "7/9 Configuring environment..."
cat > .env <<EOF
NEXT_PUBLIC_AUTH_PROXY_URL=http://${PUBLIC_IP}:8001
NEXT_PUBLIC_CHANNEL_SERVICE_URL=http://${PUBLIC_IP}:8003
NEXT_PUBLIC_MESSAGE_SERVICE_URL=http://${PUBLIC_IP}:8002
NEXT_PUBLIC_THREADS_SERVICE_URL=http://${PUBLIC_IP}:8005
NEXT_PUBLIC_REACTIONS_SERVICE_URL=http://${PUBLIC_IP}:8006
NEXT_PUBLIC_FILES_SERVICE_URL=http://${PUBLIC_IP}:8007
NEXT_PUBLIC_NOTIFICATIONS_SERVICE_URL=http://${PUBLIC_IP}:8008
NEXT_PUBLIC_WEBSOCKET_URL=http://${PUBLIC_IP}:8009
NEXT_PUBLIC_KEYCLOAK_URL=http://${PUBLIC_IP}:8080
NEXT_PUBLIC_KEYCLOAK_REALM=colink
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=web-app
POSTGRES_USER=colink_user
POSTGRES_PASSWORD=colink_secure_pass_123
POSTGRES_DB=colink_db
KEYCLOAK_ADMIN_PASSWORD=admin_pass_123
MINIO_ROOT_PASSWORD=minio_pass_123
JWT_SECRET=your_jwt_secret_key_here
SUPERADMIN_USERNAME=admin
SUPERADMIN_EMAIL=admin@colink.local
SUPERADMIN_PASSWORD=Admin@123456
EOF

# Build and start
echo "8/9 Building and starting services (this will take 10-15 minutes)..."
docker-compose build --parallel
docker-compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 90

# Create superadmin
echo "9/9 Creating superadmin user..."
sleep 30
docker-compose exec -T auth-proxy python /app/scripts/setup_superadmin.py 2>/dev/null || echo "Note: Superadmin creation via script failed, you may need to create manually"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Frontend:        http://${PUBLIC_IP}:3000"
echo "  Admin Dashboard: http://${PUBLIC_IP}:3000/admin"
echo "  Keycloak:        http://${PUBLIC_IP}:8080/admin"
echo "  MinIO Console:   http://${PUBLIC_IP}:9001"
echo "  Grafana:         http://${PUBLIC_IP}:3001"
echo ""
echo "Superadmin Credentials:"
echo "  Username: admin"
echo "  Password: Admin@123456"
echo ""
echo "IMPORTANT: Change the default password after first login!"
echo ""
echo "Useful commands:"
echo "  View logs:    cd /opt/colink && docker-compose logs -f"
echo "  Restart:      cd /opt/colink && docker-compose restart"
echo "  Stop:         cd /opt/colink && docker-compose down"
echo ""
