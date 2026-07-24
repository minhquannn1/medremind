/**
 * Fetches a plain-language explanation of a medicine from the backend proxy
 * (same server as the prescription scanner — it calls GPT-4o with just text).
 */
import { SCAN_API_URL } from '@/features/scan/aiScanner';
import type { AppLanguage } from '@/i18n';

// Derive the explain endpoint from the scan endpoint so they share one host/env.
const EXPLAIN_API_URL = SCAN_API_URL.replace(/\/scan-prescription\/?$/, '/explain-medication');

const REQUEST_TIMEOUT_MS = 30_000;

export interface ExplainResult {
  ok: boolean;
  explanation?: string;
  error?: 'network' | 'server' | 'timeout';
}

export async function explainMedication(
  name: string,
  lang: AppLanguage,
  opts: { dosage?: string | null; form?: string | null } = {},
): Promise<ExplainResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(EXPLAIN_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true' },
      body: JSON.stringify({ name, lang, dosage: opts.dosage, form: opts.form }),
      signal: controller.signal,
    });
    if (!res.ok) return { ok: false, error: 'server' };
    const data = (await res.json()) as { ok: boolean; explanation?: string };
    if (!data.ok || !data.explanation) return { ok: false, error: 'server' };
    return { ok: true, explanation: data.explanation };
  } catch (err) {
    const isAbort = err instanceof Error && err.name === 'AbortError';
    return { ok: false, error: isAbort ? 'timeout' : 'network' };
  } finally {
    clearTimeout(timer);
  }
}
