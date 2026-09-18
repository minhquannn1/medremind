// node --test push.test.mjs  (run from server/)
import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.DOCTOR_DB_PATH = '/tmp/medoly-push-test.db';
const { localHhmm, dueMedications, tick } = await import('./push.js');

test('localHhmm follows the IANA zone and rejects garbage', () => {
  const noonUtc = new Date('2026-09-18T12:00:00Z');
  assert.equal(localHhmm('Asia/Ho_Chi_Minh', noonUtc), '19:00');
  assert.equal(localHhmm('UTC', noonUtc), '12:00');
  assert.equal(localHhmm('Not/AZone', noonUtc), null);
});

test('dueMedications matches active medications at the exact minute', () => {
  const backup = JSON.stringify({
    medications: [
      { id: 1, name: 'Metformin 500mg', status: 'active' },
      { id: 2, name: 'Old med', status: 'completed' },
      { id: 3, name: 'Amlodipin 5mg' }, // no status -> active
    ],
    scheduleTimes: [
      { medicationId: 1, time: '19:00' },
      { medicationId: 2, time: '19:00' }, // inactive med
      { medicationId: 3, time: '08:00' }, // wrong minute
    ],
  });
  const due = dueMedications(backup, '19:00');
  assert.deepEqual(due, [{ name: 'Metformin 500mg', time: '19:00' }]);
});

test('dueMedications survives a corrupt backup', () => {
  assert.deepEqual(dueMedications('not json', '08:00'), []);
  assert.deepEqual(dueMedications('{}', '08:00'), []);
});

test('tick never throws, even with an unreachable subscription', async () => {
  await assert.doesNotReject(tick(new Date()));
});
