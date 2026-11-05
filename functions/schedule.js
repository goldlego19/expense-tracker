'use strict';
const { DateTime } = require('luxon');
const ZONE = 'Europe/Malta';
const isoDate = value => DateTime.fromISO(value, { zone: ZONE });
const localDate = value => DateTime.fromJSDate(value, { zone: ZONE }).toISODate();
function validRule(rule) {
  return rule && typeof rule.name === 'string' && rule.name.trim().length > 0 && rule.name.length <= 60 &&
    typeof rule.accountId === 'string' && /^[^/]+$/.test(rule.accountId) &&
    Number.isSafeInteger(rule.amountCents) && rule.amountCents > 0 && rule.amountCents <= 99999999999 &&
    ['expense', 'income'].includes(rule.kind) && ['daily', 'weekly', 'monthly', 'yearly'].includes(rule.frequency) &&
    Number.isInteger(rule.dayOfMonth) && rule.dayOfMonth >= 1 && rule.dayOfMonth <= 31 &&
    Number.isInteger(rule.weekday) && rule.weekday >= 1 && rule.weekday <= 7 &&
    Number.isInteger(rule.month) && rule.month >= 1 && rule.month <= 12 &&
    typeof rule.category === 'string' && ['Food & groceries', 'Home', 'Transport', 'Shopping', 'Health', 'Entertainment', 'Bills', 'Salary', 'Other'].includes(rule.category) &&
    typeof rule.startDate === 'string' && typeof rule.endDate === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(rule.startDate) && /^\d{4}-\d{2}-\d{2}$/.test(rule.endDate) &&
    isoDate(rule.startDate).isValid && isoDate(rule.endDate).isValid && rule.startDate <= rule.endDate &&
    rule.startDate >= '2000-01-01' && rule.endDate <= '2100-12-31' && rule.timeZone === ZONE;
}
function isDue(rule, date) {
  if (rule.frequency === 'daily') return true;
  if (rule.frequency === 'weekly') return date.weekday === rule.weekday;
  const day = Math.min(rule.dayOfMonth, date.daysInMonth);
  return date.day === day && (rule.frequency === 'monthly' || date.month === rule.month);
}
function plan(rule, now, limit = 40) {
  if (!validRule(rule)) throw new Error('Invalid recurring rule');
  const today = localDate(now);
  const created = localDate(rule.createdAt.toDate());
  const effective = localDate(rule.effectiveFrom.toDate());
  const afterCursor = rule.processedThrough ? isoDate(rule.processedThrough).plus({ days: 1 }).toISODate() : '2000-01-01';
  const first = [rule.startDate, created, effective, afterCursor].sort().at(-1);
  const last = [rule.endDate, today].sort()[0];
  const dates = [];
  let cursor = rule.processedThrough ?? null;
  for (let date = isoDate(first); date.toISODate() <= last; date = date.plus({ days: 1 })) {
    const key = date.toISODate();
    if (isDue(rule, date)) dates.push(key);
    cursor = key;
    if (dates.length >= limit) break;
  }
  return { dates, processedThrough: cursor, today };
}
function occurrenceDate(date) { return isoDate(date).startOf('day').toJSDate(); }
module.exports = { ZONE, localDate, validRule, isDue, plan, occurrenceDate };
