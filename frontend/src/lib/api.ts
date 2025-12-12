import { config } from '@/lib/config';
import { AuthService } from '@/lib/auth';

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  private async getAuthHeaders(isFormData: boolean = false): Promise<HeadersInit> {
    const token = AuthService.getAccessToken();
    const headers: HeadersInit = {};

    // Don't set Content-Type for FormData - browser will set it with boundary
    if (!isFormData) {
      headers['Content-Type'] = 'application/json';
    }

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    return headers;
  }

  async get<T>(endpoint: string): Promise<T> {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'GET',
      headers,
    });

    if (!response.ok) {
      if (response.status === 401) {
        // Token expired or invalid, redirect to login
        AuthService.clearAuth();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async post<T>(endpoint: string, data?: unknown): Promise<T> {
    const isFormData = data instanceof FormData;
    const headers = await this.getAuthHeaders(isFormData);
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers,
      body: isFormData ? data : (data ? JSON.stringify(data) : undefined),
    });

    if (!response.ok) {
      if (response.status === 401) {
        AuthService.clearAuth();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async put<T>(endpoint: string, data?: unknown): Promise<T> {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'PUT',
      headers,
      body: data ? JSON.stringify(data) : undefined,
    });

    if (!response.ok) {
      if (response.status === 401) {
        AuthService.clearAuth();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async delete<T>(endpoint: string): Promise<T> {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      if (response.status === 401) {
        AuthService.clearAuth();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async patch<T>(endpoint: string, data?: unknown): Promise<T> {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'PATCH',
      headers,
      body: data ? JSON.stringify(data) : undefined,
    });

    if (!response.ok) {
      if (response.status === 401) {
        AuthService.clearAuth();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }
}

// Create API client instances
// Auth-proxy handles authentication endpoints
export const api = new ApiClient(config.api.url);
export const authApi = new ApiClient(config.api.url);
export const userApi = new ApiClient(config.api.url);

// Direct service clients
export const channelApi = new ApiClient(config.channelService.url);
export const messageApi = new ApiClient(config.messageService.url);
export const fileApi = new ApiClient(config.filesService.url);
export const filesApi = new ApiClient(config.filesService.url);
export const threadsApi = new ApiClient(config.threadsService.url);

// Analytics API uses the message service directly for BI dashboard
export const analyticsApi = new ApiClient(config.messageService.url);
