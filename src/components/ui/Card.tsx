import { ReactNode } from 'react';
import { View, Pressable, StyleSheet, ViewStyle, StyleProp } from 'react-native';
import { colors, radius, spacing, shadow } from '@/theme';

interface CardProps {
  children: ReactNode;
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
  padded?: boolean;
  elevated?: boolean;
  tone?: 'surface' | 'primary' | 'accent' | 'warn' | 'success';
}

const toneBg: Record<NonNullable<CardProps['tone']>, string> = {
  surface: colors.surface,
  primary: colors.primarySoft,
  accent: colors.accentSoft,
  warn: colors.warnSoft,
  success: colors.successSoft,
};

export function Card({
  children,
  onPress,
  style,
  padded = true,
  elevated = true,
  tone = 'surface',
}: CardProps) {
  const content = (
    <View
      style={[
        styles.card,
        { backgroundColor: toneBg[tone] },
        padded && styles.padded,
        elevated && tone === 'surface' && shadow.card,
        style,
      ]}
    >
      {children}
    </View>
  );

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => pressed && styles.pressed}
        accessibilityRole="button"
      >
        {content}
      </Pressable>
    );
  }
  return content;
}

const styles = StyleSheet.create({
  card: {
    borderRadius: radius.lg,
  },
  padded: { padding: spacing.lg },
  pressed: { opacity: 0.92, transform: [{ scale: 0.99 }] },
});
