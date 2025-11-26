'use client';

import { useQuery } from '@tanstack/react-query';
import { channelApi } from '@/lib/api';
import { Channel } from '@/types';
import { Hash, Lock, Users, Star, Info } from 'lucide-react';
import { useAuthStore } from '@/store/authStore';

interface ChannelHeaderProps {
  channel: Channel;
}

interface ChannelMember {
  user_id: string;
  username: string;
  display_name?: string;
  is_admin: boolean;
  notifications_enabled: boolean;
  created_at: string;
}

export function ChannelHeader({ channel }: ChannelHeaderProps) {
  const { user } = useAuthStore();
  const isPrivate = channel.channel_type === 'PRIVATE';
  const isDirect = channel.channel_type === 'DIRECT';

  // Fetch channel members for DM channels to get the other user's name
  const { data: membersData } = useQuery({
    queryKey: ['channel-members', channel.id],
    queryFn: async () => {
      return await channelApi.get<{ members: ChannelMember[]; total: number }>(
        `/channels/${channel.id}/members`
      );
    },
    enabled: isDirect, // Only fetch for DM channels
  });

  // For direct messages, get the other person's name from members
  const getDisplayName = () => {
    if (!isDirect) return channel.name;

    // Get the other user from members
    if (membersData?.members) {
      const otherMember = membersData.members.find(
        (member) => member.user_id !== user?.id
      );
      if (otherMember) {
        return otherMember.display_name || otherMember.username;
      }
    }

    // Fallback to channel name
    return channel.name;
  };

  const displayName = getDisplayName();

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
          <h2 className="text-lg font-semibold text-gray-900">{displayName}</h2>
          {!isDirect && channel.topic && (
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
