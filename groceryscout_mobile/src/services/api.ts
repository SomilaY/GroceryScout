
import * as SecureStore from 'expo-secure-store';
import { router } from 'expo-router';
import { getToken } from './auth';

const API_BASE_URL = 'http://192.168.101.142:3000';
const TOKEN_KEY = 'groceryscout_access_token';

export async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getToken();

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

  if (response.status === 401) {
    const isPublicAuthEndpoint =
      endpoint === '/api/v1/login' ||
      endpoint === '/api/v1/register';

    if (!isPublicAuthEndpoint && token) {
      await SecureStore.deleteItemAsync(TOKEN_KEY);
      router.replace('/login');
    }

    throw new Error(`API request failed (${response.status})`);
  }

  if (!response.ok) {
    throw new Error(`API request failed (${response.status})`);
  }

  return response.json() as Promise<T>;
}

export { API_BASE_URL };
