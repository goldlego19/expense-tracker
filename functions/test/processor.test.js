'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { processRule } = require('../processor');
const { occurrenceDate, ZONE } = require('../schedule');
const stamp = value => ({ toDate: () => new Date(value) });
// A serialized, atomic Firestore test double lets us exercise the actual processor,
// including repeat runs and rollbacks, without touching a production project.
function fixture() {
  const docs = new Map();
  function ref(path) {
    const pieces = path.split('/');
    return { path, id: pieces.at(-1), get parent() { return collection(pieces.slice(0, -1).join('/')); }, collection: name => collection(`${path}/${name}`) };
  }
  function collection(path) { return { id: path.split('/').at(-1), parent: ref(path.split('/').slice(0, -1).join('/')), doc: id => ref(`${path}/${id}`) }; }
  let queue = Promise.resolve();
  let failCommit = false;
  const db = { runTransaction: fn => {
    const promise = queue.then(async () => {
      const writes = [];
      const tx = {
        get: async ref => { const value = docs.get(ref.path); return { exists: value !== undefined, data: () => value }; },
        create: (ref, data) => writes.push(() => { if (docs.has(ref.path)) throw Error('already exists'); docs.set(ref.path, data); }),
        update: (ref, data) => writes.push(() => { if (!docs.has(ref.path)) throw Error('not found'); docs.set(ref.path, { ...docs.get(ref.path), ...data }); }),
      };
      const result = await fn(tx);
      if (failCommit) { failCommit = false; throw Error('simulated commit failure'); }
      const before = new Map(docs);
      try { writes.forEach(write => write()); } catch (error) { docs.clear(); before.forEach((value, key) => docs.set(key, value)); throw error; }
      return result;
    });
    queue = promise.catch(() => {});
    return promise;
  } };
  const ruleRef = ref('users/u/recurringRules/r');
  docs.set(ruleRef.path, { name: 'Insurance', accountId: 'current', amountCents: 9600, kind: 'expense', category: 'Bills', frequency: 'monthly', dayOfMonth: 15, weekday: 1, month: 1, startDate: '2026-11-05', endDate: '2028-10-31', timeZone: ZONE, createdAt: stamp('2026-11-05T09:00:00Z'), effectiveFrom: stamp('2026-11-05T09:00:00Z'), processedThrough: null, enabled: true });
  docs.set('users/u/accounts/current', { archived: false });
  return { docs, ruleRef, run: now => processRule(db, ruleRef, new Date(now), value => stamp(value), occurrenceDate), failNext: () => { failCommit = true; } };
}
test('repeated and overlapping runs create a single transaction for a due date', async () => {
  const f = fixture();
  await Promise.all([f.run('2026-11-15T10:00:00Z'), f.run('2026-11-15T10:00:00Z')]);
  assert.equal([...f.docs.keys()].filter(key => key.includes('/transactions/')).length, 1);
  const entry = f.docs.get('users/u/transactions/recurring_r_2026-11-15');
  assert.equal(entry.amountCents, 9600);
  assert.equal(entry.note, 'Insurance');
  assert.equal(entry.accountId, 'current');
});
test('receipts prevent recreating a deleted entry even if the cursor is reset', async () => {
  const f = fixture();
  await f.run('2026-11-15T10:00:00Z');
  f.docs.delete('users/u/transactions/recurring_r_2026-11-15');
  f.docs.get(f.ruleRef.path).processedThrough = null;
  await f.run('2026-11-15T10:00:00Z');
  assert.equal([...f.docs.keys()].filter(key => key.includes('/transactions/')).length, 0);
});
test('failed commits do not advance the cursor or partially post payments', async () => {
  const f = fixture(); f.failNext();
  await assert.rejects(() => f.run('2026-11-15T10:00:00Z'));
  assert.equal(f.docs.get(f.ruleRef.path).processedThrough, null);
  assert.equal([...f.docs.keys()].filter(key => key.includes('/transactions/')).length, 0);
  await f.run('2026-11-15T10:00:00Z');
  assert.equal([...f.docs.keys()].filter(key => key.includes('/transactions/')).length, 1);
});
test('paused, deleted and archived-account rules do not post transactions', async () => {
  for (const scenario of ['paused', 'deleted', 'archived']) {
    const f = fixture();
    if (scenario === 'paused') f.docs.get(f.ruleRef.path).enabled = false;
    if (scenario === 'deleted') f.docs.delete(f.ruleRef.path);
    if (scenario === 'archived') f.docs.get('users/u/accounts/current').archived = true;
    assert.equal(await f.run('2026-11-15T10:00:00Z'), 0);
    assert.equal([...f.docs.keys()].filter(key => key.includes('/transactions/')).length, 0);
  }
});
test('restoring an archived account skips missed payment dates', async () => {
  const f = fixture();
  f.docs.get('users/u/accounts/current').archived = true;
  await f.run('2026-11-15T10:00:00Z');
  f.docs.get('users/u/accounts/current').archived = false;
  await f.run('2026-12-15T10:00:00Z');
  assert.equal(f.docs.has('users/u/transactions/recurring_r_2026-11-15'), false);
  assert.equal(f.docs.has('users/u/transactions/recurring_r_2026-12-15'), true);
});
