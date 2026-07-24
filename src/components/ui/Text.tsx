import { Text as RNText, TextProps as RNTextProps, StyleSheet } from 'react-native';
import { colors, fontSize, fontWeight, lineHeight } from '@/theme';

type Variant =
  | 'display'
  | 'title'
  | 'heading'
  | 'subheading'
  | 'body'
  | 'bodyStrong'
  | 'label'
  | 'caption';

type ColorKey = 'text' | 'textMuted' | 'textFaint' | 'textInverse' | 'primary' | 'accent' | 'danger' | 'success' | 'warn';

interface AppTextProps extends RNTextProps {
  variant?: Variant;
  color?: ColorKey;
  center?: boolean;
}

const colorMap: Record<ColorKey, string> = {
  text: colors.text,
  textMuted: colors.textMuted,
  textFaint: colors.textFaint,
  textInverse: colors.textInverse,
  primary: colors.primary,
  accent: colors.accent,
  danger: colors.danger,
  success: colors.success,
  warn: colors.warn,
};

export function Text({
  variant = 'body',
  color = 'text',
  center,
  style,
  ...rest
}: AppTextProps) {
  return (
    <RNText
      style={[styles[variant], { color: colorMap[color] }, center && styles.center, style]}
      {...rest}
    />
  );
}

const styles = StyleSheet.create({
  display: {
    fontSize: fontSize.display,
    fontWeight: fontWeight.bold,
    lineHeight: fontSize.display * lineHeight.tight,
    letterSpacing: -0.5,
  },
  title: {
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.bold,
    lineHeight: fontSize['3xl'] * lineHeight.tight,
    letterSpacing: -0.4,
  },
  heading: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    lineHeight: fontSize['2xl'] * lineHeight.snug,
    letterSpacing: -0.3,
  },
  subheading: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.semibold,
    lineHeight: fontSize.xl * lineHeight.snug,
  },
  body: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.regular,
    lineHeight: fontSize.base * lineHeight.normal,
  },
  bodyStrong: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    lineHeight: fontSize.base * lineHeight.normal,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    lineHeight: fontSize.sm * lineHeight.snug,
    letterSpacing: 0.2,
  },
  caption: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
    lineHeight: fontSize.xs * lineHeight.snug,
    letterSpacing: 0.2,
  },
  center: { textAlign: 'center' },
});
