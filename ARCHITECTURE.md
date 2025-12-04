# Colink Architecture Documentation

## 📋 Documentation Index

This is the **master index** for all Colink architecture documentation. All detailed specifications are in the [`/docs`](./docs/) folder.

---

## 🎯 Quick Start

1. **New to the project?** Start with:
   - [Executive Summary](./docs/architecture/00-executive-summary.md)
   - [System Architecture](./docs/architecture/01-system-architecture.md)

2. **Need to implement a feature?** Check:
   - [Service Inventory](./docs/architecture/05-service-inventory.md) - Find the right service
   - [Data Flows](./docs/architecture/02-data-flows.md) - See how features work end-to-end

3. **Security review?** See:
   - [Security Model](./docs/architecture/03-security-model.md)

4. **Scaling concerns?** Review:
   - [Scalability & Reliability](./docs/architecture/04-scalability-reliability.md)

---

## 📁 Documentation Structure

### Architecture Documentation

| Document | Description | Status |
|----------|-------------|--------|
| [00-executive-summary.md](./docs/architecture/00-executive-summary.md) | Technology stack, design decisions, trade-offs | ✅ Complete |
| [01-system-architecture.md](./docs/architecture/01-system-architecture.md) | C4 diagrams (Context & Container), deployment topology | ✅ Complete |
| [02-data-flows.md](./docs/architecture/02-data-flows.md) | Sequence diagrams for core user journeys | ✅ Complete |
| [03-security-model.md](./docs/architecture/03-security-model.md) | Authentication, authorization, RBAC, secrets management | ✅ Complete |
| [04-scalability-reliability.md](./docs/architecture/04-scalability-reliability.md) | Scaling patterns, caching, retries, circuit breakers | ✅ Complete |
| [05-service-inventory.md](./docs/architecture/05-service-inventory.md) | Detailed catalog of all services | ✅ Complete |

### Diagrams

| Diagram | Type | Status |
|---------|------|--------|
| [c4-context.md](./docs/diagrams/c4-context.md) | C4 Level 1 (System Context) | ✅ Complete |

---

## 🏗️ Architecture Summary

### Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Frontend** | Next.js | 16 |
| **Backend Runtime** | Python | 3.11 |
| **Framework** | FastAPI | 0.115+ |
| **ASGI Server** | Uvicorn | Latest |
| **Database** | PostgreSQL | 16 |
| **Cache** | Redis | 7 |
| **Message Queue** | Redpanda (Kafka-compatible) | Latest |
| **Object Storage** | MinIO / S3 | Latest |
| **Search Engine** | OpenSearch | 2.x |
| **Identity Provider** | Keycloak | 23.x |
| **Monitoring** | Prometheus + Grafana | Latest |

### Design Principles

1. **API-First**: RESTful APIs with clear contracts
2. **Microservices**: Independently deployable services with clear boundaries
3. **Stateless Services**: All state in PostgreSQL/Redis, not in-memory
4. **Event-Driven**: Async updates via Redpanda/Kafka for non-critical paths
5. **Security by Default**: JWT validation on every request, RBAC enforcement
6. **Observable**: Structured logs, distributed tracing, Prometheus metrics

---

## 🎯 System Components

### Frontend Application

| Component | Port | Technology | Responsibilities |
|-----------|------|-----------|-----------------|
| **Web App** | 3000 | Next.js 16, React, TypeScript | User interface, real-time updates, WebSocket client |

**Key Features**:
- Server-side rendering (SSR) and static generation
- Real-time messaging with WebSocket
- File upload with drag-and-drop
- Responsive design (mobile, tablet, desktop)
- Dark mode theme support
- Admin dashboard and analytics

---

### Backend Microservices (9 Services)

| Service | Port | Responsibilities |
|---------|------|-----------------|
| **auth-proxy** | 8001 | Keycloak integration, token management, user auth endpoints |
| **message-service** | 8002 | Send/edit/delete messages, DMs, analytics endpoints |
| **channel-service** | 8003 | Channel CRUD, membership management, permissions |
| **threads-service** | 8005 | Threaded conversations, replies |
| **reactions-service** | 8006 | Emoji reactions on messages |
| **files-service** | 8007 | File upload/download, presigned URLs, MinIO integration |
| **notifications-service** | 8008 | Push notifications, email notifications, user preferences |
| **websocket-service** | 8009 | WebSocket connections, real-time event fan-out, presence |
| **admin-service** | 8010 | User management, moderation, audit logging, analytics |

