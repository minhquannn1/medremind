import { useEffect, useState } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { initDatabase } from '@/db/init';
import { initI18n, detectDeviceLanguage } from '@/i18n';
import { useAppStore } from '@/store/appStore';
import { configureNotifications } from '@/features/notifications/scheduler';
import { colors } from '@/theme';

export default function RootLayout() {
  const [booted, setBooted] = useState(false);
  const load = useAppStore((s) => s.load);

  useEffect(() => {
    (async () => {
      // i18n must init before any t() call (e.g. notification channel name)
      initI18n(detectDeviceLanguage());
      await initDatabase();
      await load();
      await configureNotifications();
      setBooted(true);
    })();
  }, [load]);

  if (!booted) {
    return (
      <View style={styles.splash}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={styles.flex}>
      <SafeAreaProvider>
        <StatusBar style="dark" />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.canvas } }}>
          <Stack.Screen name="index" />
          <Stack.Screen name="auth" />
          <Stack.Screen name="onboarding" />
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="settings" options={{ presentation: 'modal' }} />
        </Stack>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.canvas,
  },
});
