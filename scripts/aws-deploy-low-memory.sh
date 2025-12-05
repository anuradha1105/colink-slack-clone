#!/bin/bash
################################################################################
# Colink AWS Deployment Script - Low Memory Edition (3GB RAM)
#
# Optimized for systems with limited RAM (3-4GB)
# - Builds services sequentially instead of parallel
# - Adds swap space
# - Reduces concurrent container count during build
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/darshlukkad/colink-slack-clone.git"
REPO_BRANCH="main"
INSTALL_DIR="/opt/colink"
SUPERADMIN_USERNAME="admin"
SUPERADMIN_EMAIL="admin@colink.local"
SUPERADMIN_PASSWORD="Admin@123456"

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

create_swap() {
    print_header "Creating Swap Space"

    # Check if swap already exists
    if swapon --show | grep -q "/swapfile"; then
        print_info "Swap file already exists"
        return 0
    fi

    print_info "Creating 4GB swap file to supplement RAM..."

    # Create 4GB swap file
    dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # Make it permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    print_success "Swap space created: 4GB"
    free -h
}

install_dependencies() {
    print_header "Installing System Dependencies"

    print_info "Updating system packages..."
    yum update -y

    print_info "Installing basic tools..."
    yum install -y git wget vim htop jq nc lsof || true

    print_success "System dependencies installed"
}

install_docker() {
    print_header "Installing Docker"

    if command -v docker &> /dev/null; then
        print_info "Docker already installed: $(docker --version)"
        return 0
    fi

    yum install -y docker
    systemctl start docker
    systemctl enable docker

    print_success "Docker installed: $(docker --version)"
}

install_docker_compose() {
    print_header "Installing Docker Compose"

    if command -v docker-compose &> /dev/null; then
        print_info "Docker Compose already installed: $(docker-compose --version)"
        return 0
    fi

    DOCKER_COMPOSE_VERSION="v2.24.5"
    mkdir -p /usr/local/lib/docker/cli-plugins

    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

    print_success "Docker Compose installed: $(docker-compose --version)"
}

clone_repository() {
    print_header "Cloning Repository"

    mkdir -p $INSTALL_DIR

    if [ -d "$INSTALL_DIR/.git" ]; then
        print_info "Repository already exists. Pulling latest changes..."
        cd $INSTALL_DIR
        git fetch origin
        git checkout $REPO_BRANCH
        git pull origin $REPO_BRANCH
    else
        print_info "Cloning repository from $REPO_URL..."
        git clone -b $REPO_BRANCH $REPO_URL $INSTALL_DIR
    fi

    cd $INSTALL_DIR
    print_success "Repository ready at $INSTALL_DIR"
}

configure_environment() {
    print_header "Configuring Environment Variables"

    cd $INSTALL_DIR

    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "localhost")
    print_info "Public IP: $PUBLIC_IP"

    cat > .env <<EOF
# Colink Environment Configuration - Low Memory Edition
# Generated on $(date)

# Public URLs
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

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=colink_db
POSTGRES_USER=colink_user
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Keycloak Configuration
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -base64 24)
KC_DB=postgres
KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db
KC_DB_USERNAME=keycloak_user
KC_DB_PASSWORD=$(openssl rand -base64 32)

# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$(openssl rand -base64 24)
MINIO_ENDPOINT=minio:9000
MINIO_BUCKET=colink-files

# Redpanda Configuration
REDPANDA_BROKERS=redpanda:9092

# JWT Secret
JWT_SECRET=$(openssl rand -base64 64)

# Superadmin Configuration
SUPERADMIN_USERNAME=$SUPERADMIN_USERNAME
SUPERADMIN_EMAIL=$SUPERADMIN_EMAIL
SUPERADMIN_PASSWORD=$SUPERADMIN_PASSWORD

# Environment
NODE_ENV=production
ENVIRONMENT=production
EOF

    print_success "Environment configured"
}

build_infrastructure() {
    print_header "Building Infrastructure Services"

    cd $INSTALL_DIR

    print_info "Starting infrastructure services (postgres, redis, keycloak, etc.)..."
    docker-compose up -d postgres redis redpanda minio keycloak opensearch prometheus grafana

    print_info "Waiting 60 seconds for infrastructure to be ready..."
    sleep 60

    print_success "Infrastructure services started"
}

build_backend_sequential() {
    print_header "Building Backend Services (Sequential - Low Memory Mode)"

    cd $INSTALL_DIR

    # Build backend services one at a time to avoid memory issues
    BACKEND_SERVICES=("auth-proxy" "message" "channel" "threads" "reactions" "files" "notifications" "websocket" "admin")

    for service in "${BACKEND_SERVICES[@]}"; do
        print_info "Building $service..."
        docker-compose build $service
        print_success "$service built"
    done
}

build_frontend() {
    print_header "Building Frontend Service"

    cd $INSTALL_DIR

    print_info "Building frontend..."
    docker-compose build frontend

    print_success "Frontend built"
}

