'use client';

import { Channel } from '@/types';
import { Hash, Lock, Users, Star, Info } from 'lucide-react';

interface ChannelHeaderProps {
  channel: Channel;
}

export function ChannelHeader({ channel }: ChannelHeaderProps) {
  const isPrivate = channel.channel_type === 'PRIVATE';
  const isDirect = channel.channel_type === 'DIRECT';

  return (
    <div className="h-14 border-b border-gray-200 px-4 flex items-center justify-between bg-white">
      <div className="flex items-center space-x-2">
        {isDirect ? (
          <div className="w-6 h-6 rounded-full bg-green-500 flex-shrink-0"></div>
        ) : isPrivate ? (
          <Lock className="h-5 w-5 text-gray-600" />
        ) : (
          <Hash className="h-5 w-5 text-gray-600" />
        )}
        <div>
          <h2 className="text-lg font-semibold text-gray-900">{channel.name}</h2>
          {channel.topic && (
            <p className="text-xs text-gray-500 truncate max-w-md">{channel.topic}</p>
          )}
        </div>
      </div>

      <div className="flex items-center space-x-2">
        <button className="p-2 hover:bg-gray-100 rounded">
          <Star className="h-5 w-5 text-gray-600" />
        </button>
        <button className="p-2 hover:bg-gray-100 rounded flex items-center space-x-1">
          <Users className="h-5 w-5 text-gray-600" />
          {channel.member_count && (
            <span className="text-sm text-gray-600">{channel.member_count}</span>
          )}
        </button>
        <button className="p-2 hover:bg-gray-100 rounded">
          <Info className="h-5 w-5 text-gray-600" />
        </button>
      </div>
    </div>
  );
}
