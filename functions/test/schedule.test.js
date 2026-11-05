'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { DateTime } = require('luxon');
const { plan, occurrenceDate, validRule, ZONE } = require('../schedule');
const timestamp = value => ({ toDate: () => new Date(value) });
const makeRule = overrides => ({ name: 'Insurance', accountId: 'current', amountCents: 9600, kind: 'expense', category: 'Bills', frequency: 'monthly', dayOfMonth: 15, weekday: 1, month: 1, startDate: '2026-11-05', endDate: '2028-10-31', timeZone: ZONE, createdAt: timestamp('2026-11-05T09:00:00Z'), effectiveFrom: timestamp('2026-11-05T09:00:00Z'), processedThrough: null, enabled: true, ...overrides });

test('€96 on every 15th through October 2028 includes the final payment', () => {
  const result = plan(makeRule(), new Date('2028-11-01T10:00:00Z'));
  assert.equal(result.dates.length, 24);
  assert.equal(result.dates[0], '2026-11-15');
  assert.equal(result.dates.at(-1), '2028-10-15');
  assert.equal(result.processedThrough, '2028-10-31');
  assert.equal(result.dates.length * 9600, 230400);
});
test('start and end are inclusive, with no payment outside the range', () => {
  assert.deepEqual(plan(makeRule({ startDate: '2026-11-15', endDate: '2026-11-15' }), new Date('2027-01-01')).dates, ['2026-11-15']);
  assert.deepEqual(plan(makeRule({ endDate: '2026-11-14' }), new Date('2027-01-01')).dates, []);
  assert.deepEqual(plan(makeRule({ startDate: '2026-11-16' }), new Date('2026-11-20')).dates, []);
});
test('days 29–31 clamp to month end without drifting in subsequent months', () => {
  const result = plan(makeRule({ dayOfMonth: 31, startDate: '2028-01-01', endDate: '2028-03-31' }), new Date('2028-04-01'));
  assert.deepEqual(result.dates, ['2028-01-31', '2028-02-29', '2028-03-31']);
});
test('weekly and daily schedules honor payment weekday and inclusive dates', () => {
  assert.deepEqual(plan(makeRule({ frequency: 'weekly', weekday: 1, endDate: '2026-11-16' }), new Date('2026-11-17')).dates, ['2026-11-09', '2026-11-16']);
  assert.deepEqual(plan(makeRule({ frequency: 'daily', endDate: '2026-11-07' }), new Date('2026-11-08')).dates, ['2026-11-05', '2026-11-06', '2026-11-07']);
});
test('yearly leap date uses February end in non-leap years', () => {
  assert.deepEqual(plan(makeRule({ frequency: 'yearly', month: 2, dayOfMonth: 29 }), new Date('2028-11-01')).dates, ['2027-02-28', '2028-02-29']);
});
test('Malta midnight and DST are used for occurrence timestamps', () => {
  assert.equal(occurrenceDate('2027-01-15').toISOString(), '2027-01-14T23:00:00.000Z');
  assert.equal(occurrenceDate('2027-07-15').toISOString(), '2027-07-14T22:00:00.000Z');
  const r = makeRule({ dayOfMonth: 15 });
  assert.deepEqual(plan(r, new Date('2026-11-14T23:20:00Z')).dates, ['2026-11-15']);
});
test('new rules and edited/resumed rules do not backfill before their effective date', () => {
  const r = makeRule({ startDate: '2020-01-01', effectiveFrom: timestamp('2027-01-20T12:00:00Z') });
  assert.deepEqual(plan(r, new Date('2027-03-20')).dates, ['2027-02-15', '2027-03-15']);
});
test('missed runs catch up in bounded chunks without losing a date', () => {
  const r = makeRule({ frequency: 'daily', endDate: '2027-02-01' });
  const first = plan(r, new Date('2027-03-01'));
  assert.equal(first.dates.length, 40);
  const second = plan({ ...r, processedThrough: first.processedThrough }, new Date('2027-03-01'));
  assert.equal(second.dates[0], DateTime.fromISO(first.processedThrough).plus({ days: 1 }).toISODate());
  assert.equal(new Set([...first.dates, ...second.dates]).size, 80);
});
test('malformed schedules fail closed', () => {
  assert.equal(validRule(makeRule({ startDate: '2027-02-30' })), false);
  assert.equal(validRule(makeRule({ amountCents: 96.5 })), false);
  assert.equal(validRule(makeRule({ accountId: 'other/path' })), false);
  assert.throws(() => plan(makeRule({ frequency: 'unknown' }), new Date()));
});
module.exports = { makeRule };
