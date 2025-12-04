# Colink Architecture Diagrams

This document contains comprehensive architecture diagrams for the Colink Slack Clone project.

---

## 1. System Architecture Overview

High-level view showing all major components and their interactions.

```mermaid
graph TB
    subgraph "Client Layer"
        Browser[Web Browser<br/>Next.js 16 Frontend]
    end

    subgraph "Application Layer"
        Frontend[Frontend Service<br/>:3000<br/>Next.js, React, TypeScript]

        subgraph "Backend Services"
            AuthProxy[Auth Proxy<br/>:8001<br/>Authentication & Users]
            Message[Message Service<br/>:8002<br/>Messages & Analytics]
            Channel[Channel Service<br/>:8003<br/>Channels & Membership]
            Threads[Threads Service<br/>:8005<br/>Thread Conversations]
            Reactions[Reactions Service<br/>:8006<br/>Emoji Reactions]
            Files[Files Service<br/>:8007<br/>File Management]
            Notifications[Notifications Service<br/>:8008<br/>User Notifications]
            WebSocket[WebSocket Service<br/>:8009<br/>Real-time Events]
            Admin[Admin Service<br/>:8010<br/>User Management]
        end
    end

    subgraph "Data Layer"
        PostgreSQL[(PostgreSQL<br/>:5432<br/>Primary Database)]
        Redis[(Redis<br/>:6379<br/>Cache & Sessions)]
        Kafka[(Redpanda/Kafka<br/>:9092<br/>Event Streaming)]
        MinIO[(MinIO<br/>:9000<br/>Object Storage)]
        OpenSearch[(OpenSearch<br/>:9200<br/>Full-text Search)]
    end

    subgraph "Infrastructure"
        Keycloak[Keycloak<br/>:8080<br/>Identity Provider]
        Prometheus[Prometheus<br/>:9090<br/>Metrics]
        Grafana[Grafana<br/>:3001<br/>Dashboards]
    end

    Browser --> Frontend
    Frontend --> AuthProxy
    Frontend --> Message
    Frontend --> Channel
    Frontend --> Threads
    Frontend --> Reactions
    Frontend --> Files
    Frontend --> Notifications
    Frontend --> WebSocket
    Frontend --> Admin

    AuthProxy --> Keycloak
    AuthProxy --> PostgreSQL
    Message --> PostgreSQL
    Message --> Kafka
    Channel --> PostgreSQL
    Channel --> Kafka
    Threads --> PostgreSQL
    Reactions --> PostgreSQL
    Files --> MinIO
    Files --> PostgreSQL
    Notifications --> PostgreSQL
    WebSocket --> Redis
    WebSocket --> Kafka
    Admin --> PostgreSQL

    Message --> Redis
    Channel --> Redis
    AuthProxy --> Redis

    Message --> Prometheus
    Channel --> Prometheus
    WebSocket --> Prometheus

    Grafana --> Prometheus

    OpenSearch -.->|Future| Message

    style Frontend fill:#61DAFB,stroke:#20232A,color:#000
    style AuthProxy fill:#009688,stroke:#00695C,color:#fff
    style Message fill:#009688,stroke:#00695C,color:#fff
    style Channel fill:#009688,stroke:#00695C,color:#fff
    style Threads fill:#009688,stroke:#00695C,color:#fff
    style Reactions fill:#009688,stroke:#00695C,color:#fff
    style Files fill:#009688,stroke:#00695C,color:#fff
    style Notifications fill:#009688,stroke:#00695C,color:#fff
    style WebSocket fill:#009688,stroke:#00695C,color:#fff
    style Admin fill:#009688,stroke:#00695C,color:#fff
    style PostgreSQL fill:#336791,stroke:#22496B,color:#fff
    style Redis fill:#DC382D,stroke:#A02B22,color:#fff
    style Kafka fill:#FF6B6B,stroke:#CC5555,color:#fff
    style MinIO fill:#C72C48,stroke:#9B2239,color:#fff
    style Keycloak fill:#008AAE,stroke:#006685,color:#fff
```

---

## 2. Data Flow: Send Message

Shows the complete flow when a user sends a message in a channel.

