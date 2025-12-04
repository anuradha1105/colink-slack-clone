import axios, { type AxiosInstance, type AxiosRequestConfig } from 'axios';
import { config } from './config';
import { AuthService } from './auth';

export class ApiClient {
  private client: AxiosInstance;

  constructor(baseURL: string) {
    this.client = axios.create({
      baseURL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor to add auth token
    this.client.interceptors.request.use(
      (config) => {
        const tokens = AuthService.getTokens();
        if (tokens?.access_token) {
          config.headers.Authorization = `Bearer ${tokens.access_token}`;
          console.log('[API] Adding auth header to request:', config.url);
        } else {
          console.warn('[API] No access token available for request:', config.url);
        }

        // If sending FormData, remove Content-Type to let browser set it with boundary
        if (config.data instanceof FormData) {
          delete config.headers['Content-Type'];
        }

        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor to handle token refresh
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        const originalRequest = error.config;

        if (error.response?.status === 401 && !originalRequest._retry) {
          console.log('[API] Got 401 error, attempting token refresh...');
          originalRequest._retry = true;

          try {
            const tokens = AuthService.getTokens();
            if (tokens?.refresh_token) {
              console.log('[API] Refreshing token...');
              const newTokens = await AuthService.refreshToken(tokens.refresh_token);
              AuthService.saveTokens(newTokens);
              console.log('[API] Token refreshed successfully, retrying request');
              originalRequest.headers.Authorization = `Bearer ${newTokens.access_token}`;
              return this.client(originalRequest);
            } else {
              console.warn('[API] No refresh token available');
            }
          } catch (refreshError) {
            console.error('[API] Token refresh failed, clearing auth and redirecting to login', refreshError);
            AuthService.clearAuth();
            if (typeof window !== 'undefined') {
              window.location.href = '/login';
            }
            return Promise.reject(refreshError);
          }
        }

        return Promise.reject(error);
      }
    );
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }

  async patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.patch<T>(url, data, config);
    return response.data;
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }
}

// API client instances
export const authApi = new ApiClient(config.api.authProxy);
export const channelApi = new ApiClient(config.api.channel);
export const messageApi = new ApiClient(config.api.message);
export const threadsApi = new ApiClient(config.api.threads);
export const reactionsApi = new ApiClient(config.api.reactions);
export const filesApi = new ApiClient(config.api.files);
export const notificationsApi = new ApiClient(config.api.notifications);
export const analyticsApi = new ApiClient(config.api.message); // Analytics endpoints are on message service
