'use client';

import { useState } from 'react';
import { Message } from '@/types';
import { formatDistanceToNow } from 'date-fns';
import { Smile, MessageSquare, MoreVertical } from 'lucide-react';

interface MessageItemProps {
  message: Message;
  showAvatar: boolean;
}

export function MessageItem({ message, showAvatar }: MessageItemProps) {
  const [showActions, setShowActions] = useState(false);

  const formattedTime = formatDistanceToNow(new Date(message.created_at), {
    addSuffix: true,
  });

  const displayTime = new Date(message.created_at).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });

  return (
    <div
      className="group hover:bg-gray-100 px-4 py-1 rounded"
      onMouseEnter={() => setShowActions(true)}
      onMouseLeave={() => setShowActions(false)}
    >
      <div className="flex space-x-3">
        {showAvatar ? (
          <div className="w-10 h-10 rounded bg-blue-500 flex items-center justify-center flex-shrink-0">
            <span className="text-white font-medium">
              {message.author?.display_name?.[0]?.toUpperCase() ||
                message.author?.username?.[0]?.toUpperCase() ||
                'U'}
            </span>
          </div>
        ) : (
          <div className="w-10 flex-shrink-0 flex items-center justify-center">
            <span className="text-xs text-gray-500 opacity-0 group-hover:opacity-100">
              {displayTime}
            </span>
          </div>
        )}

        <div className="flex-1 min-w-0">
          {showAvatar && (
            <div className="flex items-baseline space-x-2 mb-1">
              <span className="font-semibold text-gray-900">
                {message.author?.display_name || message.author?.username || 'Unknown User'}
              </span>
              <span className="text-xs text-gray-500">{formattedTime}</span>
              {message.is_edited && (
                <span className="text-xs text-gray-500">(edited)</span>
              )}
            </div>
          )}

          <div className="text-gray-900 break-words">{message.content}</div>

          {/* Reactions */}
          {message.reactions && message.reactions.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-2">
              {message.reactions.map((reaction) => (
                <button
                  key={reaction.emoji}
                  className="flex items-center space-x-1 px-2 py-1 bg-white border border-gray-300 rounded-full hover:border-blue-500 text-sm"
                >
                  <span>{reaction.emoji}</span>
                  <span className="text-gray-600">{reaction.count}</span>
                </button>
              ))}
              <button className="flex items-center px-2 py-1 bg-white border border-gray-300 rounded-full hover:border-blue-500">
                <Smile className="h-4 w-4 text-gray-500" />
              </button>
            </div>
          )}

          {/* Thread indicator */}
          {message.reply_count && message.reply_count > 0 && (
            <button className="flex items-center space-x-2 mt-2 text-blue-600 hover:bg-blue-50 px-3 py-1 rounded">
              <MessageSquare className="h-4 w-4" />
              <span className="text-sm font-medium">
                {message.reply_count} {message.reply_count === 1 ? 'reply' : 'replies'}
              </span>
            </button>
          )}
        </div>

        {/* Hover actions */}
        {showActions && (
          <div className="flex items-center space-x-1 bg-white border border-gray-300 rounded shadow-sm px-2">
            <button className="p-1 hover:bg-gray-100 rounded" title="Add reaction">
              <Smile className="h-4 w-4 text-gray-600" />
            </button>
            <button className="p-1 hover:bg-gray-100 rounded" title="Reply in thread">
              <MessageSquare className="h-4 w-4 text-gray-600" />
            </button>
            <button className="p-1 hover:bg-gray-100 rounded" title="More actions">
              <MoreVertical className="h-4 w-4 text-gray-600" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