```mermaid
sequenceDiagram
    participant User as User Browser
    participant Frontend as Frontend<br/>(Next.js)
    participant Message as Message Service<br/>:8002
    participant DB as PostgreSQL
    participant Kafka as Redpanda
    participant WS as WebSocket Service<br/>:8009
    participant Redis as Redis<br/>(Pub/Sub)
    participant OtherUsers as Other Users

    User->>Frontend: Type & send message
    Frontend->>Message: POST /messages<br/>{text, channelId}<br/>Authorization: Bearer <JWT>

    Message->>Message: Validate JWT
    Message->>Message: Check channel membership

    Message->>DB: INSERT INTO messages
    DB-->>Message: message_id

    Message->>Kafka: Publish message.created event
    Note over Kafka: Topic: message.events<br/>For async consumers

    Message->>Redis: PUBLISH channel:{id}<br/>message payload
    Note over Redis: Real-time distribution

    Message-->>Frontend: 201 Created<br/>{id, text, createdAt...}
    Frontend-->>User: Show message immediately

    WS->>Redis: SUBSCRIBE channel:{id}
    Redis-->>WS: New message event

    WS->>OtherUsers: WebSocket push<br/>message.created
    OtherUsers->>OtherUsers: Update UI in real-time

    Note over Kafka: Async consumers process event:<br/>- Search indexing (future)<br/>- Analytics<br/>- Notifications
```

---

## 3. Authentication Flow

Shows how users authenticate and access protected resources.

```mermaid
sequenceDiagram
    participant User as User Browser
    participant Frontend as Frontend<br/>Next.js
    participant AuthProxy as Auth Proxy<br/>:8001
    participant Keycloak as Keycloak<br/>:8080
    participant DB as PostgreSQL
    participant Backend as Backend Services

    User->>Frontend: Click "Login"
    Frontend->>AuthProxy: GET /auth/login
    AuthProxy->>Keycloak: Redirect to login page
    Keycloak-->>User: Show login form

    User->>Keycloak: Enter credentials
    Keycloak->>Keycloak: Validate credentials
    Keycloak->>Keycloak: Require 2FA (if enabled)
    User->>Keycloak: Enter 2FA code

    Keycloak-->>AuthProxy: Authorization code
    AuthProxy->>Keycloak: Exchange code for tokens<br/>POST /token
    Keycloak-->>AuthProxy: access_token<br/>refresh_token<br/>id_token

    AuthProxy->>Keycloak: GET /userinfo
    Keycloak-->>AuthProxy: User profile

    AuthProxy->>DB: SELECT/INSERT user<br/>Sync with local DB
    DB-->>AuthProxy: User record

    AuthProxy-->>Frontend: Redirect /auth/callback<br/>?tokens=...
    Frontend->>Frontend: Store tokens (localStorage)

    alt Admin User
        Frontend->>Frontend: Redirect to /admin
    else Regular User
        Frontend->>Frontend: Redirect to /channels
    end

    Note over User,Frontend: User is now authenticated

    User->>Frontend: Access protected page
    Frontend->>Backend: API request<br/>Authorization: Bearer <access_token>
    Backend->>Backend: Validate JWT signature
    Backend->>Backend: Check token expiration
    Backend->>Backend: Extract user claims
    Backend-->>Frontend: Protected resource
    Frontend-->>User: Display data
```

---

## 4. Real-time Message Flow

Shows how WebSocket enables real-time communication.

