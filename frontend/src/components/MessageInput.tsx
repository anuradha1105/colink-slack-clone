'use client';

import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { messageApi } from '@/lib/api';
import { Send, Paperclip, Smile } from 'lucide-react';

interface MessageInputProps {
  channelId: string;
}

export function MessageInput({ channelId }: MessageInputProps) {
  const [content, setContent] = useState('');
  const queryClient = useQueryClient();

  const sendMessageMutation = useMutation({
    mutationFn: async (messageContent: string) => {
      const response = await messageApi.post(`/channels/${channelId}/messages`, {
        content: messageContent,
        message_type: 'text',
      });
      return response.data;
    },
    onSuccess: () => {
      setContent('');
      queryClient.invalidateQueries({ queryKey: ['messages', channelId] });
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (content.trim()) {
      sendMessageMutation.mutate(content);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <div className="border-t border-gray-200 bg-white px-4 py-4">
      <form onSubmit={handleSubmit}>
        <div className="flex items-end space-x-2">
          <div className="flex-1 border border-gray-300 rounded-lg overflow-hidden focus-within:border-blue-500 focus-within:ring-1 focus-within:ring-blue-500">
            <textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Type a message..."
              className="w-full px-4 py-3 resize-none outline-none max-h-32"
              rows={1}
              disabled={sendMessageMutation.isPending}
            />
            <div className="flex items-center justify-between px-4 pb-3 pt-1">
              <div className="flex items-center space-x-2">
                <button
                  type="button"
                  className="p-1 hover:bg-gray-100 rounded"
                  title="Attach file"
                >
                  <Paperclip className="h-5 w-5 text-gray-600" />
                </button>
                <button
                  type="button"
                  className="p-1 hover:bg-gray-100 rounded"
                  title="Add emoji"
                >
                  <Smile className="h-5 w-5 text-gray-600" />
                </button>
              </div>
              <button
                type="submit"
                disabled={!content.trim() || sendMessageMutation.isPending}
                className="flex items-center space-x-1 px-3 py-1.5 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                <Send className="h-4 w-4" />
                <span className="text-sm font-medium">Send</span>
              </button>
            </div>
          </div>
        </div>
      </form>
    </div>
  );
}
