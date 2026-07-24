import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getLocales } from 'expo-localization';
import { vi } from './locales/vi';
import { en } from './locales/en';

export type AppLanguage = 'vi' | 'en';

const SUPPORTED: AppLanguage[] = ['vi', 'en'];

export function detectDeviceLanguage(): AppLanguage {
  const code = getLocales()[0]?.languageCode ?? 'vi';
  return (SUPPORTED as string[]).includes(code) ? (code as AppLanguage) : 'vi';
}

export function initI18n(language: AppLanguage) {
  if (i18n.isInitialized) {
    i18n.changeLanguage(language);
    return i18n;
  }
  i18n.use(initReactI18next).init({
    resources: {
      vi: { translation: vi },
      en: { translation: en },
    },
    lng: language,
    fallbackLng: 'vi',
    interpolation: { escapeValue: false },
    returnNull: false,
  });
  return i18n;
}

export function setLanguage(language: AppLanguage) {
  i18n.changeLanguage(language);
}

export default i18n;