```mermaid
graph TB
    subgraph "Connected Clients"
        User1[User 1 Browser]
        User2[User 2 Browser]
        User3[User 3 Browser]
    end

    subgraph "Frontend Layer"
        WS1[WebSocket Client 1]
        WS2[WebSocket Client 2]
        WS3[WebSocket Client 3]
    end

    subgraph "WebSocket Service :8009"
        WSServer[WebSocket Server<br/>Socket.IO / FastAPI]
        ConnectionMgr[Connection Manager<br/>Track active connections]
    end

    subgraph "Message Broker"
        Redis[Redis Pub/Sub<br/>Real-time events]
        Redpanda[Redpanda<br/>Persistent events]
    end

    subgraph "Backend Services"
        MessageSvc[Message Service]
        ChannelSvc[Channel Service]
        ThreadsSvc[Threads Service]
        ReactionsSvc[Reactions Service]
    end

    User1 --> WS1
    User2 --> WS2
    User3 --> WS3

    WS1 <-->|WSS| WSServer
    WS2 <-->|WSS| WSServer
    WS3 <-->|WSS| WSServer

    WSServer <--> ConnectionMgr
    WSServer <--> Redis

    MessageSvc -->|PUBLISH| Redis
    ChannelSvc -->|PUBLISH| Redis
    ThreadsSvc -->|PUBLISH| Redis
    ReactionsSvc -->|PUBLISH| Redis

    MessageSvc -->|Produce| Redpanda
    ChannelSvc -->|Produce| Redpanda
    ThreadsSvc -->|Produce| Redpanda
    ReactionsSvc -->|Produce| Redpanda

    style WSServer fill:#FFA500,stroke:#CC8400,color:#fff
    style Redis fill:#DC382D,stroke:#A02B22,color:#fff
    style Redpanda fill:#FF6B6B,stroke:#CC5555,color:#fff
```

---

## 5. Data Storage Architecture

Shows how different data types are stored across different storage systems.

```mermaid
graph TB
    subgraph "PostgreSQL - Persistent Data"
        UsersTable[(users<br/>user profiles, roles)]
        ChannelsTable[(channels<br/>channel metadata)]
        MessagesTable[(messages<br/>all messages)]
        ThreadsTable[(threads<br/>thread conversations)]
        ReactionsTable[(reactions<br/>emoji reactions)]
        FilesTable[(files<br/>file metadata)]
        NotificationsTable[(notifications<br/>user notifications)]
        AuditTable[(audit_logs<br/>admin actions)]
    end

    subgraph "Redis - Temporary Data"
        UserCache[User Cache<br/>TTL: 5 min]
        ChannelCache[Channel Cache<br/>TTL: 5 min]
        PresenceCache[Presence Status<br/>TTL: 60 sec]
        TypingCache[Typing Indicators<br/>TTL: 5 sec]
        SessionCache[User Sessions<br/>TTL: 1 hour]
        RateLimitCache[Rate Limit Counters<br/>TTL: 1 min]
    end

    subgraph "MinIO - Object Storage"
        FilesBucket[colink-files<br/>User uploads]
        AvatarsBucket[colink-avatars<br/>Profile pictures]
        ThumbnailsBucket[colink-thumbnails<br/>Image previews]
    end

    subgraph "Redpanda - Event Streaming"
        MessageEvents[message.events<br/>Retention: 30 days]
        ChannelEvents[channel.events<br/>Retention: 30 days]
        UserEvents[user.events<br/>Retention: 7 days]
        AuditEvents[audit.events<br/>Retention: 90 days]
    end

    subgraph "OpenSearch - Search Index"
        MessageIndex[messages index<br/>Full-text search]
        FileIndex[files index<br/>File content search]
        UserIndex[users index<br/>User directory]
    end

    style UsersTable fill:#336791,stroke:#22496B,color:#fff
    style ChannelsTable fill:#336791,stroke:#22496B,color:#fff
    style MessagesTable fill:#336791,stroke:#22496B,color:#fff
    style UserCache fill:#DC382D,stroke:#A02B22,color:#fff
    style ChannelCache fill:#DC382D,stroke:#A02B22,color:#fff
    style FilesBucket fill:#C72C48,stroke:#9B2239,color:#fff
    style MessageEvents fill:#FF6B6B,stroke:#CC5555,color:#fff
    style MessageIndex fill:#005EB8,stroke:#004080,color:#fff
```

---

## 6. Deployment Architecture

Shows how services are deployed in Docker containers.

