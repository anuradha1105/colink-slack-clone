'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAuthStore } from '@/store/authStore';
import { channelApi } from '@/lib/api';
import { Channel } from '@/types';
import { Hash, Lock, ChevronDown, Plus, MessageSquare, Settings, LogOut } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuthStore();
  const [channelsExpanded, setChannelsExpanded] = useState(true);
  const [directMessagesExpanded, setDirectMessagesExpanded] = useState(true);

  const { data: channels = [], isLoading } = useQuery({
    queryKey: ['channels'],
    queryFn: async () => {
      const response = await channelApi.get<Channel[]>('/channels');
      return response.data;
    },
  });

  const publicChannels = channels.filter(c => c.channel_type === 'PUBLIC');
  const privateChannels = channels.filter(c => c.channel_type === 'PRIVATE');
  const directMessages = channels.filter(c => c.channel_type === 'DIRECT');

  const handleLogout = async () => {
    await logout();
  };

  return (
    <div className="w-64 bg-purple-900 text-white flex flex-col h-screen">
      {/* Workspace Header */}
      <div className="p-4 border-b border-purple-800">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <MessageSquare className="h-6 w-6" />
            <h1 className="text-lg font-bold">Colink</h1>
          </div>
          <ChevronDown className="h-4 w-4" />
        </div>
      </div>

      {/* User Info */}
      <div className="px-4 py-3 border-b border-purple-800">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 rounded bg-purple-600 flex items-center justify-center">
            <span className="text-sm font-medium">
              {user?.display_name?.[0]?.toUpperCase() || user?.username?.[0]?.toUpperCase() || 'U'}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium truncate">{user?.display_name || user?.username}</p>
            <p className="text-xs text-purple-300 truncate">{user?.status_text || 'Active'}</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <div className="flex-1 overflow-y-auto">
        {/* Public Channels */}
        <div className="px-2 py-2">
          <button
            onClick={() => setChannelsExpanded(!channelsExpanded)}
            className="w-full flex items-center justify-between px-2 py-1 hover:bg-purple-800 rounded text-sm"
          >
            <span className="font-semibold">Channels</span>
            <div className="flex items-center space-x-1">
              <button className="hover:bg-purple-700 rounded p-0.5">
                <Plus className="h-4 w-4" />
              </button>
              <ChevronDown
                className={`h-4 w-4 transition-transform ${channelsExpanded ? '' : '-rotate-90'}`}
              />
            </div>
          </button>

          {channelsExpanded && (
            <div className="mt-1 space-y-0.5">
              {isLoading ? (
                <div className="px-2 py-1 text-sm text-purple-300">Loading...</div>
              ) : publicChannels.length === 0 ? (
                <div className="px-2 py-1 text-sm text-purple-300">No channels yet</div>
              ) : (
                publicChannels.map((channel) => (
                  <Link
                    key={channel.id}
                    href={`/channels/${channel.id}`}
                    className={`flex items-center space-x-2 px-2 py-1 rounded text-sm hover:bg-purple-800 ${
                      pathname === `/channels/${channel.id}` ? 'bg-purple-700' : ''
                    }`}
                  >
                    <Hash className="h-4 w-4" />
                    <span className="flex-1 truncate">{channel.name}</span>
                    {channel.unread_count && channel.unread_count > 0 ? (
                      <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[20px] text-center">
                        {channel.unread_count}
                      </span>
                    ) : null}
                  </Link>
                ))
              )}
            </div>
          )}
        </div>

        {/* Private Channels */}
        {privateChannels.length > 0 && (
          <div className="px-2 py-2">
            <div className="text-xs font-semibold text-purple-300 px-2 py-1">PRIVATE CHANNELS</div>
            <div className="mt-1 space-y-0.5">
              {privateChannels.map((channel) => (
                <Link
                  key={channel.id}
                  href={`/channels/${channel.id}`}
                  className={`flex items-center space-x-2 px-2 py-1 rounded text-sm hover:bg-purple-800 ${
                    pathname === `/channels/${channel.id}` ? 'bg-purple-700' : ''
                  }`}
                >
                  <Lock className="h-4 w-4" />
                  <span className="flex-1 truncate">{channel.name}</span>
                  {channel.unread_count && channel.unread_count > 0 ? (
                    <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[20px] text-center">
                      {channel.unread_count}
                    </span>
                  ) : null}
                </Link>
              ))}
            </div>
          </div>
        )}

        {/* Direct Messages */}
        <div className="px-2 py-2">
          <button
            onClick={() => setDirectMessagesExpanded(!directMessagesExpanded)}
            className="w-full flex items-center justify-between px-2 py-1 hover:bg-purple-800 rounded text-sm"
          >
            <span className="font-semibold">Direct Messages</span>
            <div className="flex items-center space-x-1">
              <button className="hover:bg-purple-700 rounded p-0.5">
                <Plus className="h-4 w-4" />
              </button>
              <ChevronDown
                className={`h-4 w-4 transition-transform ${directMessagesExpanded ? '' : '-rotate-90'}`}
              />
            </div>
          </button>

          {directMessagesExpanded && (
            <div className="mt-1 space-y-0.5">
              {directMessages.length === 0 ? (
                <div className="px-2 py-1 text-sm text-purple-300">No direct messages</div>
              ) : (
                directMessages.map((channel) => (
                  <Link
                    key={channel.id}
                    href={`/channels/${channel.id}`}
                    className={`flex items-center space-x-2 px-2 py-1 rounded text-sm hover:bg-purple-800 ${
                      pathname === `/channels/${channel.id}` ? 'bg-purple-700' : ''
                    }`}
                  >
                    <div className="w-4 h-4 rounded-full bg-green-500 flex-shrink-0"></div>
                    <span className="flex-1 truncate">{channel.name}</span>
                    {channel.unread_count && channel.unread_count > 0 ? (
                      <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[20px] text-center">
                        {channel.unread_count}
                      </span>
                    ) : null}
                  </Link>
                ))
              )}
            </div>
          )}
        </div>
      </div>

      {/* Footer Actions */}
      <div className="border-t border-purple-800 p-2">
        <button
          onClick={handleLogout}
          className="w-full flex items-center space-x-2 px-2 py-2 hover:bg-purple-800 rounded text-sm"
        >
          <LogOut className="h-4 w-4" />
          <span>Sign out</span>
        </button>
      </div>
    </div>
  );
}
