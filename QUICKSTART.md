# Colink Quick Start Guide

## 🚀 Get Started in 5 Minutes

This guide will get you up and running with the complete Colink application (frontend + backend) in your local development environment.

---

## Prerequisites

Before you begin, ensure you have:

- **Docker** & **Docker Compose** installed (Docker Desktop recommended)
- **Node.js 18+** installed (for frontend development)
- **Python 3.11+** installed (for backend development)
- At least **8GB RAM** available for Docker
- **Git** installed

### Check Prerequisites

```bash
# Check Docker
docker --version          # Should be 20.10+
docker-compose --version  # Should be 2.0+

# Check Node.js
node --version            # Should be 18.0.0+
npm --version             # Should be 9.0.0+

# Check Python
python3 --version         # Should be 3.11+
```

---

## Quick Start (Recommended)

### Option 1: Start Everything at Once

```bash
# Clone the repository
git clone https://github.com/yourorg/colink-slack-clone.git
cd colink-slack-clone

# Start all services (frontend, backend, infrastructure)
docker-compose up -d

# Wait 30-60 seconds for all services to start

# Check service status
docker-compose ps
```

**Access the application**:
- Frontend: http://localhost:3000
- Admin Dashboard: http://localhost:3000/admin (login as superadmin)
- Analytics: http://localhost:3000/analytics (admin only)

### Option 2: Start Services Separately (Advanced)

If you want more control or plan to develop locally without Docker:

```bash
# 1. Start infrastructure only
docker-compose up -d postgres redis redpanda minio keycloak opensearch prometheus grafana

# 2. Start backend services
docker-compose up -d auth-proxy message channel threads reactions files notifications websocket admin

# 3. Start frontend
docker-compose up -d frontend

# OR start frontend in development mode (hot reload)
cd frontend
npm install
npm run dev
```

---

## First-Time Setup

### 1. Create Superadmin User

After all services are running, create the superadmin user:

```bash
# Access the auth-proxy container
docker-compose exec auth-proxy bash

# Inside the container, run the superadmin creation script
python scripts/create_superadmin.py

# Follow the prompts:
# Username: admin (or your choice)
# Email: admin@colink.local
# Password: (your secure password)
# Display Name: System Administrator

# Exit the container
exit
```

### 2. Login and Verify

1. Open http://localhost:3000
2. Click "Login"
3. Enter your superadmin credentials
4. You should be redirected to the Admin Dashboard
5. Verify you can see the Analytics page

### 3. Create Test Users (Optional)

To test the messaging features, create some regular users:

1. Go to Admin Dashboard (you should already be there)
2. Click "Create New User"
3. Fill in user details:
   - Username: alice
   - Email: alice@colink.local
   - Display Name: Alice Smith
   - Role: member
4. Repeat for more test users (bob, charlie, etc.)

---

## Default Credentials

### Keycloak Admin Console

- URL: http://localhost:8080/admin
- Username: `admin`
- Password: `admin`

### MinIO Console

- URL: http://localhost:9001
- Username: `minioadmin`
- Password: `minioadmin`

### Grafana Dashboard

- URL: http://localhost:3001
- Username: `admin`
- Password: `admin`

### Prometheus

- URL: http://localhost:9090
- No authentication required

### PostgreSQL

- Host: `localhost`
- Port: `5432`
- Database: `colink_db`
- Username: `colink_user`
- Password: `colink_password`

### Redis

- Host: `localhost`
- Port: `6379`
- No password required

---

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f message
docker-compose logs -f auth-proxy

# Last 100 lines
docker-compose logs --tail=100 -f
```

### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart frontend
docker-compose restart message

# Rebuild and restart specific service
docker-compose build frontend
docker-compose up -d frontend
```

### Stop Services

```bash
# Stop all services
docker-compose stop

# Stop and remove containers (keeps data)
docker-compose down

# Stop and remove everything including volumes (⚠️ DELETES ALL DATA)
docker-compose down -v
```

### Database Operations

```bash
# Access PostgreSQL shell
docker-compose exec postgres psql -U colink_user -d colink_db

# View tables
\dt

# Query users
SELECT * FROM users;

# Exit
\q

# Backup database
docker-compose exec postgres pg_dump -U colink_user colink_db > backup.sql

# Restore database
docker-compose exec -T postgres psql -U colink_user colink_db < backup.sql
```

### Redis Operations

```bash
# Access Redis CLI
docker-compose exec redis redis-cli

# View all keys
KEYS *

# Get a value
GET user:123

# Clear all data (⚠️ CAREFUL!)
FLUSHALL

# Exit
exit
```

---

## Development Workflow

### Frontend Development

For hot-reload development (recommended for frontend work):

```bash
# Stop the Docker frontend container
docker-compose stop frontend

# Navigate to frontend directory
cd frontend

# Install dependencies (first time only)
npm install

# Start development server
npm run dev

# Frontend now running with hot reload at http://localhost:3000
```

### Backend Development

To develop backend services with auto-reload:

```bash
# Each backend service has a development mode with hot reload
# Edit docker-compose.yml and add:
#   volumes:
#     - ./backend/services/[service-name]:/app
#   environment:
#     - RELOAD=true

# Restart the service
docker-compose restart [service-name]
```

### Code Formatting & Linting

**Frontend**:
```bash
cd frontend
npm run lint        # Run ESLint
npm run type-check  # Run TypeScript checks
npm run format      # Format code with Prettier
```

**Backend**:
```bash
cd backend
pip install -r requirements-dev.txt
black .            # Format code
ruff check .       # Lint code
mypy .             # Type check
```

