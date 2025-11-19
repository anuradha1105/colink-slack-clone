# Colink Quick Start Guide

## 🚀 Get Started in 5 Minutes

This guide will get you up and running with the Colink development environment.

---

## Prerequisites

Before you begin, ensure you have:

- **Docker** & **Docker Compose** installed
- **Python 3.12+** installed
- **Make** installed (comes with Xcode Command Line Tools on macOS)
- At least **4GB RAM** available for Docker

### Check Prerequisites

```bash
# Check Docker
docker --version
docker-compose --version

# Check Python
python3 --version  # Should be 3.12 or higher

# Check Make
make --version
```

---

## Step 1: Initial Setup

Run the one-command setup:

```bash
make setup
```

This will:
- ✅ Install Python dependencies
- ✅ Create `.env` file from template
- ✅ Set up development environment

---

## Step 2: Start Infrastructure

Start all infrastructure services (Postgres, Redis, Kafka, etc.):

```bash
make infra-up
```

This starts:
- **PostgreSQL** (localhost:5432)
- **Redis** (localhost:6379)
- **Redpanda/Kafka** (localhost:19092)
- **MinIO** (localhost:9000, console: 9001)
- **Keycloak** (localhost:8080)
- **OpenSearch** (localhost:9200)

**Wait ~30 seconds** for all services to be healthy.

---

## Step 3: Initialize Database

Run database migrations to create tables:

```bash
make migrate
```

---

## Step 4: Verify Setup

Check that everything is running:

```bash
make health
```

You should see green checkmarks (✓) for all infrastructure services.

---

## 🎉 You're Ready!

Access the services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Keycloak Admin** | http://localhost:8080/admin | admin / admin |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin |
| **PostgreSQL** | localhost:5432 | colink / colink_password |
| **Redis** | localhost:6379 | (no password) |
| **OpenSearch** | http://localhost:9200 | admin / admin |

---

## Common Commands

### Development

```bash
# Start all services in development mode
make dev

# Start in background
make dev-detached

# Stop all services
make stop

# View logs
make logs

# View logs for specific service
make logs-service SERVICE=messaging-service
```

### Database

```bash
# Run migrations
make migrate

# Generate new migration
make migrate-auto

# Rollback last migration
make migrate-down

# Open database shell
make db-shell

# Seed test data
make seed
```

### Testing

```bash
# Run all tests
make test

# Run with coverage
make test-cov

# Run only unit tests
make test-unit
```

### Code Quality

```bash
# Format code
make format

# Run linters
make lint

# Check formatting without changes
make format-check
```

### Cleanup

```bash
# Stop and remove containers
make down

# Clean up build artifacts
make clean

# Complete reset (careful!)
make reset
```

---

## Troubleshooting

### Port Already in Use

If you see "port already allocated" errors:

```bash
# Find process using port (e.g., 5432 for Postgres)
lsof -i :5432

# Kill the process
kill -9 <PID>
```

### Docker Out of Memory

Increase Docker Desktop memory:
1. Docker Desktop → Preferences → Resources
2. Set Memory to at least 4GB
3. Click "Apply & Restart"

### Services Not Starting

```bash
# Check service logs
make logs-service SERVICE=postgres

# Restart specific service
make service-restart SERVICE=postgres

# Nuclear option: full cleanup and restart
make down
docker system prune -f
make infra-up
```

### Database Connection Issues

```bash
# Check if Postgres is ready
docker-compose exec postgres pg_isready -U colink

# Manually connect to verify
make db-shell
```

---

## Next Steps

Now that your environment is ready:

1. **📚 Read Architecture Docs**: [ARCHITECTURE.md](./ARCHITECTURE.md)
2. **🛠️ Start Building**: Begin with [auth-proxy service](./services/auth-proxy/)
3. **🧪 Write Tests**: Check [tests/README.md](./tests/README.md)
4. **📖 API Docs**: Review [docs/architecture/05-service-inventory.md](./docs/architecture/05-service-inventory.md)

---

## Development Workflow

Typical daily workflow:

```bash
# Morning: Start infrastructure
make infra-up

# Run migrations (if any new ones)
make migrate

# Start developing
make dev

# Make code changes...

# Format and lint before committing
make format
make lint

# Run tests
make test

# Evening: Stop everything
make stop
```

---

## Help

View all available commands:

```bash
make help
```

For more detailed documentation, see:
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [CONTRIBUTING.md](./CONTRIBUTING.md) - Contribution guidelines
- [docs/](./docs/) - Detailed technical documentation

---

**Happy Coding! 🚀**