```mermaid
graph TB
    subgraph "Docker Host"
        subgraph "Application Containers"
            FrontendC[frontend<br/>Node.js + Next.js<br/>Port: 3000]
            AuthC[auth-proxy<br/>Python + FastAPI<br/>Port: 8001]
            MessageC[message<br/>Python + FastAPI<br/>Port: 8002]
            ChannelC[channel<br/>Python + FastAPI<br/>Port: 8003]
            ThreadsC[threads<br/>Python + FastAPI<br/>Port: 8005]
            ReactionsC[reactions<br/>Python + FastAPI<br/>Port: 8006]
            FilesC[files<br/>Python + FastAPI<br/>Port: 8007]
            NotificationsC[notifications<br/>Python + FastAPI<br/>Port: 8008]
            WebSocketC[websocket<br/>Python + FastAPI<br/>Port: 8009]
            AdminC[admin<br/>Python + FastAPI<br/>Port: 8010]
        end

        subgraph "Data Containers"
            PostgreSQLC[postgres<br/>PostgreSQL 16<br/>Port: 5432]
            RedisC[redis<br/>Redis 7<br/>Port: 6379]
            RedpandaC[redpanda<br/>Kafka-compatible<br/>Port: 9092]
            MinIOC[minio<br/>Object Storage<br/>Port: 9000, 9001]
            OpenSearchC[opensearch<br/>Search Engine<br/>Port: 9200, 9600]
        end

        subgraph "Infrastructure Containers"
            KeycloakC[keycloak<br/>Identity Provider<br/>Port: 8080]
            PrometheusC[prometheus<br/>Metrics<br/>Port: 9090]
            GrafanaC[grafana<br/>Dashboards<br/>Port: 3001]
        end

        subgraph "Volumes"
            PostgresVol[postgres_data]
            RedisVol[redis_data]
            MinIOVol[minio_data]
            KeycloakVol[keycloak_data]
            OpenSearchVol[opensearch_data]
        end

        subgraph "Networks"
            AppNet[colink-network<br/>Bridge Network]
        end
    end

    FrontendC -.-> AppNet
    AuthC -.-> AppNet
    MessageC -.-> AppNet
    ChannelC -.-> AppNet
    ThreadsC -.-> AppNet
    ReactionsC -.-> AppNet
    FilesC -.-> AppNet
    NotificationsC -.-> AppNet
    WebSocketC -.-> AppNet
    AdminC -.-> AppNet
    PostgreSQLC -.-> AppNet
    RedisC -.-> AppNet
    RedpandaC -.-> AppNet
    MinIOC -.-> AppNet
    OpenSearchC -.-> AppNet
    KeycloakC -.-> AppNet
    PrometheusC -.-> AppNet
    GrafanaC -.-> AppNet

    PostgreSQLC --> PostgresVol
    RedisC --> RedisVol
    MinIOC --> MinIOVol
    KeycloakC --> KeycloakVol
    OpenSearchC --> OpenSearchVol

    style FrontendC fill:#61DAFB,stroke:#20232A,color:#000
    style AuthC fill:#009688,stroke:#00695C,color:#fff
    style PostgreSQLC fill:#336791,stroke:#22496B,color:#fff
    style RedisC fill:#DC382D,stroke:#A02B22,color:#fff
```

---

## 7. Admin Dashboard Flow

Shows how superadmin accesses and uses the admin dashboard.

```mermaid
sequenceDiagram
    participant Admin as Superadmin
    participant Frontend as Frontend
    participant AuthProxy as Auth Proxy
    participant AdminSvc as Admin Service
    participant DB as PostgreSQL
    participant Keycloak as Keycloak

    Admin->>Frontend: Login with admin credentials
    Frontend->>AuthProxy: POST /auth/login
    AuthProxy->>Keycloak: Authenticate
    Keycloak-->>AuthProxy: JWT with role=admin
    AuthProxy-->>Frontend: User object + tokens

    Frontend->>Frontend: Check user.role === 'admin'
    Frontend->>Frontend: Redirect to /admin

    Admin->>Frontend: Access /admin dashboard
    Frontend->>AuthProxy: GET /auth/users
    AuthProxy->>DB: SELECT * FROM users
    DB-->>AuthProxy: User list
    AuthProxy-->>Frontend: User data
    Frontend-->>Admin: Display user table

    Admin->>Frontend: Click "Create User"
    Frontend->>Frontend: Show create user form
    Admin->>Frontend: Submit form
    Frontend->>AuthProxy: POST /auth/admin/users
    AuthProxy->>Keycloak: Create user in Keycloak
    Keycloak-->>AuthProxy: User created
    AuthProxy->>DB: INSERT INTO users
    DB-->>AuthProxy: User record
    AuthProxy-->>Frontend: Success
    Frontend-->>Admin: User created successfully

    Admin->>Frontend: Access /analytics
    Frontend->>AdminSvc: GET /analytics/summary
    AdminSvc->>DB: Complex analytics queries
    DB-->>AdminSvc: Aggregated data
    AdminSvc-->>Frontend: Analytics data
    Frontend-->>Admin: Display charts and metrics
```

