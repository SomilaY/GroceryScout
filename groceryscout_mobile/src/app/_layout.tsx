
import { useEffect, useState } from 'react';
import {
  DarkTheme,
  DefaultTheme,
  ThemeProvider,
  Stack,
  useRouter,
  useSegments,
} from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { getToken } from '@/services/auth';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const router = useRouter();
  const segments = useSegments();

  const [authChecked, setAuthChecked] = useState(false);

  useEffect(() => {
    let active = true;

    async function checkAuthentication() {
      try {
        const token = await getToken();

        if (!active) return;

        const currentScreen = segments[0];
        const isAuthScreen =
          currentScreen === 'login' || currentScreen === 'register';

        if (!token && !isAuthScreen) {
          router.replace('/login');
        } else if (token && isAuthScreen) {
          router.replace('/(tabs)');
        }
      } catch {
        if (active) {
          router.replace('/login');
        }
      } finally {
        if (active) {
          setAuthChecked(true);
        }
      }
    }

    checkAuthentication();

    return () => {
      active = false;
    };
  }, [segments, router]);

  if (!authChecked) {
    return null;
  }

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AnimatedSplashOverlay />

      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="login" />
        <Stack.Screen name="register" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="compare" />
      </Stack>
    </ThemeProvider>
  );
}
