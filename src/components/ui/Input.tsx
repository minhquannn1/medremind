import { forwardRef } from 'react';
import {
  View,
  TextInput,
  TextInputProps,
  StyleSheet,
  Pressable,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Text } from './Text';
import { colors, radius, spacing, fontSize } from '@/theme';

interface InputProps extends TextInputProps {
  label?: string;
  error?: string;
  hint?: string;
  icon?: keyof typeof Ionicons.glyphMap;
  suffix?: string;
  onPressContainer?: () => void;
  editableLook?: boolean;
}

export const Input = forwardRef<TextInput, InputProps>(function Input(
  { label, error, hint, icon, suffix, onPressContainer, editableLook = true, style, ...rest },
  ref,
) {
  const Container = onPressContainer ? Pressable : View;
  return (
    <View style={styles.wrap}>
      {label && (
        <Text variant="label" color="textMuted" style={styles.label}>
          {label}
        </Text>
      )}
      <Container
        onPress={onPressContainer}
        style={[
          styles.field,
          !editableLook && styles.fieldStatic,
          error && styles.fieldError,
        ]}
      >
        {icon && <Ionicons name={icon} size={20} color={colors.textFaint} />}
        <TextInput
          ref={ref}
          placeholderTextColor={colors.textFaint}
          editable={!onPressContainer}
          pointerEvents={onPressContainer ? 'none' : 'auto'}
          style={[styles.input, style]}
          {...rest}
        />
        {suffix && (
          <Text variant="body" color="textFaint">
            {suffix}
          </Text>
        )}
      </Container>
      {error ? (
        <Text variant="caption" color="danger" style={styles.help}>
          {error}
        </Text>
      ) : hint ? (
        <Text variant="caption" color="textFaint" style={styles.help}>
          {hint}
        </Text>
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  wrap: { marginBottom: spacing.lg },
  label: { marginBottom: spacing.xs },
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.surface,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.lg,
    minHeight: 52,
  },
  fieldStatic: { backgroundColor: colors.canvas },
  fieldError: { borderColor: colors.danger },
  input: {
    flex: 1,
    fontSize: fontSize.base,
    color: colors.text,
    paddingVertical: spacing.md,
  },
  help: { marginTop: spacing.xs, marginLeft: spacing.xs },
});