---

## 8. Channel Creation & Messaging Flow

Complete flow from creating a channel to sending messages.

```mermaid
sequenceDiagram
    participant User as User
    participant Frontend as Frontend
    participant Channel as Channel Service
    participant Message as Message Service
    participant WebSocket as WebSocket Service
    participant DB as PostgreSQL
    participant Redis as Redis
    participant Kafka as Redpanda

    User->>Frontend: Create new channel
    Frontend->>Channel: POST /channels<br/>{name, type, description}
    Channel->>DB: INSERT INTO channels
    Channel->>DB: INSERT INTO channel_members<br/>(creator as member)
    DB-->>Channel: Channel created
    Channel->>Kafka: Publish channel.created event
    Channel-->>Frontend: Channel object
    Frontend-->>User: Navigate to new channel

    User->>Frontend: Type message
    Frontend->>Message: POST /messages<br/>{channelId, text}
    Message->>DB: Verify channel membership
    Message->>DB: INSERT INTO messages
    Message->>Redis: PUBLISH channel:{id}
    Message->>Kafka: Publish message.created
    Message-->>Frontend: Message object

    WebSocket->>Redis: SUBSCRIBE channel:{id}
    Redis-->>WebSocket: message event
    WebSocket->>WebSocket: Find connected users<br/>in this channel
    WebSocket-->>User: Push to WebSocket<br/>Real-time update

    Frontend-->>User: Message appears instantly

    Note over User,Kafka: Other users in channel<br/>see message in real-time
```

---

## Component Details

### Frontend (Next.js 16)
- **Technology**: Next.js 16, React 18, TypeScript
- **Key Features**: SSR, Real-time WebSocket, File uploads, Dark mode
- **State Management**: Zustand for auth and theme
- **Data Fetching**: TanStack Query (React Query)

### Backend Services (Python + FastAPI)
- **Runtime**: Python 3.11
- **Framework**: FastAPI 0.115+
- **ASGI Server**: Uvicorn with workers
- **Database ORM**: SQLAlchemy 2.0
- **Authentication**: JWT validation on all requests

### Data Stores
- **PostgreSQL 16**: ACID-compliant relational database for persistent data
- **Redis 7**: In-memory cache for temporary data and pub/sub
- **Redpanda**: Kafka-compatible event streaming for async processing
- **MinIO**: S3-compatible object storage for files
- **OpenSearch 2.x**: Full-text search engine (infrastructure ready)

### Infrastructure
- **Keycloak 23.x**: OAuth 2.0 / OIDC identity provider
- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards

---

## Key Design Patterns

### 1. Event-Driven Architecture
- Services publish events to Redpanda after state changes
- Other services consume events asynchronously
- Enables loose coupling and scalability

### 2. CQRS (Light)
- Write operations go to PostgreSQL directly
- Read operations use Redis cache when possible
- Analytics queries use optimized read models

### 3. API Gateway Pattern
- Frontend acts as API gateway aggregator
- Backend services have focused, single-responsibility APIs
- No service-to-service synchronous calls (except auth validation)

### 4. Cache-Aside Pattern
- Services check Redis before hitting PostgreSQL
- Cache misses trigger DB query and cache population
- TTL-based cache invalidation

---

## Scalability Considerations

### Horizontal Scaling
- All backend services are stateless and can scale horizontally
- WebSocket service maintains connection state in Redis
- Frontend can be scaled with CDN for static assets

### Database Scaling
- PostgreSQL read replicas for read-heavy workloads
- Connection pooling with PgBouncer
- Future: Table partitioning for messages (by date)

### Cache Optimization
- Redis cluster for high availability
- Separate cache namespaces per service
- Intelligent TTL based on data access patterns

---

**Last Updated**: 2025-12-04
