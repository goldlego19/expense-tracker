'use strict';
const { plan, localDate, validRule } = require('./schedule');

// One atomic transaction reads the current config/account/receipts, then posts
// entries and advances the cursor together. Retries and overlapping jobs are safe.
async function processRule(db, ref, now, timestampFromDate, occurrenceDate) {
  return db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return 0;
    const rule = snapshot.data();
    if (!rule.enabled) return 0;
    const user = ref.parent.parent;
    if (!user || user.parent.id !== 'users') return 0;
    if (!validRule(rule) || !rule.createdAt?.toDate || !rule.effectiveFrom?.toDate) {
      tx.update(ref, { lastError: 'Invalid rule. Edit and save its settings.', lastRunAt: timestampFromDate(now) });
      return 0;
    }
    const account = await tx.get(user.collection('accounts').doc(rule.accountId));
    if (!account.exists || account.data().archived) {
      tx.update(ref, { processedThrough: localDate(now), lastError: 'Account unavailable or archived. Skipped payments are not backfilled.', lastRunAt: timestampFromDate(now) });
      return 0;
    }
    const schedule = plan(rule, now);
    const refs = schedule.dates.map(date => ({
      date,
      receipt: ref.collection('occurrences').doc(date),
      entry: user.collection('transactions').doc(`recurring_${ref.id}_${date}`),
    }));
    // All reads must precede all writes in a Firestore transaction.
    const reads = [];
    for (const item of refs) reads.push({ ...item, receiptSnap: await tx.get(item.receipt), entrySnap: await tx.get(item.entry) });
    let posted = 0;
    for (const item of reads) {
      if (item.receiptSnap.exists) continue;
      if (!item.entrySnap.exists) {
        tx.create(item.entry, {
          kind: rule.kind, accountId: rule.accountId, targetId: null,
          amountCents: rule.amountCents, category: rule.category,
          note: rule.name, date: timestampFromDate(occurrenceDate(item.date)),
        });
        posted++;
      }
      // Keep receipts even if the user later deletes the generated entry.
      tx.create(item.receipt, { transactionId: item.entry.id, date: item.date, postedAt: timestampFromDate(now) });
    }
    tx.update(ref, { processedThrough: schedule.processedThrough, lastRunAt: timestampFromDate(now), lastError: null });
    return posted;
  });
}
module.exports = { processRule };
