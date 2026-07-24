import { useState } from 'react';
import { View, Pressable, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';
import { Text, Card, Input } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';

export interface ListItem {
  id: number;
  label: string;
  sub?: string | null;
}

interface EditableListSectionProps {
  items: ListItem[];
  placeholder: string;
  addLabel: string;
  icon: keyof typeof Ionicons.glyphMap;
  tone?: 'primary' | 'danger';
  onAdd: (text: string) => Promise<void> | void;
  onRemove: (id: number) => Promise<void> | void;
}

export function EditableListSection({
  items,
  placeholder,
  addLabel,
  icon,
  tone = 'primary',
  onAdd,
  onRemove,
}: EditableListSectionProps) {
  const { t } = useTranslation();
  const [adding, setAdding] = useState(false);
  const [text, setText] = useState('');
  const accent = tone === 'danger' ? colors.danger : colors.primary;
  const accentSoft = tone === 'danger' ? colors.dangerSoft : colors.primarySoft;

  const submit = async () => {
    if (!text.trim()) {
      setAdding(false);
      return;
    }
    await onAdd(text.trim());
    setText('');
    setAdding(false);
  };

  return (
    <Card style={styles.card}>
      {items.length === 0 && !adding && (
        <Text variant="body" color="textFaint">
          {t('common.none')}
        </Text>
      )}

      {items.map((item) => (
        <View key={item.id} style={styles.row}>
          <View style={[styles.dot, { backgroundColor: accentSoft }]}>
            <Ionicons name={icon} size={16} color={accent} />
          </View>
          <View style={styles.flex}>
            <Text variant="body">{item.label}</Text>
            {item.sub && (
              <Text variant="caption" color="textMuted">
                {item.sub}
              </Text>
            )}
          </View>
          <Pressable onPress={() => onRemove(item.id)} hitSlop={8}>
            <Ionicons name="close-circle-outline" size={22} color={colors.textFaint} />
          </Pressable>
        </View>
      ))}

      {adding ? (
        <View style={styles.addRow}>
          <View style={styles.flex}>
            <Input
              value={text}
              onChangeText={setText}
              placeholder={placeholder}
              autoFocus
              onSubmitEditing={submit}
              returnKeyType="done"
            />
          </View>
          <Pressable onPress={submit} style={[styles.confirmBtn, { backgroundColor: accent }]}>
            <Ionicons name="checkmark" size={20} color={colors.textInverse} />
          </Pressable>
        </View>
      ) : (
        <Pressable style={styles.addBtn} onPress={() => setAdding(true)}>
          <Ionicons name="add" size={18} color={accent} />
          <Text variant="label" style={{ color: accent }}>
            {addLabel}
          </Text>
        </Pressable>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { gap: spacing.md },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  dot: {
    width: 32,
    height: 32,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  flex: { flex: 1 },
  addRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm },
  confirmBtn: {
    width: 52,
    height: 52,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, alignSelf: 'flex-start' },
});
