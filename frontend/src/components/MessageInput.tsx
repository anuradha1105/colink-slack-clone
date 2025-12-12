'use client';

import { useState, useRef, useCallback } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { messageApi, filesApi } from '@/lib/api';
import { Send, Paperclip, Smile, X, Sparkles, Check, XCircle, Loader2 } from 'lucide-react';
import { useWebSocket } from '@/contexts/WebSocketContext';

// AI Service URL for rephrase feature
const AI_SERVICE_URL = process.env.NEXT_PUBLIC_AI_SERVICE_URL || 'http://localhost:8011';

interface MessageInputProps {
  channelId: string;
}

interface UploadedFile {
  id: string;
  filename: string;
  url: string;
  content_type: string;
  size: number;
}

interface RephraseResponse {
  original: string;
  rephrased: string;
  was_changed: boolean;
}

export function MessageInput({ channelId }: MessageInputProps) {
  const [content, setContent] = useState('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [attachedFiles, setAttachedFiles] = useState<UploadedFile[]>([]);
  const [isUploading, setIsUploading] = useState(false);
  const [isRephrasing, setIsRephrasing] = useState(false);
  const [rephrasedText, setRephrasedText] = useState<string | null>(null);
  const [showRephrasePreview, setShowRephrasePreview] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();
  const { sendTyping } = useWebSocket();
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Common emojis for quick access
  const quickEmojis = ['😊', '👍', '❤️', '😂', '🎉', '👀', '🔥', '✅', '🚀', '💯'];

  const sendMessageMutation = useMutation({
    mutationFn: async (messageContent: string) => {
      const payload: any = {
        content: messageContent,
        channel_id: channelId,
        message_type: 'text',
      };

      // Include file IDs if there are attachments
      if (attachedFiles.length > 0) {
        payload.attachment_ids = attachedFiles.map(f => f.id);
      }

      const response = await messageApi.post<any>(`/messages`, payload);
      console.log('Message sent:', response);
      return response;
    },
    onSuccess: async (newMessage) => {
      setContent('');
      setAttachedFiles([]); // Clear attached files
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    // Allow sending if there's content OR attachments
    if (content.trim() || attachedFiles.length > 0) {
      const messageContent = content.trim() || '📎';

      // Check for @AI pattern
      const aiMatch = messageContent.match(/@AI\s+(.+)/i);

      // Send the user's message first
      sendMessageMutation.mutate(messageContent);

      // If @AI was mentioned, get AI response
      if (aiMatch && aiMatch[1]) {
        const question = aiMatch[1].trim();

        try {
          // Call AI service
          const response = await fetch(`${AI_SERVICE_URL}/ask`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ question }),
          });

          if (response.ok) {
            const data = await response.json();

            // Post AI response as a follow-up message
            await messageApi.post('/messages', {
              content: `🤖 **AI Assistant:** ${data.answer}`,
              channel_id: channelId,
              message_type: 'text',
            });

            // Refetch messages to show AI response
            await queryClient.refetchQueries({ queryKey: ['messages', channelId] });
          }
        } catch (error) {
          console.error('Failed to get AI response:', error);
          // Post error message
          await messageApi.post('/messages', {
            content: '🤖 **AI Assistant:** Sorry, I couldn\'t process your request. Please try again.',
            channel_id: channelId,
            message_type: 'text',
          });
          await queryClient.refetchQueries({ queryKey: ['messages', channelId] });
        }
      }
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const handleEmojiClick = (emoji: string) => {
    setContent(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  // Smart Rephrase handler - calls AI service to improve message phrasing
  const handleRephrase = async () => {
    if (!content.trim() || content.trim().length < 5) return;

    setIsRephrasing(true);
    setShowRephrasePreview(false);

    try {
      const response = await fetch(`${AI_SERVICE_URL}/rephrase`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: content.trim() }),
      });

      if (!response.ok) {
        throw new Error('Failed to rephrase message');
      }

      const data: RephraseResponse = await response.json();

      if (data.was_changed && data.rephrased !== content.trim()) {
        setRephrasedText(data.rephrased);
        setShowRephrasePreview(true);
      } else {
        // Message was already well-phrased
        setRephrasedText(null);
        setShowRephrasePreview(false);
      }
    } catch (error) {
      console.error('Failed to rephrase message:', error);
    } finally {
      setIsRephrasing(false);
    }
  };

  // Accept the rephrased text
  const handleAcceptRephrase = () => {
    if (rephrasedText) {
      setContent(rephrasedText);
      setRephrasedText(null);
      setShowRephrasePreview(false);
    }
  };

  // Dismiss the rephrase suggestion
  const handleDismissRephrase = () => {
    setRephrasedText(null);
    setShowRephrasePreview(false);
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);
    try {
      const uploadPromises = Array.from(files).map(async (file) => {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('channel_id', channelId);

        // Content-Type will be automatically set by browser for FormData
        const response = await filesApi.post<UploadedFile>('/api/v1/files/upload', formData);

        return response;
      });

      const uploadedFiles = await Promise.all(uploadPromises);
      setAttachedFiles(prev => [...prev, ...uploadedFiles]);
    } catch (error) {
      console.error('Failed to upload files:', error);
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleRemoveFile = (fileId: string) => {
    setAttachedFiles(prev => prev.filter(f => f.id !== fileId));
  };

  const handleAttachClick = () => {
    fileInputRef.current?.click();
  };

  return (
    <div className="border-t border-gray-200 bg-white px-4 py-4">
      <form onSubmit={handleSubmit}>
        <div className="flex items-end space-x-2">
          <div className="flex-1 border border-gray-300 rounded-lg overflow-hidden focus-within:border-blue-500 focus-within:ring-1 focus-within:ring-blue-500">
            {/* Attached files preview */}
            {attachedFiles.length > 0 && (
              <div className="px-4 pt-3 pb-2 border-b border-gray-200">
                <div className="flex flex-wrap gap-2">
                  {attachedFiles.map((file) => (
                    <div
                      key={file.id}
                      className="flex items-center space-x-2 bg-gray-100 px-3 py-2 rounded-lg"
                    >
                      <Paperclip className="h-4 w-4 text-gray-600" />
                      <span className="text-sm text-gray-700 max-w-[200px] truncate">
                        {file.filename}
                      </span>
                      <button
                        type="button"
                        onClick={() => handleRemoveFile(file.id)}
                        className="text-gray-500 hover:text-gray-700"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <textarea
              value={content}
              onChange={handleContentChange}
              onKeyDown={handleKeyDown}
              placeholder="Type a message..."
              className="w-full px-4 py-3 resize-none outline-none max-h-32 text-gray-900"
              rows={1}
              disabled={sendMessageMutation.isPending || isUploading}
            />

            {/* Smart Rephrase Preview */}
            {showRephrasePreview && rephrasedText && (
              <div className="mx-4 mb-2 p-3 bg-purple-50 border border-purple-200 rounded-lg">
                <div className="flex items-start gap-2">
                  <Sparkles className="h-4 w-4 text-purple-600 mt-0.5 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs text-purple-600 font-medium mb-1">Suggested rephrase:</p>
                    <p className="text-sm text-gray-800">{rephrasedText}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2 mt-2 ml-6">
                  <button
                    type="button"
                    onClick={handleAcceptRephrase}
                    className="flex items-center gap-1 px-2 py-1 text-xs font-medium text-white bg-purple-600 hover:bg-purple-700 rounded transition-colors"
                  >
                    <Check className="h-3 w-3" />
                    Accept
                  </button>
                  <button
                    type="button"
                    onClick={handleDismissRephrase}
                    className="flex items-center gap-1 px-2 py-1 text-xs font-medium text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded transition-colors"
                  >
                    <XCircle className="h-3 w-3" />
                    Dismiss
                  </button>
                </div>
              </div>
            )}

            <div className="flex items-center justify-between px-4 pb-3 pt-1">
              <div className="flex items-center space-x-2 relative">
                <input
                  ref={fileInputRef}
                  type="file"
                  multiple
                  onChange={handleFileSelect}
                  className="hidden"
                  accept="image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.txt"
                />
                <button
                  type="button"
                  onClick={handleAttachClick}
                  disabled={isUploading}
                  className="p-1 hover:bg-gray-100 rounded disabled:opacity-50 disabled:cursor-not-allowed"
                  title="Attach file"
                >
                  {isUploading ? (
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-gray-600"></div>
                  ) : (
                    <Paperclip className="h-5 w-5 text-gray-600" />
                  )}
                </button>
                <button
                  type="button"
                  className="p-1 hover:bg-gray-100 rounded"
                  title="Add emoji"
                  onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                >
                  <Smile className="h-5 w-5 text-gray-600" />
                </button>

                {/* Smart Rephrase Button */}
                <button
                  type="button"
                  onClick={handleRephrase}
                  disabled={isRephrasing || !content.trim() || content.trim().length < 5}
                  className="p-1 hover:bg-purple-100 rounded disabled:opacity-50 disabled:cursor-not-allowed group"
                  title="Smart Rephrase - Fix grammar and improve phrasing"
                >
                  {isRephrasing ? (
                    <Loader2 className="h-5 w-5 text-purple-600 animate-spin" />
                  ) : (
                    <Sparkles className="h-5 w-5 text-purple-600 group-hover:text-purple-700" />
                  )}
                </button>

                {/* Emoji Picker */}
                {showEmojiPicker && (
                  <div className="absolute bottom-full left-0 mb-2 p-2 bg-white border border-gray-300 rounded-lg shadow-lg z-10">
                    <div className="flex items-center gap-1">
                      {quickEmojis.map((emoji) => (
                        <button
                          key={emoji}
                          type="button"
                          onClick={() => handleEmojiClick(emoji)}
                          className="text-2xl hover:bg-gray-100 p-1 rounded transition-colors"
                        >
                          {emoji}
                        </button>
                      ))}
                      <button
                        type="button"
                        onClick={() => setShowEmojiPicker(false)}
                        className="ml-2 text-gray-400 hover:text-gray-600 text-sm px-2"
                      >
                        ✕
                      </button>
                    </div>
                  </div>
                )}
              </div>
              <button
                type="submit"
                disabled={(!content.trim() && attachedFiles.length === 0) || sendMessageMutation.isPending || isUploading}
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
