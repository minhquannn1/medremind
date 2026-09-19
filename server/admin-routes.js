// Admin console API.
//
// Answers "how is the app doing" from aggregates. It deliberately does NOT
// expose anyone's health data: the backups table holds a full copy of every
// patient's medications and dose history, and an operations dashboard has no
// business displaying that. Counts are computed from it; contents never leave.
//
// Emails are masked in every listing for the same reason.
import express from 'express';

import {
  adminEnabled,
  requireAdmin,
  signToken,
  verifyAdminPassword,
} from './auth.js';
import { db } from './db.js';

export const adminRouter = express.Router();

const maskEmail = (e) => String(e).replace(/^(.{1,2})[^@]*(@.*)$/, '$1***$2');

const count = (sql, ...args) => db.prepare(sql).get(...args)?.n ?? 0;

/** ISO timestamp [days] ago, matching how the app writes created_at. */
const daysAgo = (days) =>
  new Date(Date.now() - days * 86400000).toISOString();

adminRouter.post('/admin/login', (req, res) => {
  if (!adminEnabled) {
    return res.status(503).json({ ok: false, error: 'admin_disabled' });
  }
  const { password } = req.body || {};
  if (!verifyAdminPassword(password)) {
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  // sub 0: the console is a single role, not a user account.
  return res.json({ ok: true, token: signToken(0, 'admin') });
});

/// Feature totals, derived by walking every backup once.
///
/// Each backup is the patient's whole on-device database as JSON, so this is
/// the only place the server can see how much the app is actually used. The
/// walk is cached because it grows with the user base while the dashboard is
/// refreshed freely — but keyed on the data rather than on a clock, because a
/// time-based cache showed stale numbers right after a sync and made a
/// working dashboard look broken.
let featureCache = { key: null, value: null };

function backupsSignature() {
  const row = db.prepare(
    'SELECT COUNT(*) AS n, COALESCE(MAX(updated_at), \'\') AS last FROM backups',
  ).get();
  return `${row.n}:${row.last}`;
}

function featureTotals() {
  const key = backupsSignature();
  if (featureCache.value && featureCache.key === key) return featureCache.value;

  const rows = db.prepare('SELECT data FROM backups').all();
  const totals = {
    prescriptions: 0,
    medications: 0,
    scheduleTimes: 0,
    doseLogs: 0,
    dosesTaken: 0,
    dosesSkipped: 0,
    dosesMissed: 0,
    appointments: 0,
    accountsWithPrescription: 0,
    unreadable: 0,
  };

  for (const row of rows) {
    let data;
    try {
      data = JSON.parse(row.data);
    } catch {
      totals.unreadable += 1;
      continue;
    }
    const list = (k) => (Array.isArray(data[k]) ? data[k] : []);

    const prescriptions = list('prescriptions');
    totals.prescriptions += prescriptions.length;
    totals.medications += list('medications').length;
    totals.scheduleTimes += list('scheduleTimes').length;
    totals.appointments += list('appointments').length;
    if (prescriptions.length > 0) totals.accountsWithPrescription += 1;

    for (const dose of list('doseLogs')) {
      totals.doseLogs += 1;
      if (dose.status === 'taken') totals.dosesTaken += 1;
      else if (dose.status === 'skipped') totals.dosesSkipped += 1;
      else if (dose.status === 'missed') totals.dosesMissed += 1;
      // Anything else is 'pending': due later, not an outcome yet.
    }
  }

  featureCache = { key, value: totals };
  return totals;
}

adminRouter.get('/admin/stats', requireAdmin, (_req, res) => {
  const d7 = daysAgo(7);
  const d30 = daysAgo(30);

  const users = {
    accounts: count('SELECT COUNT(*) AS n FROM accounts'),
    new7d: count('SELECT COUNT(*) AS n FROM accounts WHERE created_at >= ?', d7),
    new30d: count('SELECT COUNT(*) AS n FROM accounts WHERE created_at >= ?', d30),
    deleted: count('SELECT COUNT(*) AS n FROM deleted_accounts'),
    // A backup exists only after the app syncs data, so this is the honest
    // count of accounts that actually used the app rather than just signing up.
    withData: count('SELECT COUNT(*) AS n FROM backups'),
    active7d: count('SELECT COUNT(*) AS n FROM backups WHERE updated_at >= ?', d7),
    active30d: count('SELECT COUNT(*) AS n FROM backups WHERE updated_at >= ?', d30),
  };

  const doctors = {
    total: count('SELECT COUNT(*) AS n FROM doctors'),
    new30d: count('SELECT COUNT(*) AS n FROM doctors WHERE created_at >= ?', d30),
    patientRecords: count('SELECT COUNT(*) AS n FROM patients'),
    paired: count('SELECT COUNT(*) AS n FROM patients WHERE linked = 1'),
    withSnapshot: count('SELECT COUNT(*) AS n FROM snapshots'),
  };

  // push_subscriptions is created by push.js, which may not have run yet.
  let push = { subscriptions: 0, accounts: 0 };
  try {
    push = {
      subscriptions: count('SELECT COUNT(*) AS n FROM push_subscriptions'),
      accounts: count(
        'SELECT COUNT(DISTINCT account_id) AS n FROM push_subscriptions',
      ),
    };
  } catch {
    // Table absent: the scheduler has not started on this instance yet.
  }

  const features = featureTotals();
  // Every dose with an outcome, matching how the app's own adherence ring
  // counts: pending doses are excluded (not due yet), missed ones are not —
  // leaving them out reported a flattering 100% for data that was 86%.
  const resolved =
    features.dosesTaken + features.dosesSkipped + features.dosesMissed;

  res.json({
    ok: true,
    users,
    doctors,
    push,
    features,
    // Across every backup, not a per-user average: the headline number for
    // "is the app doing its job".
    adherence: resolved === 0
      ? null
      : Math.round((features.dosesTaken / resolved) * 100),
    generatedAt: new Date().toISOString(),
  });
});

adminRouter.get('/admin/accounts', requireAdmin, (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 25, 100);
  const rows = db.prepare(
    `SELECT a.id, a.email, a.name, a.created_at,
            b.updated_at AS last_sync,
            LENGTH(b.data) AS data_bytes
       FROM accounts a
       LEFT JOIN backups b ON b.account_id = a.id
      ORDER BY a.created_at DESC
      LIMIT ?`,
  ).all(limit);

  res.json({
    ok: true,
    accounts: rows.map((r) => ({
      id: r.id,
      email: maskEmail(r.email),
      name: r.name,
      createdAt: r.created_at,
      lastSync: r.last_sync,
      dataBytes: r.data_bytes ?? 0,
    })),
  });
});

/// Removes an account and everything attached to it.
///
/// Requires the caller to repeat the account's full email: the listing only
/// ever shows masked addresses, so this cannot be fired from the dashboard by
/// a mis-click — the operator has to know who they are deleting.
adminRouter.delete('/admin/accounts/:id', requireAdmin, (req, res) => {
  const id = Number(req.params.id);
  const { email } = req.body || {};
  const account = db.prepare('SELECT id, email FROM accounts WHERE id = ?').get(id);
  if (!account) return res.status(404).json({ ok: false, error: 'not_found' });

  if (String(email || '').trim().toLowerCase() !== account.email.toLowerCase()) {
    return res.status(400).json({ ok: false, error: 'email_mismatch' });
  }

  db.prepare('DELETE FROM backups WHERE account_id = ?').run(id);
  try {
    db.prepare('DELETE FROM push_subscriptions WHERE account_id = ?').run(id);
  } catch {
    // Table absent; nothing to clean up.
  }
  db.prepare('DELETE FROM accounts WHERE id = ?').run(id);

  console.log(`[admin] deleted account ${maskEmail(account.email)}`);
  res.json({ ok: true });
});
