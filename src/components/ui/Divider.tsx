import { View, StyleSheet } from 'react-native';
import { colors, spacing } from '@/theme';

export function Divider({ spaced = true }: { spaced?: boolean }) {
  return <View style={[styles.line, spaced && styles.spaced]} />;
}

const styles = StyleSheet.create({
  line: { height: StyleSheet.hairlineWidth, backgroundColor: colors.border },
  spaced: { marginVertical: spacing.lg },
});
