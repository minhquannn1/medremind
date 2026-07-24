import { ReactNode } from 'react';
import {
  ScrollView,
  View,
  StyleSheet,
  RefreshControl,
  ViewStyle,
  StyleProp,
} from 'react-native';
import { SafeAreaView, Edge } from 'react-native-safe-area-context';
import { colors, spacing } from '@/theme';

interface ScreenProps {
  children: ReactNode;
  scroll?: boolean;
  padded?: boolean;
  edges?: Edge[];
  refreshing?: boolean;
  onRefresh?: () => void;
  contentStyle?: StyleProp<ViewStyle>;
  background?: 'canvas' | 'surface' | 'primary';
}

export function Screen({
  children,
  scroll = true,
  padded = true,
  edges = ['top'],
  refreshing,
  onRefresh,
  contentStyle,
  background = 'canvas',
}: ScreenProps) {
  const bg =
    background === 'primary'
      ? colors.primary
      : background === 'surface'
        ? colors.surface
        : colors.canvas;

  const inner = (
    <View style={[padded && styles.padded, contentStyle]}>{children}</View>
  );

  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: bg }]} edges={edges}>
      {scroll ? (
        <ScrollView
          style={styles.flex}
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          refreshControl={
            onRefresh ? (
              <RefreshControl
                refreshing={!!refreshing}
                onRefresh={onRefresh}
                tintColor={colors.primary}
              />
            ) : undefined
          }
        >
          {inner}
        </ScrollView>
      ) : (
        <View style={styles.flex}>{inner}</View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  flex: { flex: 1 },
  scrollContent: { flexGrow: 1, paddingBottom: spacing['3xl'] },
  padded: { paddingHorizontal: spacing.xl, paddingTop: spacing.lg },
});
