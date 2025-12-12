import type { User, AuthTokens } from '@/types';
import { config } from '@/lib/config';

const TOKEN_KEY = 'auth_tokens';
const USER_KEY = 'user';

const KEYCLOAK_URL = 'http://localhost:8080';
const KEYCLOAK_REALM = 'colink';
const KEYCLOAK_CLIENT_ID = 'web-app';

export class AuthService {
  static getAuthUrl(): string {
    const redirectUri = typeof window !== 'undefined' 
      ? `${window.location.origin}/auth/callback`
      : 'http://localhost:3000/auth/callback';
    
    const params = new URLSearchParams({
      client_id: KEYCLOAK_CLIENT_ID,
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: 'openid profile email',
    });

    return `${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth?${params.toString()}`;
  }

  static getLogoutUrl(): string {
    const redirectUri = typeof window !== 'undefined' 
      ? window.location.origin
      : 'http://localhost:3000';
    
    const params = new URLSearchParams({
      redirect_uri: redirectUri,
    });

    return `${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout?${params.toString()}`;
  }

  static async exchangeCodeForTokens(code: string): Promise<AuthTokens | null> {
    const redirectUri = typeof window !== 'undefined' 
      ? `${window.location.origin}/auth/callback`
      : 'http://localhost:3000/auth/callback';

    try {
      const response = await fetch(`${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: KEYCLOAK_CLIENT_ID,
          code,
          redirect_uri: redirectUri,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to exchange code for tokens');
      }

      const data = await response.json();
      return {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expires_in: data.expires_in,
        token_type: data.token_type,
      };
    } catch (error) {
      console.error('Error exchanging code for tokens:', error);
      return null;
    }
  }

  // Alias for compatibility
  static async exchangeCodeForToken(code: string): Promise<AuthTokens> {
    const tokens = await this.exchangeCodeForTokens(code);
    if (!tokens) {
      throw new Error('Failed to exchange code for token');
    }
    return tokens;
  }

  static async getCurrentUser(accessToken: string): Promise<User> {
    try {
      // Decode JWT to get user info
      const payload = JSON.parse(atob(accessToken.split('.')[1]));
      
      // Extract role from Keycloak token
      // Check realm_access.roles first, then resource_access
      let role: 'ADMIN' | 'MODERATOR' | 'MEMBER' = 'MEMBER';
      
      const realmRoles = payload.realm_access?.roles || [];
      if (realmRoles.includes('Admin') || realmRoles.includes('admin') || realmRoles.includes('ADMIN')) {
        role = 'ADMIN';
      } else if (realmRoles.includes('Moderator') || realmRoles.includes('moderator') || realmRoles.includes('MODERATOR')) {
        role = 'MODERATOR';
      }
      
      return {
        id: payload.sub,
        keycloak_id: payload.sub, // Add keycloak_id from token
        username: payload.preferred_username || payload.sub,
        email: payload.email || '',
        display_name: payload.name || payload.preferred_username || '',
        avatar_url: undefined, // Use undefined instead of null to match User type
        status: 'ACTIVE' as const,
        role: role,
      };
    } catch (error) {
      console.error('Error decoding token:', error);
      throw new Error('Failed to get user info from token');
    }
  }

  static saveTokens(tokens: AuthTokens): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem(TOKEN_KEY, JSON.stringify(tokens));
    }
  }

  static getTokens(): AuthTokens | null {
    if (typeof window !== 'undefined') {
      const tokens = localStorage.getItem(TOKEN_KEY);
      return tokens ? JSON.parse(tokens) : null;
    }
    return null;
  }

  static saveUser(user: User): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem(USER_KEY, JSON.stringify(user));
    }
  }

  static getUser(): User | null {
    if (typeof window !== 'undefined') {
      const user = localStorage.getItem(USER_KEY);
      return user ? JSON.parse(user) : null;
    }
    return null;
  }

  static clearAuth(): void {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(USER_KEY);
    }
  }

  static getAccessToken(): string | null {
    const tokens = this.getTokens();
    return tokens?.access_token || null;
  }

  static getRefreshToken(): string | null {
    const tokens = this.getTokens();
    return tokens?.refresh_token || null;
  }

  static isTokenExpired(token: string): boolean {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const exp = payload.exp;
      if (!exp) return true;
      // Add 30 second buffer before actual expiration
      return Date.now() >= (exp * 1000) - 30000;
    } catch {
      return true;
    }
  }

  static async refreshToken(refreshToken: string): Promise<AuthTokens> {
    try {
      const response = await fetch(`${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'refresh_token',
          client_id: KEYCLOAK_CLIENT_ID,
          refresh_token: refreshToken,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to refresh token');
      }

      const data = await response.json();
      return {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expires_in: data.expires_in,
        token_type: data.token_type,
      };
    } catch (error) {
      console.error('Error refreshing token:', error);
      throw error;
    }
  }

  static async logout(refreshToken: string): Promise<void> {
    try {
      await fetch(`${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          client_id: KEYCLOAK_CLIENT_ID,
          refresh_token: refreshToken,
        }),
      });
    } catch (error) {
      console.error('Error logging out:', error);
    }
    this.clearAuth();
  }
}