---

### Infrastructure Components

| Component | Port(s) | Purpose |
|-----------|---------|---------|
| **PostgreSQL** | 5432 | Primary database for all services |
| **Redis** | 6379 | Cache, session store, pub/sub backplane |
| **Redpanda** | 9092, 9644 | Event streaming (Kafka-compatible) |
| **Keycloak** | 8080 | Identity provider, OAuth 2.0 / OIDC |
| **MinIO** | 9000, 9001 | S3-compatible object storage |
| **OpenSearch** | 9200, 9600 | Full-text search engine |
| **Prometheus** | 9090 | Metrics collection and storage |
| **Grafana** | 3001 | Metrics visualization and dashboards |

---

## 🔐 Security Model

### Authentication Flow

```
User → Frontend → Auth Proxy → Keycloak
                       ↓
                  JWT tokens
                       ↓
                  Frontend storage
                       ↓
              Backend API requests
```

### Authorization (RBAC)

**Roles**:
- **Admin/Superadmin**: Full system access, user management, analytics
- **Moderator**: Channel moderation, content management
- **Member**: Standard user access to channels and DMs
- **Guest**: Limited read-only access

**Implementation**:
- JWT tokens include user roles
- Backend services validate roles on protected endpoints
- Frontend conditionally renders features based on user role

### Security Features

- **OAuth 2.0 / OIDC**: Standard authentication via Keycloak
- **JWT Tokens**: Short-lived access tokens (1 hour), refresh tokens (30 days)
- **Token Refresh**: Automatic token refresh on expiration
- **Secure Storage**: HttpOnly cookies or localStorage for tokens
- **CORS**: Configured for frontend domain
- **Rate Limiting**: Per-user and per-IP rate limits

---

## 📊 Data Architecture

### PostgreSQL Databases

Each service has its own database schema:

**auth-proxy**:
- `users` - User profiles, roles, keycloak mapping
- `user_settings` - User preferences

**channel-service**:
- `channels` - Channel metadata
- `channel_members` - User-channel relationships

**message-service**:
- `messages` - All messages (channel and DMs)
- `message_files` - Message-file relationships

**threads-service**:
- `threads` - Thread metadata
- `replies` - Thread replies

**reactions-service**:
- `reactions` - Emoji reactions on messages

**files-service**:
- `files` - File metadata, storage keys

**notifications-service**:
- `notifications` - User notifications
- `notification_preferences` - User notification settings

**admin-service**:
- `audit_logs` - System audit trail

### Redis Usage

**Cache Patterns**:
- User profile cache (5-min TTL)
- Channel metadata cache (5-min TTL)
- Online user presence (60-sec TTL)
- Typing indicators (5-sec TTL)

**Pub/Sub**:
- WebSocket message fan-out
- Real-time event broadcasting

### Redpanda/Kafka Topics

| Topic | Purpose | Retention |
|-------|---------|-----------|
| `user.events` | User created/updated/deleted | 7 days |
| `channel.events` | Channel operations | 30 days |
| `message.events` | Message CRUD operations | 30 days |
| `thread.events` | Thread operations | 30 days |
| `reaction.events` | Reaction operations | 7 days |
| `file.events` | File upload/delete | 30 days |
| `audit.events` | Admin actions | 90 days |

### MinIO/S3 Buckets

| Bucket | Purpose | Access |
|--------|---------|--------|
| `colink-files` | User-uploaded files | Presigned URLs (1-hour download) |
| `colink-avatars` | User avatar images | Presigned URLs |
| `colink-thumbnails` | Image thumbnails | Presigned URLs |

---

## 🔄 Data Flow Examples

### 1. User Sends Message

```
User types message → Frontend
                       ↓
            POST /messages (JWT auth)
                       ↓
              Message Service
                       ↓
         ┌──────────┬──────────┬──────────┐
         ↓          ↓          ↓          ↓
    PostgreSQL  Redpanda   Redis    WebSocket
    (persist)   (event)   (cache)  (broadcast)
```

### 2. User Uploads File

```
User selects file → Frontend requests upload URL
                          ↓
                   Files Service
                          ↓
                    MinIO presigned URL
                          ↓
         Frontend uploads directly to MinIO
                          ↓
              Frontend notifies Files Service
                          ↓
                   Metadata saved
                          ↓
                File ID returned to frontend
```

### 3. Real-time Updates

