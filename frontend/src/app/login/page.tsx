'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { AuthService } from '@/lib/auth';
import { useAuthStore } from '@/store/authStore';
import { MessageSquare } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuthStore();

  useEffect(() => {
    if (isAuthenticated) {
      router.push('/channels');
    }
  }, [isAuthenticated, router]);

  const handleLogin = () => {
    window.location.href = AuthService.getAuthUrl();
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8">
        <div className="text-center">
          <div className="flex justify-center mb-6">
            <div className="bg-blue-600 p-4 rounded-2xl">
              <MessageSquare className="h-12 w-12 text-white" />
            </div>
          </div>
          <h1 className="text-4xl font-bold text-gray-900 mb-2">Colink</h1>
          <p className="text-gray-600">Team communication made simple</p>
        </div>

        <div className="mt-8 space-y-4">
          <button
            onClick={handleLogin}
            className="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            Sign in with Keycloak
          </button>

          <div className="text-center text-sm text-gray-500 mt-4">
            <p>Secure authentication powered by Keycloak</p>
          </div>
        </div>

        <div className="mt-8 pt-8 border-t border-gray-200">
          <div className="text-center space-y-2">
            <p className="text-sm text-gray-600 font-medium">Demo Accounts</p>
            <div className="space-y-1 text-xs text-gray-500">
              <p>alice / password</p>
              <p>bob / password</p>
              <p>charlie / password</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
