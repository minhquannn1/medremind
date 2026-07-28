/**
 * Patient authentication against the backend account database.
 * The session token is stored locally by the app store.
 */
import { SCAN_API_URL } from '@/features/scan/aiScanner';

const API_BASE = SCAN_API_URL.replace(/\/scan-prescription\/?$/, '');
const REQUEST_TIMEOUT_MS = 20_000;

export interface AuthAccount {
  userId: number;
  email: string;
  name: string;
}

export type AuthErrorCode =
  | 'email_taken'
  | 'invalid_credentials'
  | 'account_deleted'
  | 'weak_password'
  | 'missing_fields'
  | 'network';

export type AuthResult =
  | { ok: true; token: string; account: AuthAccount }
  | { ok: false; error: AuthErrorCode };

async function post(path: string, body: unknown): Promise<AuthResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`${API_BASE}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const data = (await res.json().catch(() => ({}))) as {
      ok?: boolean;
      token?: string;
      userId?: number;
      name?: string;
      error?: AuthErrorCode;
    };
    if (!res.ok || !data.ok || !data.token || data.userId == null) {
      return { ok: false, error: data.error ?? 'network' };
    }
    return {
      ok: true,
      token: data.token,
      account: { userId: data.userId, email: String((body as { email: string }).email).toLowerCase(), name: data.name ?? '' },
    };
  } catch {
    return { ok: false, error: 'network' };
  } finally {
    clearTimeout(timer);
  }
}

export function registerPatient(email: string, password: string, name: string): Promise<AuthResult> {
  return post('/patient/register', { email: email.trim(), password, name: name.trim() });
}

export function loginPatient(email: string, password: string): Promise<AuthResult> {
  return post('/patient/login', { email: email.trim(), password });
}

/**
 * Permanently deletes the account and all server-side data (backup + any
 * doctor-shared snapshot, identified by pairCode). Required by App Store
 * Guideline 5.1.1(v).
 */
export async function deletePatientAccount(
  token: string,
  pairCode: string | null,
): Promise<boolean> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`${API_BASE}/patient/account`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        'bypass-tunnel-reminder': 'true',
      },
      body: JSON.stringify({ pairCode }),
      signal: controller.signal,
    });
    return res.ok;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}
