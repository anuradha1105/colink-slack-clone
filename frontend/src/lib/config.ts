export const config = {
  keycloak: {
    url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
    realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'colink',
    clientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'web-app',
  },
  api: {
    authProxy: process.env.NEXT_PUBLIC_AUTH_PROXY_URL || 'http://localhost:8001',
    channel: process.env.NEXT_PUBLIC_CHANNEL_SERVICE_URL || 'http://localhost:8003',
    message: process.env.NEXT_PUBLIC_MESSAGE_SERVICE_URL || 'http://localhost:8002',
    threads: process.env.NEXT_PUBLIC_THREADS_SERVICE_URL || 'http://localhost:8005',
    reactions: process.env.NEXT_PUBLIC_REACTIONS_SERVICE_URL || 'http://localhost:8006',
    files: process.env.NEXT_PUBLIC_FILES_SERVICE_URL || 'http://localhost:8007',
    notifications: process.env.NEXT_PUBLIC_NOTIFICATIONS_SERVICE_URL || 'http://localhost:8008',
  },
  websocket: {
    url: process.env.NEXT_PUBLIC_WEBSOCKET_URL || 'http://localhost:8009',
  },
};
