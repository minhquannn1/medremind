/**
 * Design tokens — "soft clinical" direction.
 * Calm, trustworthy teal primary with warm accents, generous rhythm,
 * soft depth. Single source of truth for color / spacing / type / radius.
 */

export const palette = {
  // Brand — teal conveys health, calm, trust
  teal900: '#0A4F4E',
  teal700: '#0E7C7B',
  teal500: '#16A6A4',
  teal300: '#7CD0CE',
  teal100: '#D6F0EF',
  teal50: '#EEF8F8',

  // Warm accent — encouragement, highlights
  coral600: '#E8674C',
  coral400: '#F2937E',
  coral100: '#FCE3DC',

  // Amber — refill / attention
  amber600: '#D98A0B',
  amber100: '#FBEFD3',

  // Status
  green600: '#2E9E5B',
  green100: '#D9F2E3',
  red600: '#D64545',
  red100: '#F8DCDC',

  // Neutrals (warm-tinted grays)
  ink900: '#16201F',
  ink700: '#35413F',
  ink500: '#5C6967',
  ink400: '#8A9694',
  ink300: '#B9C2C0',
  ink200: '#DCE3E1',
  ink100: '#EDF1F0',
  surface: '#FFFFFF',
  canvas: '#F4F7F6',
  white: '#FFFFFF',
} as const;

export const colors = {
  primary: palette.teal700,
  primaryDark: palette.teal900,
  primaryBright: palette.teal500,
  primarySoft: palette.teal100,
  primaryFaint: palette.teal50,

  accent: palette.coral600,
  accentSoft: palette.coral100,

  warn: palette.amber600,
  warnSoft: palette.amber100,

  success: palette.green600,
  successSoft: palette.green100,
  danger: palette.red600,
  dangerSoft: palette.red100,

  text: palette.ink900,
  textMuted: palette.ink500,
  textFaint: palette.ink400,
  textInverse: palette.white,

  border: palette.ink200,
  borderStrong: palette.ink300,

  surface: palette.surface,
  canvas: palette.canvas,
  overlay: 'rgba(16, 32, 31, 0.45)',
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  '2xl': 32,
  '3xl': 48,
  '4xl': 64,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 18,
  xl: 28,
  pill: 999,
} as const;

export const fontSize = {
  xs: 12,
  sm: 14,
  base: 16,
  lg: 18,
  xl: 22,
  '2xl': 28,
  '3xl': 34,
  display: 44,
} as const;

export const fontWeight = {
  regular: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
} as const;

export const lineHeight = {
  tight: 1.15,
  snug: 1.3,
  normal: 1.5,
  relaxed: 1.65,
} as const;

export const shadow = {
  // soft, low-spread elevation for clinical calm
  card: {
    shadowColor: '#0A4F4E',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 16,
    elevation: 3,
  },
  floating: {
    shadowColor: '#0A4F4E',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.14,
    shadowRadius: 24,
    elevation: 8,
  },
} as const;

export type Spacing = keyof typeof spacing;
export type Radius = keyof typeof radius;
export type FontSize = keyof typeof fontSize;
