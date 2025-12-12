export const config = {
  api: {
    url: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8001',
  },
  channelService: {
    url: process.env.NEXT_PUBLIC_CHANNEL_SERVICE_URL || 'http://localhost:8003',
  },
  messageService: {
    url: process.env.NEXT_PUBLIC_MESSAGE_SERVICE_URL || 'http://localhost:8002',
  },
  filesService: {
    url: process.env.NEXT_PUBLIC_FILES_SERVICE_URL || 'http://localhost:8007',
  },
  threadsService: {
    url: process.env.NEXT_PUBLIC_THREADS_SERVICE_URL || 'http://localhost:8005',
  },
  websocket: {
    url: process.env.NEXT_PUBLIC_WS_URL || 'http://localhost:8009',
  },
};
