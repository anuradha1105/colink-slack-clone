# Colink - Real-time Collaboration Platform

[![Architecture](https://img.shields.io/badge/docs-architecture-blue)](./ARCHITECTURE.md)
[![Python](https://img.shields.io/badge/python-3.11-blue)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-green)](https://fastapi.tiangolo.com/)
[![Next.js](https://img.shields.io/badge/Next.js-16.0-black)](https://nextjs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

> **Production-ready collaboration platform** built with modern microservices architecture, featuring real-time messaging, channels, direct messages, file sharing, analytics, and comprehensive admin tools.

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/darshlukkad/colink-slack-clone.git
cd colink-slack-clone

# Start all services with Docker Compose
docker-compose up -d

# Wait for services to be healthy (~30-60 seconds)
docker-compose ps

# Set up superadmin user
docker exec colink-auth-proxy python /app/scripts/setup_superadmin.py

# Access the platform
# Frontend: http://localhost:3000
# Superadmin credentials:
#   Username: superadmin
#   Password: SuperAdmin@123
```

See **[QUICKSTART.md](./QUICKSTART.md)** for detailed setup instructions.

---

## ✨ Features

### Core Functionality
- ✅ **Modern UI**: Next.js 16 with Turbopack, TailwindCSS, React Query
- ✅ **Authentication**: OAuth 2.0/OIDC via Keycloak integration
- ✅ **Real-time Messaging**: WebSocket-based instant message delivery
- ✅ **Channels**: Public and private channels with member management
- ✅ **Direct Messages**: One-on-one conversations
- ✅ **Threaded Conversations**: Organize discussions with message threads
- ✅ **Emoji Reactions**: React to messages with emoji support
- ✅ **File Sharing**: Upload and share files with MinIO object storage
- ✅ **Presence System**: Online status and typing indicators
- ✅ **User Profiles**: Customizable profiles with avatars
- ✅ **Notifications**: Real-time push notifications

### Admin & Analytics
- ✅ **Admin Dashboard**: User management, role assignment, user deletion
- ✅ **Analytics Dashboard**: Usage statistics, channel activity, message trends
- ✅ **Role-Based Access**: Admin, Moderator, Member, Guest roles
- ✅ **Superadmin Mode**: Hidden admin user for system management
- ✅ **Monitoring**: Prometheus metrics, Grafana dashboards
- ✅ **Audit Logging**: Comprehensive activity tracking

### Developer Experience
- ✅ **Hot Reload**: Fast development with Next.js Turbopack
- ✅ **Type Safety**: Full TypeScript support
- ✅ **API Documentation**: Auto-generated Swagger/OpenAPI docs
- ✅ **Docker Compose**: One-command setup for all services
- ✅ **Health Checks**: Built-in health monitoring for all services

---

## 🏗️ Architecture

### Microservices (10 Services)

| Service | Responsibilities | Port | Status |
|---------|-----------------|------|--------|
| **frontend** | Next.js 16 web application | 3000 | ✅ Production |
| **auth-proxy** | Authentication, JWT validation, admin API | 8001 | ✅ Production |
| **channel** | Channel CRUD, membership management | 8003 | ✅ Production |
| **message** | Messages, DMs, analytics API | 8002 | ✅ Production |
| **threads** | Thread replies and management | 8005 | ✅ Production |
| **reactions** | Emoji reactions to messages | 8006 | ✅ Production |
| **files** | File upload/download, MinIO integration | 8007 | ✅ Production |
| **notifications** | Push notifications, user alerts | 8008 | ✅ Production |
| **websocket** | Real-time WebSocket connections | 8009 | ✅ Production |

### Infrastructure Components

| Component | Technology | Port | Purpose |
|-----------|-----------|------|---------|
| **postgres** | PostgreSQL 16 | 5432 | Primary database |
| **redis** | Redis 7 | 6379 | Caching & session storage |
| **redpanda** | Kafka-compatible | 19092 | Event streaming |
| **keycloak** | Keycloak 23.x | 8080 | Identity & access management |
| **minio** | MinIO S3-compatible | 9000, 9001 | Object storage |
| **opensearch** | OpenSearch 2.x | 9200 | Full-text search |
| **prometheus** | Prometheus | 9090 | Metrics collection |
| **grafana** | Grafana | 3001 | Metrics visualization |

### Technology Stack

#### Frontend
| Component | Technology | Version |
|-----------|-----------|---------|
| **Framework** | Next.js | 16.0.4 |
| **Build Tool** | Turbopack | Latest |
| **UI Library** | React | 19.x |
| **Styling** | TailwindCSS | 3.x |
| **State Management** | Zustand, React Query | Latest |
| **Icons** | Lucide React | Latest |
| **Forms** | React Hook Form | Latest |

#### Backend
| Component | Technology | Version |
|-----------|-----------|---------|
| **Runtime** | Python | 3.11 |
| **Framework** | FastAPI | 0.115+ |
| **Server** | Uvicorn | Latest |
| **Database** | PostgreSQL | 16 |
| **ORM** | SQLAlchemy | 2.0 |
| **Cache** | Redis | 7 |
| **Message Queue** | Redpanda (Kafka) | Latest |
| **Auth** | Keycloak | 23.x |

---

## 📁 Project Structure

```
colink-slack-clone/
├── frontend/                 # Next.js 16 frontend application
│   ├── src/
│   │   ├── app/             # Next.js app router pages
│   │   │   ├── admin/       # Admin dashboard
│   │   │   ├── analytics/   # Analytics dashboard
│   │   │   ├── auth/        # Authentication pages
│   │   │   ├── channels/    # Channel pages
│   │   │   └── login/       # Login page
│   │   ├── components/      # React components
│   │   ├── contexts/        # React contexts (WebSocket, etc.)
│   │   ├── hooks/           # Custom React hooks
│   │   ├── lib/             # API clients, utilities
│   │   ├── store/           # Zustand stores
│   │   └── types/           # TypeScript types
│   ├── public/              # Static assets
│   └── package.json
│
├── backend/
│   ├── shared/              # Shared database models and utilities
│   │   └── database/        # SQLAlchemy models
│   └── services/
│       ├── auth-proxy/      # Authentication service
│       ├── channel/         # Channel management
│       ├── message/         # Messaging + Analytics
│       ├── threads/         # Thread management
│       ├── reactions/       # Emoji reactions
│       ├── files-service/   # File storage
│       ├── notifications/   # Notifications
│       └── websocket/       # WebSocket gateway
│
├── scripts/                 # Utility scripts
│   ├── setup_superadmin.sh  # Bash script for superadmin setup
│   ├── setup_superadmin.py  # Python script for superadmin setup (recommended)
│   └── README.md            # Scripts documentation
│
├── monitoring/              # Monitoring configurations
│   └── grafana-dashboard.json
│
├── docs/                    # Documentation
│   ├── architecture/        # Architecture docs
│   └── diagrams/           # System diagrams
│
├── docker-compose.yml       # Docker Compose configuration
├── ARCHITECTURE.md          # Architecture overview
├── QUICKSTART.md           # Quick start guide
├── SUPERADMIN_SETUP.md     # Superadmin setup guide
├── RECENT_CHANGES.md       # Recent changes and updates
└── README.md               # This file
```

---

## 🛠️ Development Setup

### Prerequisites

- Docker Desktop or Docker Engine with Docker Compose
- Git
- (Optional) Python 3.11+ for local backend development
- (Optional) Node.js 20+ for local frontend development

### Quick Setup

```bash
# 1. Clone repository
git clone https://github.com/darshlukkad/colink-slack-clone.git
cd colink-slack-clone

# 2. Start all services
docker-compose up -d

# 3. Wait for services to be healthy
docker-compose ps

# 4. Set up superadmin
docker exec colink-auth-proxy python /app/scripts/setup_superadmin.py

# 5. Access the application
open http://localhost:3000
```

### Verify Installation

```bash
# Check all services are running and healthy
docker-compose ps

# Expected output: All services should show "Up" and "(healthy)"
# Example:
# colink-frontend     Up 2 minutes (healthy)
# colink-auth-proxy   Up 2 minutes (healthy)
# colink-message      Up 2 minutes (healthy)
# ...

# Check frontend logs
docker logs colink-frontend

# Check backend logs
docker logs colink-message
```

### Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://localhost:3000 | superadmin / SuperAdmin@123 |
| **Keycloak Admin** | http://localhost:8080/admin | admin / admin |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin |
| **Grafana** | http://localhost:3001 | admin / admin |
| **Prometheus** | http://localhost:9090 | N/A |

---

## 🧪 Testing

### Frontend Testing

```bash
cd frontend

# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

### Backend Testing

```bash
cd backend

# Run all tests
pytest

# Run specific service tests
pytest services/message/tests/

# Run with coverage
pytest --cov=services --cov-report=html
```

---

## 📖 API Documentation

### Interactive API Docs (Swagger UI)

Once services are running, access interactive API documentation:

- **Auth Proxy**: http://localhost:8001/docs
- **Channel Service**: http://localhost:8003/docs
- **Message Service**: http://localhost:8002/docs
- **Threads Service**: http://localhost:8005/docs
- **Reactions Service**: http://localhost:8006/docs
- **Files Service**: http://localhost:8007/docs
- **Notifications Service**: http://localhost:8008/docs

### Example API Calls

```bash
# 1. Login via Keycloak (handled by frontend)
# Frontend redirects to http://localhost:8080/realms/colink/protocol/openid-connect/auth

# 2. Get all channels (authenticated)
curl http://localhost:8003/channels \
  -H "Authorization: Bearer <YOUR_TOKEN>"

# 3. Send a message
curl -X POST http://localhost:8002/messages \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "channel_id": "<CHANNEL_ID>",
    "text": "Hello, Colink!"
  }'

# 4. Get analytics (admin only)
curl http://localhost:8002/analytics/summary \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

---

## 🔐 Security

### Authentication & Authorization
- **OAuth 2.0/OIDC**: Full integration with Keycloak
- **JWT Tokens**: Secure token-based authentication
- **Role-Based Access Control (RBAC)**:
  - **Admin**: Full system access, user management, analytics
  - **Moderator**: Channel moderation, content management
  - **Member**: Standard user access
  - **Guest**: Limited read-only access
- **Superadmin**: Hidden system administrator (excluded from user lists)

### Security Features
- **TLS/HTTPS**: All production traffic encrypted
- **Token Refresh**: Automatic token refresh on expiry
- **Rate Limiting**: Protection against abuse
- **CORS**: Configured cross-origin resource sharing
- **File Validation**: File type and size validation
- **XSS Protection**: Content sanitization

### Default Credentials

⚠️ **Change these in production!**

| Service | Username | Password |
|---------|----------|----------|
| Superadmin | superadmin | SuperAdmin@123 |
| Keycloak Admin | admin | admin |
| MinIO | minioadmin | minioadmin |
| Grafana | admin | admin |

---

## 🚢 Deployment

### Docker Compose (Development/Staging)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ deletes data)
docker-compose down -v
```

### Production Deployment

For production deployment:

1. **Update Environment Variables**:
   - Set strong passwords for all services
   - Configure proper domain names
   - Set `NODE_ENV=production`
   - Enable HTTPS/TLS

2. **Use External Databases** (recommended):
   - Managed PostgreSQL (AWS RDS, Google Cloud SQL)
   - Managed Redis (ElastiCache, Google Memorystore)
   - Managed Kafka (Confluent Cloud, AWS MSK)

3. **Enable Monitoring**:
   - Configure Prometheus alerts
   - Set up Grafana dashboards
   - Enable error tracking (Sentry)

4. **Backup Strategy**:
   - Automated database backups
   - Object storage replication
   - Disaster recovery plan

---

## 📊 Monitoring & Observability

### Grafana Dashboards

Pre-configured dashboards available at http://localhost:3001:

- **System Overview**: CPU, memory, disk usage
- **Service Health**: Request rates, error rates, latencies
- **Business Metrics**: Active users, message counts, channel activity
- **Database**: Connection pool, query performance
- **WebSocket**: Active connections, message throughput

### Prometheus Metrics

Key metrics exposed by services:

- `http_request_duration_seconds` - API latency
- `http_requests_total` - Request counts
- `websocket_connections` - Active WebSocket connections
- `kafka_consumer_lag` - Message queue lag
- `db_connection_pool_size` - Database connection usage

### Log Aggregation

```bash
# View logs for specific service
docker logs colink-frontend
docker logs colink-message

# Follow logs in real-time
docker logs -f colink-websocket

# View logs for all services
docker-compose logs -f
```

---

## 🎯 Key Features

### Admin Dashboard
- **User Management**: View, create, delete users
- **Role Assignment**: Assign admin/moderator roles
- **User Search**: Filter and search users
- **Activity Monitoring**: Track user activity

### Analytics Dashboard
- **Total Counts**: Users, channels, messages
- **Top Channels**: Most active channels by message count
- **Daily Trends**: Message activity over last 7 days
- **User Engagement**: Active users, messages per day

### Superadmin Features
- **Hidden from Users**: Not visible in DM lists or searches
- **Full System Access**: Complete administrative control
- **Separate Dashboard**: Dedicated admin interface
- **Auto-redirect**: Admins redirected to `/admin` on login

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
4. **Test your changes**:
   ```bash
   npm test  # Frontend
   pytest    # Backend
   ```
5. **Commit your changes**:
   ```bash
   git commit -m 'feat: add amazing feature'
   ```
6. **Push to your fork**:
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**

### Code Style

- **Frontend**: ESLint, Prettier
- **Backend**: PEP 8, Black, isort
- **Commit Messages**: Conventional Commits format
  - `feat:` New features
  - `fix:` Bug fixes
  - `docs:` Documentation changes
  - `refactor:` Code refactoring
  - `test:` Test additions/changes

---

## 📝 Documentation

### Complete Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - System architecture overview
- **[QUICKSTART.md](./QUICKSTART.md)** - Detailed quick start guide
- **[SUPERADMIN_SETUP.md](./SUPERADMIN_SETUP.md)** - Superadmin setup instructions
- **[RECENT_CHANGES.md](./RECENT_CHANGES.md)** - Recent updates and changes
- **[scripts/README.md](./scripts/README.md)** - Scripts documentation

### Additional Resources

- **Architecture Docs**: See `docs/architecture/` for detailed architecture documentation
- **API Schemas**: OpenAPI/Swagger documentation at service `/docs` endpoints
- **Diagrams**: System diagrams in `docs/diagrams/`

---

## 🗺️ Roadmap

### ✅ Completed (Phase 1-3)
- ✅ Microservices architecture
- ✅ Frontend with Next.js 16
- ✅ Real-time messaging with WebSocket
- ✅ Authentication with Keycloak
- ✅ Channels and direct messages
- ✅ File upload and storage
- ✅ Admin dashboard
- ✅ Analytics dashboard
- ✅ Notifications system
- ✅ Monitoring with Grafana/Prometheus

### 🚧 In Progress (Phase 4)
- ⏳ Full-text search with OpenSearch
- ⏳ Advanced moderation tools
- ⏳ Enhanced analytics
- ⏳ Mobile-responsive improvements

### 📋 Planned (Phase 5)
- 📋 Mobile applications (React Native)
- 📋 Voice/video calls (WebRTC)
- 📋 Screen sharing
- 📋 Advanced search filters
- 📋 Email notifications
- 📋 Slack import/export
- 📋 Custom emoji
- 📋 Bot framework

---

## 🐛 Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check Docker is running
docker version

# Check for port conflicts
lsof -i :3000  # Frontend port
lsof -i :8080  # Keycloak port

# Restart services
docker-compose restart
```

**Superadmin can't login:**
```bash
# Re-run superadmin setup
docker exec colink-auth-proxy python /app/scripts/setup_superadmin.py

# Check logs
docker logs colink-auth-proxy
docker logs colink-keycloak
```

**Frontend not loading:**
```bash
# Rebuild frontend
docker-compose build frontend
docker-compose up -d frontend

# Check logs
docker logs colink-frontend

# Hard refresh browser (Cmd+Shift+R or Ctrl+Shift+R)
```

**Database connection errors:**
```bash
# Check PostgreSQL is running
docker exec colink-postgres pg_isready

# Check database logs
docker logs colink-postgres

# Restart database
docker-compose restart postgres
```

---

## 📧 Support

- **GitHub Issues**: [Create an issue](https://github.com/darshlukkad/colink-slack-clone/issues)
- **Documentation**: See `docs/` directory
- **Email**: Contact repository owner

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## 👥 Team

- **Lead Developer**: Darsh Lukkad ([@darshlukkad](https://github.com/darshlukkad))
- **Contributors**: See [CONTRIBUTORS.md](./CONTRIBUTORS.md)

---

## 🙏 Acknowledgments

- [Next.js](https://nextjs.org/) - React framework
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [Keycloak](https://www.keycloak.org/) - Identity and access management
- [PostgreSQL](https://www.postgresql.org/) - Reliable database
- [Redpanda](https://redpanda.com/) - Kafka-compatible streaming
- [OpenSearch](https://opensearch.org/) - Search and analytics
- [TailwindCSS](https://tailwindcss.com/) - Utility-first CSS framework

---

**Built with ❤️ using Next.js, FastAPI, PostgreSQL, and Kafka**

*Last Updated: December 2025*
