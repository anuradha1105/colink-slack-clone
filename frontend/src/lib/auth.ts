import { config } from './config';
import type { AuthTokens, User } from '@/types';

export class AuthService {
  private static readonly TOKEN_KEY = 'colink_tokens';
  private static readonly USER_KEY = 'colink_user';

  static getAuthUrl(): string {
    const params = new URLSearchParams({
      client_id: config.keycloak.clientId,
      redirect_uri: typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : '',
      response_type: 'code',
      scope: 'openid profile email',
    });

    return `${config.keycloak.url}/realms/${config.keycloak.realm}/protocol/openid-connect/auth?${params}`;
  }

  static async exchangeCodeForToken(code: string): Promise<AuthTokens> {
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: config.keycloak.clientId,
      code,
      redirect_uri: typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : '',
    });

    const response = await fetch(
      `${config.keycloak.url}/realms/${config.keycloak.realm}/protocol/openid-connect/token`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params,
      }
    );

    if (!response.ok) {
      throw new Error('Failed to exchange code for token');
    }

    return response.json();
  }

  static async refreshToken(refreshToken: string): Promise<AuthTokens> {
    const params = new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: config.keycloak.clientId,
      refresh_token: refreshToken,
    });

    const response = await fetch(
      `${config.keycloak.url}/realms/${config.keycloak.realm}/protocol/openid-connect/token`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params,
      }
    );

    if (!response.ok) {
      throw new Error('Failed to refresh token');
    }

    return response.json();
  }

  static async logout(refreshToken: string): Promise<void> {
    const params = new URLSearchParams({
      client_id: config.keycloak.clientId,
      refresh_token: refreshToken,
    });

    await fetch(
      `${config.keycloak.url}/realms/${config.keycloak.realm}/protocol/openid-connect/logout`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params,
      }
    );
  }

  static async getCurrentUser(accessToken: string): Promise<User> {
    const response = await fetch(`${config.api.authProxy}/auth/me`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error('Failed to get current user');
    }

    return response.json();
  }

  static saveTokens(tokens: AuthTokens): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem(this.TOKEN_KEY, JSON.stringify(tokens));
    }
  }

  static getTokens(): AuthTokens | null {
    if (typeof window === 'undefined') return null;

    const stored = localStorage.getItem(this.TOKEN_KEY);
    return stored ? JSON.parse(stored) : null;
  }

  static saveUser(user: User): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem(this.USER_KEY, JSON.stringify(user));
    }
  }

  static getUser(): User | null {
    if (typeof window === 'undefined') return null;

    const stored = localStorage.getItem(this.USER_KEY);
    return stored ? JSON.parse(stored) : null;
  }

  static clearAuth(): void {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(this.TOKEN_KEY);
      localStorage.removeItem(this.USER_KEY);
    }
  }

  static isTokenExpired(token: string): boolean {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp * 1000 < Date.now();
    } catch {
      return true;
    }
  }
}
