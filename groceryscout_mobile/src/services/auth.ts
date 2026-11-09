
import * as SecureStore from 'expo-secure-store';
import { apiRequest } from './api';

const TOKEN_KEY = 'groceryscout_access_token';
const USER_KEY = 'groceryscout_user';

export interface AuthUser {
  id: number;
  name: string;
  email: string;
}

interface AuthResponse {
  message: string;
  user: AuthUser;
  access_token: string;
  token_type: string;
  expires_in: number;
}

export async function saveToken(token: string) {
  await SecureStore.setItemAsync(TOKEN_KEY, token);
}

export async function getToken(): Promise<string | null> {
  return SecureStore.getItemAsync(TOKEN_KEY);
}

export async function saveUser(user: AuthUser) {
  await SecureStore.setItemAsync(USER_KEY, JSON.stringify(user));
}

export async function getUser(): Promise<AuthUser | null> {
  const user = await SecureStore.getItemAsync(USER_KEY);
  return user ? JSON.parse(user) as AuthUser : null;
}

export async function removeToken() {
  await SecureStore.deleteItemAsync(TOKEN_KEY);
  await SecureStore.deleteItemAsync(USER_KEY);
}

export async function login(email: string, password: string) {
  const response = await apiRequest<AuthResponse>('/api/v1/login', {
    method: 'POST',
    body: JSON.stringify({
      user: { email, password },
    }),
  });

  await saveToken(response.access_token);
  await saveUser(response.user);

  return response.user;
}

export async function register(
  name: string,
  email: string,
  password: string
) {
  const response = await apiRequest<AuthResponse>('/api/v1/register', {
    method: 'POST',
    body: JSON.stringify({
      user: { name, email, password },
    }),
  });

  await saveToken(response.access_token);
  await saveUser(response.user);

  return response.user;
}
