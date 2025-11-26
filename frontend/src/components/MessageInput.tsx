'use client';

import { useState, useRef, useCallback } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { messageApi } from '@/lib/api';
import { Send, Paperclip, Smile } from 'lucide-react';
import { useWebSocket } from '@/contexts/WebSocketContext';

interface MessageInputProps {
  channelId: string;
}

export function MessageInput({ channelId }: MessageInputProps) {
  const [content, setContent] = useState('');
  const queryClient = useQueryClient();
  const { sendTyping } = useWebSocket();
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const sendMessageMutation = useMutation({
    mutationFn: async (messageContent: string) => {
      const response = await messageApi.post<any>(`/messages`, {
        content: messageContent,
        channel_id: channelId,
        message_type: 'text',
      });
      console.log('Message sent:', response);
      return response;
    },
    onSuccess: async (newMessage) => {
      setContent('');
      sendTyping(channelId, false); // Stop typing indicator
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
        typingTimeoutRef.current = null;
      }

      // Refetch messages immediately
      await queryClient.refetchQueries({ queryKey: ['messages', channelId] });
    },
    onError: (error) => {
      console.error('Failed to send message:', error);
    },
  });

  const handleTyping = useCallback(() => {
    // Send typing indicator
    sendTyping(channelId, true);

    // Clear existing timeout
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    // Stop typing after 2 seconds of inactivity
    typingTimeoutRef.current = setTimeout(() => {
      sendTyping(channelId, false);
      typingTimeoutRef.current = null;
    }, 2000);
  }, [channelId, sendTyping]);

  const handleContentChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setContent(e.target.value);
    if (e.target.value.trim()) {
      handleTyping();
    } else {
      // Stop typing if content is empty
      sendTyping(channelId, false);
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
        typingTimeoutRef.current = null;
      }
    }
  };

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
              onChange={handleContentChange}
              onKeyDown={handleKeyDown}
              placeholder="Type a message..."
              className="w-full px-4 py-3 resize-none outline-none max-h-32 text-gray-900"
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