start_backend_services() {
    print_header "Starting Backend Services"

    cd $INSTALL_DIR

    print_info "Starting backend services..."
    docker-compose up -d auth-proxy message channel threads reactions files notifications websocket admin

    print_info "Waiting 30 seconds for backend services to start..."
    sleep 30

    print_success "Backend services started"
}

start_frontend() {
    print_header "Starting Frontend Service"

    cd $INSTALL_DIR

    print_info "Starting frontend..."
    docker-compose up -d frontend

    print_info "Waiting 20 seconds for frontend to start..."
    sleep 20

    print_success "Frontend started"
}

create_superadmin() {
    print_header "Creating Superadmin User"

    cd $INSTALL_DIR

    print_info "Ensuring auth-proxy is ready..."
    sleep 15

    print_info "Creating superadmin user: $SUPERADMIN_USERNAME"

    if docker-compose exec -T auth-proxy python /app/scripts/setup_superadmin.py 2>/dev/null; then
        print_success "Superadmin created via setup script"
    else
        print_warning "Setup script not found. You can create superadmin manually:"
        print_info "Run: cd $INSTALL_DIR && docker-compose exec auth-proxy python /app/scripts/setup_superadmin.py"
    fi

    print_info "Username: $SUPERADMIN_USERNAME"
    print_info "Email: $SUPERADMIN_EMAIL"
    print_warning "Password: $SUPERADMIN_PASSWORD"
    print_warning "IMPORTANT: Change this password after first login!"
}

cleanup_build_cache() {
    print_header "Cleaning Up Docker Build Cache"

    print_info "Removing unused Docker images and build cache..."
    docker system prune -f

    print_success "Build cache cleaned"
}

print_access_info() {
    print_header "Deployment Complete!"

    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "YOUR_SERVER_IP")

    echo -e "${GREEN}"
    echo "================================================"
    echo "   Colink Deployed Successfully!"
    echo "   Low Memory Edition (3GB RAM + 4GB Swap)"
    echo "================================================"
    echo -e "${NC}"

    echo -e "\n${BLUE}Access URLs:${NC}"
    echo -e "  Frontend:          ${GREEN}http://${PUBLIC_IP}:3000${NC}"
    echo -e "  Admin Dashboard:   ${GREEN}http://${PUBLIC_IP}:3000/admin${NC}"
    echo -e "  Analytics:         ${GREEN}http://${PUBLIC_IP}:3000/analytics${NC}"
    echo -e "  Keycloak Admin:    ${GREEN}http://${PUBLIC_IP}:8080/admin${NC}"
    echo -e "  MinIO Console:     ${GREEN}http://${PUBLIC_IP}:9001${NC}"
    echo -e "  Grafana:           ${GREEN}http://${PUBLIC_IP}:3001${NC}"

    echo -e "\n${BLUE}Superadmin Credentials:${NC}"
    echo -e "  Username: ${GREEN}$SUPERADMIN_USERNAME${NC}"
    echo -e "  Email:    ${GREEN}$SUPERADMIN_EMAIL${NC}"
    echo -e "  Password: ${YELLOW}$SUPERADMIN_PASSWORD${NC}"
    echo -e "  ${RED}⚠ CHANGE THIS PASSWORD AFTER FIRST LOGIN!${NC}"

    echo -e "\n${BLUE}System Resources:${NC}"
    echo -e "  ${YELLOW}Note: Running on 3GB RAM with 4GB swap${NC}"
    echo -e "  ${YELLOW}Performance may be slower than 8GB RAM systems${NC}"
    free -h

    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo -e "  View logs:         ${GREEN}cd $INSTALL_DIR && docker-compose logs -f${NC}"
    echo -e "  Check memory:      ${GREEN}free -h${NC}"
    echo -e "  Check containers:  ${GREEN}docker stats${NC}"
    echo -e "  Restart:           ${GREEN}cd $INSTALL_DIR && docker-compose restart${NC}"

    echo -e "\n${YELLOW}Low Memory Tips:${NC}"
    echo "  - Services may take longer to start"
    echo "  - Monitor memory usage: watch -n 5 free -h"
    echo "  - If services crash, restart them: docker-compose restart"
    echo "  - Consider upgrading to 8GB RAM for production use"

    echo ""
}

main() {
    clear

    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║                                                    ║"
    echo "║    Colink AWS Deployment - Low Memory Edition     ║"
    echo "║           Optimized for 3GB RAM Systems           ║"
    echo "║                                                    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    print_warning "This deployment is optimized for low-memory systems (3GB RAM)"
    print_warning "Build process will be slower (sequential instead of parallel)"
    print_warning "Estimated time: 25-35 minutes"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi

    # Pre-flight checks
    check_root

    # Create swap space first
    create_swap

    # Install dependencies
    install_dependencies
    install_docker
    install_docker_compose

    # Setup application
    clone_repository
    configure_environment

    # Build and deploy infrastructure first
    build_infrastructure

    # Build backend services sequentially (low memory mode)
    build_backend_sequential

    # Build frontend
    build_frontend

    # Start backend services
    start_backend_services

    # Start frontend
    start_frontend

    # Clean up to free memory
    cleanup_build_cache

    # Create superadmin
    create_superadmin

    # Print access information
    print_access_info

    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
