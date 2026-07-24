import { View, Pressable, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Text } from './Text';
import { colors, spacing } from '@/theme';

interface HeaderProps {
  title: string;
  onBack?: () => void;
  actionIcon?: keyof typeof Ionicons.glyphMap;
  onAction?: () => void;
}

export function Header({ title, onBack, actionIcon, onAction }: HeaderProps) {
  const router = useRouter();
  const back = onBack ?? (() => router.back());
  return (
    <View style={styles.header}>
      <Pressable onPress={back} hitSlop={10} style={styles.iconBtn} accessibilityLabel="Back">
        <Ionicons name="chevron-back" size={26} color={colors.text} />
      </Pressable>
      <Text variant="subheading" style={styles.title} numberOfLines={1}>
        {title}
      </Text>
      {actionIcon && onAction ? (
        <Pressable onPress={onAction} hitSlop={10} style={styles.iconBtn}>
          <Ionicons name={actionIcon} size={24} color={colors.primary} />
        </Pressable>
      ) : (
        <View style={styles.iconBtn} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingBottom: spacing.md,
  },
  iconBtn: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  title: { flex: 1, textAlign: 'center' },
});
