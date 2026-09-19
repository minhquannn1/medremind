// node --test admin.test.mjs   (run from server/)
//
// Drives the admin console over HTTP against a throwaway database, because
// the interesting behaviour is in the route layer: who is refused, what is
// masked, and whether the numbers are honest.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { rmSync } from 'node:fs';

const DB = '/tmp/medoly-admin-test.db';
const PORT = 3211;
const BASE = `http://127.0.0.1:${PORT}`;
const PASSWORD = 'AdminTest!2026';

let server;

const api = (path, options = {}) =>
  fetch(`${BASE}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
  });

before(async () => {
  rmSync(DB, { force: true });
  rmSync(`${DB}-wal`, { force: true });
  rmSync(`${DB}-shm`, { force: true });
  server = spawn('node', ['index.js'], {
    env: { ...process.env, PORT: String(PORT), DOCTOR_DB_PATH: DB, ADMIN_PASSWORD: PASSWORD },
    stdio: 'ignore',
  });
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`${BASE}/health`);
      if (res.ok) return;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('server did not start');
});

after(() => {
  server?.kill();
  rmSync(DB, { force: true });
  rmSync(`${DB}-wal`, { force: true });
  rmSync(`${DB}-shm`, { force: true });
});

async function adminToken() {
  const res = await api('/api/admin/login', {
    method: 'POST',
    body: JSON.stringify({ password: PASSWORD }),
  });
  return (await res.json()).token;
}

test('a wrong password does not open the console', async () => {
  const res = await api('/api/admin/login', {
    method: 'POST',
    body: JSON.stringify({ password: 'not-it' }),
  });
  assert.equal(res.status, 401);
});

test('stats refuse an unauthenticated caller', async () => {
  assert.equal((await api('/api/admin/stats')).status, 401);
});

test('a patient token cannot read admin stats', async () => {
  // Role confusion would hand every account's data to any signed-in user.
  await api('/api/patient/register', {
    method: 'POST',
    body: JSON.stringify({ email: 'a@t.test', password: 'Passw0rd!x', name: 'A' }),
  });
  const login = await api('/api/patient/login', {
    method: 'POST',
    body: JSON.stringify({ email: 'a@t.test', password: 'Passw0rd!x' }),
  });
  const { token } = await login.json();

  const res = await api('/api/admin/stats', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 403);
});

test('counts separate signing up from actually using the app', async () => {
  const token = await adminToken();
  const stats = await (
    await api('/api/admin/stats', { headers: { Authorization: `Bearer ${token}` } })
  ).json();

  assert.equal(stats.users.accounts, 1, 'the registered account');
  assert.equal(stats.users.withData, 0, 'but it has never synced');
  assert.equal(stats.adherence, null, 'no doses yet means no percentage');
});

test('adherence counts missed doses, not just taken ones', async () => {
  // A formula of taken/(taken+skipped) reported a flattering 100% for data
  // that is really 86%.
  const login = await api('/api/patient/login', {
    method: 'POST',
    body: JSON.stringify({ email: 'a@t.test', password: 'Passw0rd!x' }),
  });
  const { token: patientToken } = await login.json();

  const doseLogs = [
    ...Array.from({ length: 18 }, (_, i) => ({ id: i + 1, status: 'taken' })),
    ...Array.from({ length: 3 }, (_, i) => ({ id: 100 + i, status: 'missed' })),
    { id: 200, status: 'pending' }, // due later; must not count either way
  ];
  await api('/api/patient/backup', {
    method: 'PUT',
    headers: { Authorization: `Bearer ${patientToken}` },
    body: JSON.stringify({
      data: {
        patient: { fullName: 'A' },
        prescriptions: [{ id: 1 }],
        medications: [{ id: 1 }, { id: 2 }],
        scheduleTimes: [{ id: 1 }],
        doseLogs,
        appointments: [],
      },
    }),
  });

  const adminTok = await adminToken();
  const stats = await (
    await api('/api/admin/stats', { headers: { Authorization: `Bearer ${adminTok}` } })
  ).json();

  assert.equal(stats.features.dosesTaken, 18);
  assert.equal(stats.features.dosesMissed, 3);
  assert.equal(stats.adherence, 86);
  assert.equal(stats.users.withData, 1, 'the sync registered');
  assert.equal(stats.features.accountsWithPrescription, 1);
});

test('the account listing masks addresses', async () => {
  const token = await adminToken();
  const { accounts } = await (
    await api('/api/admin/accounts', { headers: { Authorization: `Bearer ${token}` } })
  ).json();

  assert.equal(accounts.length, 1);
  assert.match(accounts[0].email, /^a\*\*\*@t\.test$/);
  assert.ok(!accounts[0].email.includes('a@t.test'), 'the full address never ships');
});

test('deleting refuses unless the full address is repeated', async () => {
  const token = await adminToken();
  const auth = { Authorization: `Bearer ${token}` };

  const wrong = await api('/api/admin/accounts/1', {
    method: 'DELETE',
    headers: auth,
    body: JSON.stringify({ email: 'someone@else.test' }),
  });
  assert.equal(wrong.status, 400);

  const still = await (await api('/api/admin/accounts', { headers: auth })).json();
  assert.equal(still.accounts.length, 1, 'nothing was deleted');

  const right = await api('/api/admin/accounts/1', {
    method: 'DELETE',
    headers: auth,
    body: JSON.stringify({ email: 'a@t.test' }),
  });
  assert.equal(right.status, 200);

  const after = await (await api('/api/admin/accounts', { headers: auth })).json();
  assert.equal(after.accounts.length, 0);

  // The backup must go with it, not linger as orphaned health data.
  const stats = await (await api('/api/admin/stats', { headers: auth })).json();
  assert.equal(stats.users.withData, 0);
});
