
import '@/global.css';
import { Platform } from 'react-native';

export const Colors = {
  light: {
    text: '#1E293B',
    background: '#F8FAFC',
    backgroundElement: '#FFFFFF',
    backgroundSelected: '#DCFCE7',
    textSecondary: '#64748B',
    primary: '#22C55E',
    primaryDark: '#15803D',
    border: '#E2E8F0',
    glass: 'rgba(255,255,255,0.72)',
  },
  dark: {
    text: '#F8FAFC',
    background: '#0F172A',
    backgroundElement: '#1E293B',
    backgroundSelected: '#14532D',
    textSecondary: '#94A3B8',
    primary: '#22C55E',
    primaryDark: '#4ADE80',
    border: '#334155',
    glass: 'rgba(30,41,59,0.72)',
  },
} as const;

export type ThemeColor = keyof typeof Colors.light & keyof typeof Colors.dark;

export const Fonts = Platform.select({
  ios: {
    sans: 'system-ui',
    serif: 'ui-serif',
    rounded: 'ui-rounded',
    mono: 'ui-monospace',
  },
  default: {
    sans: 'normal',
    serif: 'serif',
    rounded: 'normal',
    mono: 'monospace',
  },
  web: {
    sans: 'var(--font-display)',
    serif: 'var(--font-serif)',
    rounded: 'var(--font-rounded)',
    mono: 'var(--font-mono)',
  },
});

export const Spacing = {
  half: 2,
  one: 4,
  two: 8,
  three: 16,
  four: 24,
  five: 32,
  six: 64,
} as const;

export const BottomTabInset = Platform.select({ ios: 50, android: 80 }) ?? 0;
export const MaxContentWidth = 800;
