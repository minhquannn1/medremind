import { Redirect } from 'expo-router';
import { useAppStore } from '@/store/appStore';

export default function Index() {
  const { ready, authed, onboarded } = useAppStore();
  if (!ready) return null;
  if (!authed) return <Redirect href="/auth" />;
  return <Redirect href={onboarded ? '/(tabs)' : '/onboarding'} />;
}
