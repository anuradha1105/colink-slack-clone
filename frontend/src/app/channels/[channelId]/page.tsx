'use client';

import { use } from 'react';
import { useQuery } from '@tanstack/react-query';
import { channelApi, messageApi } from '@/lib/api';
import { Channel, Message } from '@/types';
import { ChannelHeader } from '@/components/ChannelHeader';
import { MessageList } from '@/components/MessageList';
import { MessageInput } from '@/components/MessageInput';

interface ChannelPageProps {
  params: Promise<{
    channelId: string;
  }>;
}

export default function ChannelPage({ params }: ChannelPageProps) {
  const { channelId } = use(params);

  const { data: channel, isLoading: channelLoading } = useQuery({
    queryKey: ['channel', channelId],
    queryFn: async () => {
      const response = await channelApi.get<Channel>(`/channels/${channelId}`);
      return response.data;
    },
  });

  const { data: messages = [], isLoading: messagesLoading } = useQuery({
    queryKey: ['messages', channelId],
    queryFn: async () => {
      const response = await messageApi.get<Message[]>(`/channels/${channelId}/messages`);
      return response.data;
    },
  });

  if (channelLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900"></div>
      </div>
    );
  }

  if (!channel) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-gray-900 mb-2">Channel not found</h2>
          <p className="text-gray-600">This channel may have been deleted or you don't have access</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <ChannelHeader channel={channel} />
      <MessageList messages={messages} isLoading={messagesLoading} />
      <MessageInput channelId={channelId} />
    </div>
  );
}
