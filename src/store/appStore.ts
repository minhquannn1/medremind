import { create } from 'zustand';
import { getSetting, setSetting, SettingsKeys } from '@/db/repositories/settings';
import { getPatientByAccount, claimOrphanPatient } from '@/db/repositories/patients';
import { importPatientData, deleteLocalPatientData } from '@/db/repositories/backup';
import { fetchServerBackup } from '@/features/sync/backup';
import { syncReminders } from '@/features/notifications/scheduler';
import {
  loginPatient,
  registerPatient,
  deletePatientAccount,
  type AuthAccount,
  type AuthErrorCode,
} from '@/features/auth/patientAuth';
import { detectDeviceLanguage, setLanguage as applyLanguage, type AppLanguage } from '@/i18n';

type AuthOutcome = { ok: true } | { ok: false; error: AuthErrorCode };

interface AppState {
  ready: boolean;
  authed: boolean;
  account: AuthAccount | null;
  onboarded: boolean;
  activePatientId: number | null;
  language: AppLanguage;
  load: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<AuthOutcome>;
  signUp: (email: string, password: string, name: string) => Promise<AuthOutcome>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<boolean>;
  completeOnboarding: (patientId: number) => Promise<void>;
  setLanguage: (lang: AppLanguage) => Promise<void>;
  setActivePatient: (id: number) => Promise<void>;
}

async function persistSession(token: string, account: AuthAccount): Promise<void> {
  await setSetting(SettingsKeys.authToken, token);
  await setSetting(SettingsKeys.accountUserId, String(account.userId));
  await setSetting(SettingsKeys.accountEmail, account.email);
  await setSetting(SettingsKeys.accountName, account.name);
}

export const useAppStore = create<AppState>((set) => ({
  ready: false,
  authed: false,
  account: null,
  onboarded: false,
  activePatientId: null,
  language: 'vi',

  load: async () => {
    const storedLang = (await getSetting(SettingsKeys.language)) as AppLanguage | null;
    const language = storedLang ?? detectDeviceLanguage();
    applyLanguage(language);

    const token = await getSetting(SettingsKeys.authToken);
    if (!token) {
      set({ language, authed: false, account: null, onboarded: false, activePatientId: null, ready: true });
      return;
    }

    const userId = Number(await getSetting(SettingsKeys.accountUserId));
    const account: AuthAccount = {
      userId,
      email: (await getSetting(SettingsKeys.accountEmail)) ?? '',
      name: (await getSetting(SettingsKeys.accountName)) ?? '',
    };
    const patient = await getPatientByAccount(userId);
    set({
      language,
      authed: true,
      account,
      onboarded: !!patient,
      activePatientId: patient?.id ?? null,
      ready: true,
    });
  },

  signIn: async (email, password) => {
    const res = await loginPatient(email, password);
    if (!res.ok) return res;
    await persistSession(res.token, res.account);
    let patient = await getPatientByAccount(res.account.userId);
    if (!patient) {
      // Fresh device: restore the account's cloud backup if one exists.
      const backup = await fetchServerBackup(res.token);
      if (backup) {
        try {
          const patientId = await importPatientData(backup, res.account.userId, res.account.email);
          await syncReminders(patientId);
          patient = await getPatientByAccount(res.account.userId);
        } catch {
          // A failed restore should not block sign-in; the user can start fresh.
          patient = await getPatientByAccount(res.account.userId);
        }
      }
    }
    set({
      authed: true,
      account: res.account,
      onboarded: !!patient,
      activePatientId: patient?.id ?? null,
    });
    return { ok: true };
  },

  signUp: async (email, password, name) => {
    const res = await registerPatient(email, password, name);
    if (!res.ok) return res;
    await persistSession(res.token, res.account);
    // Let this new account adopt any pre-existing on-device profile.
    await claimOrphanPatient(res.account.userId, res.account.email);
    const patient = await getPatientByAccount(res.account.userId);
    set({
      authed: true,
      account: res.account,
      onboarded: !!patient,
      activePatientId: patient?.id ?? null,
    });
    return { ok: true };
  },

  signOut: async () => {
    // Clear the session only — on-device medication data stays, tied to the
    // account, and is restored on next sign-in.
    await setSetting(SettingsKeys.authToken, '');
    await setSetting(SettingsKeys.accountUserId, '');
    await setSetting(SettingsKeys.accountEmail, '');
    await setSetting(SettingsKeys.accountName, '');
    set({ authed: false, account: null, onboarded: false, activePatientId: null });
  },

  deleteAccount: async () => {
    const token = await getSetting(SettingsKeys.authToken);
    if (!token) return false;
    const pairCode = await getSetting(SettingsKeys.doctorPairCode);
    const deleted = await deletePatientAccount(token, pairCode || null);
    if (!deleted) return false;

    // Server data is gone; remove the on-device copy and its reminders too.
    const userId = Number(await getSetting(SettingsKeys.accountUserId));
    const patient = await getPatientByAccount(userId);
    if (patient) {
      await deleteLocalPatientData(patient.id);
      try {
        await syncReminders(patient.id);
      } catch {
        // Reminder cleanup is best-effort; nothing references the data anymore.
      }
    }

    await setSetting(SettingsKeys.authToken, '');
    await setSetting(SettingsKeys.accountUserId, '');
    await setSetting(SettingsKeys.accountEmail, '');
    await setSetting(SettingsKeys.accountName, '');
    set({ authed: false, account: null, onboarded: false, activePatientId: null });
    return true;
  },

  completeOnboarding: async (patientId: number) => {
    set({ onboarded: true, activePatientId: patientId });
  },

  setLanguage: async (lang: AppLanguage) => {
    await setSetting(SettingsKeys.language, lang);
    applyLanguage(lang);
    set({ language: lang });
  },

  setActivePatient: async (id: number) => {
    set({ activePatientId: id });
  },
}));
