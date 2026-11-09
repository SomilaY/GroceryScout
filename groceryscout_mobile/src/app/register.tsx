
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

import { register } from '@/services/auth';

export default function RegisterScreen() {
  const router = useRouter();

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleRegister() {
    if (!name.trim() || !email.trim() || !password) {
      Alert.alert('Missing details', 'Please complete all fields.');
      return;
    }

    if (password.length < 8) {
      Alert.alert(
        'Password too short',
        'Your password must be at least 8 characters.'
      );
      return;
    }

    try {
      setLoading(true);
      await register(name.trim(), email.trim(), password);
      router.replace('/(tabs)');
    } catch (error) {
      Alert.alert(
        'Unable to create account',
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
          <Text style={styles.eyebrow}>GET STARTED</Text>
          <Text style={styles.title}>Shop smarter.</Text>
          <Text style={styles.subtitle}>
            Create your account and start discovering better grocery prices.
          </Text>
        </View>

        <View style={styles.form}>
          <View style={styles.field}>
            <Text style={styles.label}>Full name</Text>
            <TextInput
              style={styles.input}
              placeholder="Your name"
              placeholderTextColor="#A0AAA3"
              value={name}
              onChangeText={setName}
              autoCapitalize="words"
            />
          </View>

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
              placeholder="At least 8 characters"
              placeholderTextColor="#A0AAA3"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              autoCapitalize="none"
            />
          </View>

          <Pressable
            style={({ pressed }) => [
              styles.registerButton,
              pressed && styles.buttonPressed,
              loading && styles.buttonDisabled,
            ]}
            onPress={handleRegister}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.registerButtonText}>Create account</Text>
            )}
          </Pressable>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Already have an account?</Text>
          <Pressable onPress={() => router.replace('/login')}>
            <Text style={styles.footerLink}>Sign in</Text>
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
    paddingVertical: 30,
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
    marginBottom: 38,
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
    marginBottom: 28,
  },
  eyebrow: {
    color: '#43815A',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 12,
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
    marginTop: 10,
    maxWidth: 320,
  },
  form: {
    gap: 17,
  },
  field: {
    gap: 9,
  },
  label: {
    color: '#304638',
    fontSize: 13,
    fontWeight: '700',
  },
  input: {
    height: 54,
    borderWidth: 1,
    borderColor: '#E3EAE4',
    borderRadius: 13,
    paddingHorizontal: 17,
    fontSize: 15,
    color: '#183526',
    backgroundColor: '#FFFFFF',
  },
  registerButton: {
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
  registerButtonText: {
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
    marginTop: 26,
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
    marginTop: 38,
  },
});
