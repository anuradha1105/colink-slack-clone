import { create } from 'zustand';
import type { User, AuthTokens } from '@/types';
import { AuthService } from '@/lib/auth';

interface AuthState {
  user: User | null;
  tokens: AuthTokens | null;
  isAuthenticated: boolean;
  isLoading: boolean;

  // Actions
  setAuth: (user: User | null, tokens: AuthTokens | null) => void;
  setUser: (user: User) => void;
  clearAuth: () => void;
  initializeAuth: () => Promise<void>;
  refreshTokens: () => Promise<void>;
  logout: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  tokens: null,
  isAuthenticated: false,
  isLoading: true,

  // Allow null so we can do setAuth(null, null)
  setAuth: (user, tokens) => {
    if (user && tokens) {
      AuthService.saveUser(user);
      AuthService.saveTokens(tokens);

      set({
        user,
        tokens,
        isAuthenticated: true,
        isLoading: false,
      });
    } else {
      AuthService.clearAuth();

      set({
        user: null,
        tokens: null,
        isAuthenticated: false,
        isLoading: false,
      });
    }
  },

  setUser: (user) => {
    AuthService.saveUser(user);
    set({ user });
  },

  clearAuth: () => {
    AuthService.clearAuth();
    set({
      user: null,
      tokens: null,
      isAuthenticated: false,
      isLoading: false,
    });
  },

  initializeAuth: async () => {
    try {
      const tokens = AuthService.getTokens();
      const user = AuthService.getUser();

      if (!tokens || !user) {
        set({ isLoading: false });
        return;
      }

      // Check if token is expired
      if (AuthService.isTokenExpired(tokens.access_token)) {
        try {
          await get().refreshTokens();
        } catch (error) {
          console.error('Failed to refresh tokens on init:', error);
          get().clearAuth();
        }
      } else {
        set({
          user,
          tokens,
          isAuthenticated: true,
          isLoading: false,
        });
      }
    } catch (error) {
      console.error('Failed to initialize auth:', error);
      get().clearAuth();
    }
  },

  // 🛠 Uses AuthService.refreshToken(refresh_token: string)
  refreshTokens: async () => {
    try {
      const { tokens } = get();

      if (!tokens?.refresh_token) {
        throw new Error('No refresh token available');
      }

      // Call the singular refreshToken method on AuthService
      const newTokens = await AuthService.refreshToken(tokens.refresh_token);

      const user = await AuthService.getCurrentUser(newTokens.access_token);

      if (!user) {
        // If backend can't resolve a user, treat as logged out
        await AuthService.logout(tokens.refresh_token);
        get().setAuth(null, null);
        return;
      }

      get().setAuth(user, newTokens);
    } catch (error) {
      console.error('Failed to refresh tokens:', error);
      get().setAuth(null, null);
    }
  },

  logout: async () => {
    const { tokens } = get();

    if (tokens?.refresh_token) {
      try {
        await AuthService.logout(tokens.refresh_token);
      } catch (error) {
        console.error('Logout error:', error);
      }
    }

    get().clearAuth();
  },
}));
