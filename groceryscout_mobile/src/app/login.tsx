
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';

import { login } from '@/services/auth';

export default function LoginScreen() {
  const router = useRouter();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleLogin() {
    if (!email.trim() || !password) {
      Alert.alert('Missing details', 'Please enter your email and password.');
      return;
    }

    try {
      setLoading(true);
      await login(email.trim(), password);
      router.replace('/(tabs)');
    } catch (error) {
      Alert.alert(
        'Unable to sign in',
        error instanceof Error ? error.message : 'Please try again.'
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.content}>
        <View style={styles.brand}>
          <View style={styles.logoMark}>
            <Text style={styles.logoLetter}>G</Text>
          </View>
          <Text style={styles.brandName}>groceryscout</Text>
        </View>

        <View style={styles.heading}>
          <Text style={styles.eyebrow}>WELCOME BACK</Text>
          <Text style={styles.title}>Good to see you.</Text>
          <Text style={styles.subtitle}>
            Sign in to find better prices and make every shop count.
          </Text>
        </View>

        <View style={styles.form}>
          <View style={styles.field}>
            <Text style={styles.label}>Email address</Text>
            <TextInput
              style={styles.input}
              placeholder="name@example.com"
              placeholderTextColor="#A0AAA3"
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Password</Text>
            <TextInput
              style={styles.input}
              placeholder="Enter your password"
              placeholderTextColor="#A0AAA3"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              autoCapitalize="none"
            />
          </View>

          <Pressable
            style={({ pressed }) => [
              styles.loginButton,
              pressed && styles.buttonPressed,
              loading && styles.buttonDisabled,
            ]}
            onPress={handleLogin}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.loginButtonText}>Sign in</Text>
            )}
          </Pressable>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>New to GroceryScout?</Text>
          <Pressable onPress={() => router.push('/register')}>
            <Text style={styles.footerLink}>Create an account</Text>
          </Pressable>
        </View>

        <Text style={styles.bottomNote}>
          SHOP SMARTER. SAVE MORE.
        </Text>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FAFCFA',
    justifyContent: 'center',
    paddingHorizontal: 28,
    paddingVertical: 36,
  },
  content: {
    width: '100%',
    maxWidth: 420,
    alignSelf: 'center',
  },
  brand: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 11,
    marginBottom: 64,
  },
  logoMark: {
    width: 42,
    height: 42,
    borderRadius: 13,
    backgroundColor: '#174C32',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoLetter: {
    color: '#FFFFFF',
    fontSize: 25,
    fontWeight: '800',
  },
  brandName: {
    fontSize: 20,
    fontWeight: '800',
    letterSpacing: -0.8,
    color: '#173B29',
  },
  heading: {
    marginBottom: 38,
  },
  eyebrow: {
    color: '#43815A',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 14,
  },
  title: {
    color: '#183526',
    fontSize: 34,
    fontWeight: '800',
    letterSpacing: -1.3,
  },
  subtitle: {
    color: '#7B8980',
    fontSize: 15,
    lineHeight: 24,
    marginTop: 12,
    maxWidth: 310,
  },
  form: {
    gap: 23,
  },
  field: {
    gap: 10,
  },
  label: {
    color: '#304638',
    fontSize: 13,
    fontWeight: '700',
  },
  input: {
    height: 56,
    borderWidth: 1,
    borderColor: '#E3EAE4',
    borderRadius: 13,
    paddingHorizontal: 17,
    fontSize: 15,
    color: '#183526',
    backgroundColor: '#FFFFFF',
  },
  loginButton: {
    height: 57,
    borderRadius: 14,
    backgroundColor: '#174C32',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
  },
  buttonPressed: {
    opacity: 0.85,
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  loginButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
    letterSpacing: 0.3,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 5,
    marginTop: 34,
  },
  footerText: {
    color: '#87938B',
    fontSize: 13,
  },
  footerLink: {
    color: '#267346',
    fontSize: 13,
    fontWeight: '800',
  },
  bottomNote: {
    color: '#A0ACA3',
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 2,
    textAlign: 'center',
    marginTop: 58,
  },
});