---

## Troubleshooting

### Port Already in Use

If you see errors like "port 3000 already allocated":

```bash
# Find process using the port
lsof -i :3000    # On macOS/Linux
netstat -ano | findstr :3000    # On Windows

# Kill the process
kill -9 <PID>    # On macOS/Linux

# Or change the port in docker-compose.yml
```

### Services Not Starting

```bash
# Check service status
docker-compose ps

# Check logs for errors
docker-compose logs [service-name]

# Restart specific service
docker-compose restart [service-name]

# Nuclear option: rebuild everything
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Keycloak Not Ready

Keycloak takes 30-60 seconds to fully start:

```bash
# Check Keycloak logs
docker-compose logs keycloak

# Wait for "Started" message
# Then try accessing http://localhost:8080
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Test connection
docker-compose exec postgres pg_isready -U colink_user

# View database logs
docker-compose logs postgres
```

### Frontend Build Errors

```bash
# Clear Next.js cache
cd frontend
rm -rf .next
npm run build

# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

### WebSocket Connection Issues

If real-time messages aren't working:

```bash
# Check WebSocket service
docker-compose logs websocket

# Verify WebSocket URL in frontend config
# frontend/src/lib/config.ts should have:
# websocket.url: 'http://localhost:8009'

# Restart WebSocket service
docker-compose restart websocket
```

### Docker Out of Memory

If services are crashing or slow:

1. Open Docker Desktop → Settings → Resources
2. Increase Memory to at least 8GB
3. Increase CPU cores to 4+
4. Click "Apply & Restart"

---

## Service URLs Reference

| Service | URL | Notes |
|---------|-----|-------|
| **Frontend** | http://localhost:3000 | Main application UI |
| **Admin Dashboard** | http://localhost:3000/admin | Superadmin only |
| **Analytics** | http://localhost:3000/analytics | Admin only |
| **Auth Proxy** | http://localhost:8001 | Auth & user management |
| **Message Service** | http://localhost:8002 | Messaging & analytics API |
| **Channel Service** | http://localhost:8003 | Channel management API |
| **Threads Service** | http://localhost:8005 | Thread management API |
| **Reactions Service** | http://localhost:8006 | Emoji reactions API |
| **Files Service** | http://localhost:8007 | File upload/download API |
| **Notifications Service** | http://localhost:8008 | Notifications API |
| **WebSocket Service** | http://localhost:8009 | Real-time events |
| **Admin Service** | http://localhost:8010 | Admin operations API |
| **Keycloak** | http://localhost:8080 | Identity provider |
| **MinIO Console** | http://localhost:9001 | Object storage UI |
| **Grafana** | http://localhost:3001 | Metrics dashboard |
| **Prometheus** | http://localhost:9090 | Metrics collection |

---

## Testing the Application

### Manual Testing

1. **Login as Superadmin**:
   - Go to http://localhost:3000
   - Login with superadmin credentials
   - Should redirect to Admin Dashboard

2. **Create Users**:
   - Create 2-3 test users (Alice, Bob, Charlie)
   - Set role as "member"

3. **Login as Regular User**:
   - Logout from superadmin
   - Login as Alice
   - Should redirect to channels page

4. **Test Messaging**:
   - Create a new channel
   - Send messages
   - Verify real-time updates
   - Test emoji reactions
   - Test file uploads

5. **Test Direct Messages**:
   - Click on another user in the sidebar
   - Send direct messages
   - Verify real-time delivery

6. **Test Threads**:
   - Reply to a message
   - View thread conversation
   - Test thread notifications

### Automated Testing

```bash
# Frontend tests
cd frontend
npm run test

# Backend tests (when implemented)
cd backend
pytest
```

---

## Next Steps

Now that your environment is running:

1. **📚 Read the Documentation**:
   - [README.md](./README.md) - Project overview
   - [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
   - [docs/](./docs/) - Detailed technical docs

2. **🛠️ Start Building**:
   - Explore the codebase
   - Make your first changes
   - Test your changes locally

3. **🤝 Contribute**:
   - Read [CONTRIBUTING.md](./CONTRIBUTING.md) (if available)
   - Create a feature branch
   - Submit a pull request

4. **🧪 Explore Features**:
   - Create channels and send messages
   - Test file uploads
   - Try emoji reactions
   - Check admin dashboard
   - View analytics

---

## Useful Commands Cheat Sheet

```bash
# Start everything
docker-compose up -d

# Stop everything
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Rebuild service
docker-compose build [service-name]
docker-compose up -d [service-name]

# Rebuild all services in parallel
docker-compose build

# Restart service
docker-compose restart [service-name]

# Access service shell
docker-compose exec [service-name] bash

# Access database
docker-compose exec postgres psql -U colink_user -d colink_db

# Access Redis
docker-compose exec redis redis-cli

# Check service status
docker-compose ps

# View resource usage
docker stats

# Clean up everything (⚠️ DELETES ALL DATA)
docker-compose down -v
docker system prune -af --volumes
```

---

## Getting Help

If you encounter issues:

1. **Check the logs**: `docker-compose logs -f [service-name]`
2. **Search existing issues**: Check GitHub issues for similar problems
3. **Read the docs**: Review ARCHITECTURE.md and README.md
4. **Ask for help**: Create a GitHub issue with:
   - What you were trying to do
   - What happened instead
   - Relevant log output
   - Your environment (OS, Docker version, etc.)

---

**Happy Coding! 🚀**

*Last Updated: 2025-12-04*