```
Backend event → Redpanda topic
                      ↓
            WebSocket Service (consumer)
                      ↓
              Redis pub/sub
                      ↓
           All WebSocket connections
                      ↓
            Connected clients receive update
```

---

## 🚀 Deployment

### Local Development (Docker Compose)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f [service-name]

# Rebuild specific service
docker-compose build [service-name]

# Restart specific service
docker-compose restart [service-name]

# Stop all services
docker-compose down

# Remove all data
docker-compose down -v
```

**Service Access**:
- Frontend: http://localhost:3000
- Backend APIs: http://localhost:800X (see service ports above)
- Keycloak Admin: http://localhost:8080/admin
- MinIO Console: http://localhost:9001
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090

### Production Considerations

**Scaling**:
- Horizontal scaling for all backend services
- Read replicas for PostgreSQL
- Redis cluster for high availability
- Redpanda cluster with multiple brokers
- CDN for static assets and avatars

**Monitoring**:
- Prometheus for metrics collection
- Grafana for visualization
- Structured logging to centralized store
- Distributed tracing (future)

**Security**:
- TLS/HTTPS for all external traffic
- Network policies between services
- Secrets management (environment variables or secrets manager)
- Regular security updates

---

## 📈 Scaling Targets

| Metric | Current MVP | Future Scale |
|--------|-------------|--------------|
| Concurrent users | 100-1,000 | 10,000+ |
| Messages/second | 50 | 1,000+ |
| WebSocket connections | 1,000 | 50,000+ |
| Database size | 10GB | 1TB+ |
| File storage | 100GB | 10TB+ |

---

## 🧪 Testing Strategy

1. **Unit Tests**: Service-level tests with pytest
2. **Integration Tests**: API endpoint tests with real database
3. **E2E Tests**: Full user flow tests (future)
4. **Load Tests**: Performance testing with k6 or locust (future)

---

## 📚 Key Features

### Core Messaging
- ✅ Channel-based messaging (public/private)
- ✅ Direct messages (1-on-1)
- ✅ Threaded conversations
- ✅ Emoji reactions
- ✅ File attachments
- ✅ Real-time updates via WebSocket
- ✅ Message editing and deletion
- ✅ Typing indicators
- ✅ Online presence

### Admin & Moderation
- ✅ User management (create, update, deactivate)
- ✅ Role-based access control
- ✅ Superadmin mode (hidden from regular users)
- ✅ Admin dashboard with user list
- ✅ Avatar management
- ✅ Audit logging

### Analytics & Monitoring
- ✅ System analytics dashboard
- ✅ Message statistics
- ✅ User activity metrics
- ✅ Channel engagement tracking
- ✅ Prometheus metrics
- ✅ Grafana dashboards

### User Experience
- ✅ Dark mode / Light mode toggle
- ✅ Responsive design
- ✅ Real-time notifications
- ✅ User avatars
- ✅ Channel browsing
- ✅ Member lists

### Infrastructure
- ✅ Microservices architecture
- ✅ Docker containerization
- ✅ PostgreSQL database
- ✅ Redis caching
- ✅ Redpanda event streaming
- ✅ MinIO object storage
- ✅ Keycloak authentication
- ✅ OpenSearch infrastructure (search implementation in progress)

---

## 🔮 Future Enhancements

### Planned Features
- 📝 Full-text search (OpenSearch integration)
- 📝 Voice/video calls
- 📝 Screen sharing
- 📝 Message pinning
- 📝 Channel announcements
- 📝 Custom emoji
- 📝 Webhooks and integrations
- 📝 Mobile apps (iOS/Android)

### Technical Improvements
- 📝 Distributed tracing
- 📝 Advanced caching strategies
- 📝 Database sharding
- 📝 CDN integration
- 📝 CI/CD pipeline
- 📝 Automated backups
- 📝 Disaster recovery plan

---

## 📖 Additional Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Next.js Documentation**: https://nextjs.org/docs
- **Keycloak Documentation**: https://www.keycloak.org/documentation
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Redis Documentation**: https://redis.io/documentation
- **Redpanda Documentation**: https://docs.redpanda.com/
- **MinIO Documentation**: https://min.io/docs/
- **OpenSearch Documentation**: https://opensearch.org/docs/

---

## 🤝 Contributing

See the main [README.md](./README.md) for contribution guidelines.

---

## 📄 License

[MIT License](./LICENSE)

---

**Last Updated**: 2025-12-04
**Architecture Version**: 2.0.0
