// Web Push for dose reminders on the PWA.
//
// A browser cannot schedule its own notifications the way iOS does, so the
// server does it: the signed-in web app registers a push subscription here,
// and a scheduler walks every subscription's cloud backup — the same backup
// that already syncs on every change — and pushes at each medication's
// wall-clock time in the subscriber's own timezone.
//
// Reminders on the web therefore require an account. That is inherent, not a
// product choice: without the backup the server has no schedule to push.
import webpush from 'web-push';
import { db } from './db.js';

db.exec(`
CREATE TABLE IF NOT EXISTS push_subscriptions (
  endpoint TEXT PRIMARY KEY,
  account_id INTEGER NOT NULL,
  subscription TEXT NOT NULL,
  timezone TEXT NOT NULL,
  lang TEXT NOT NULL DEFAULT 'vi',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_push_account ON push_subscriptions(account_id);
CREATE TABLE IF NOT EXISTS push_vapid (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  public_key TEXT NOT NULL,
  private_key TEXT NOT NULL
);
`);

// VAPID keys identify this server to browser push services. Generated once
// and kept in the database (which lives on the persistent volume), so no
// manual env setup — losing them would orphan every existing subscription.
function loadVapid() {
  const row = db.prepare('SELECT public_key, private_key FROM push_vapid WHERE id = 1').get();
  if (row) return { publicKey: row.public_key, privateKey: row.private_key };
  const keys = webpush.generateVAPIDKeys();
  db.prepare('INSERT INTO push_vapid (id, public_key, private_key) VALUES (1, ?, ?)')
    .run(keys.publicKey, keys.privateKey);
  return keys;
}

const vapid = loadVapid();
webpush.setVapidDetails('mailto:nguyenxavier201103@gmail.com', vapid.publicKey, vapid.privateKey);

export const vapidPublicKey = vapid.publicKey;

export function saveSubscription(accountId, subscription, timezone, lang) {
  if (!subscription || typeof subscription.endpoint !== 'string') return false;
  db.prepare(
    `INSERT INTO push_subscriptions (endpoint, account_id, subscription, timezone, lang, created_at)
     VALUES (?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(endpoint) DO UPDATE SET
       account_id = excluded.account_id,
       subscription = excluded.subscription,
       timezone = excluded.timezone,
       lang = excluded.lang`,
  ).run(subscription.endpoint, accountId, JSON.stringify(subscription), timezone, lang);
  return true;
}

export function deleteSubscription(accountId, endpoint) {
  // Scoped to the owner so one user cannot unsubscribe another's browser.
  db.prepare('DELETE FROM push_subscriptions WHERE endpoint = ? AND account_id = ?')
    .run(endpoint, accountId);
}

export function deleteSubscriptionsForAccount(accountId) {
  db.prepare('DELETE FROM push_subscriptions WHERE account_id = ?').run(accountId);
}

/** "HH:mm" right now in an IANA timezone, or null when the zone is invalid. */
export function localHhmm(timezone, now = new Date()) {
  try {
    return new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(now).replace('24:', '00:');
  } catch {
    return null;
  }
}

/** Local date key used for once-per-day dedupe, e.g. "2026-09-18". */
function localDateKey(timezone, now = new Date()) {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone, dateStyle: 'short' }).format(now);
  } catch {
    return 'invalid';
  }
}

/** Active medications due at [hhmm] according to the account's backup. */
export function dueMedications(backupJson, hhmm) {
  let data;
  try {
    data = JSON.parse(backupJson);
  } catch {
    return [];
  }
  const meds = Array.isArray(data.medications) ? data.medications : [];
  const times = Array.isArray(data.scheduleTimes) ? data.scheduleTimes : [];
  const activeById = new Map(
    meds.filter((m) => (m.status ?? 'active') === 'active').map((m) => [m.id, m]),
  );
  return times
    .filter((t) => t.time === hhmm && activeById.has(t.medicationId))
    .map((t) => ({ name: activeById.get(t.medicationId).name, time: t.time }));
}

const TEXT = {
  vi: (name) => ({ title: 'Đến giờ uống thuốc', body: `${name} — bấm để xác nhận đã uống.` }),
  en: (name) => ({ title: 'Time for your medication', body: `${name} — tap to confirm you took it.` }),
};

// Once-per-day dedupe, in memory: a redeploy may re-send at most one dose,
// which is preferable to a missed one.
const sent = new Map();

export async function tick(now = new Date()) {
  // Drop yesterday's dedupe keys so the map cannot grow without bound.
  const today = new Date(now).toISOString().slice(0, 10);
  for (const key of sent.keys()) if (!key.endsWith(today) && !key.includes(today)) sent.delete(key);

  const subs = db.prepare(
    `SELECT s.endpoint, s.subscription, s.timezone, s.lang, b.data
       FROM push_subscriptions s
       JOIN backups b ON b.account_id = s.account_id`,
  ).all();

  for (const sub of subs) {
    const hhmm = localHhmm(sub.timezone, now);
    if (!hhmm) continue;
    const dateKey = localDateKey(sub.timezone, now);

    for (const med of dueMedications(sub.data, hhmm)) {
      const key = `${sub.endpoint}|${med.name}|${med.time}|${dateKey}`;
      if (sent.has(key)) continue;
      sent.set(key, true);

      const text = (TEXT[sub.lang] || TEXT.vi)(med.name);
      try {
        await webpush.sendNotification(
          JSON.parse(sub.subscription),
          JSON.stringify({ ...text, tag: `dose-${med.name}-${med.time}` }),
          { TTL: 15 * 60 },
        );
      } catch (err) {
        // 404/410 mean the browser revoked the subscription — clean it up.
        if (err && (err.statusCode === 404 || err.statusCode === 410)) {
          db.prepare('DELETE FROM push_subscriptions WHERE endpoint = ?').run(sub.endpoint);
        }
      }
    }
  }
}

export function startPushScheduler() {
  // 30s so a dose minute is never straddled; dedupe makes re-entry harmless.
  const timer = setInterval(() => {
    tick().catch((err) => console.error('[push] tick failed:', err.message));
  }, 30 * 1000);
  timer.unref?.();
  console.log('[push] dose reminder scheduler running');
}
