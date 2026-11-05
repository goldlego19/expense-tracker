'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldPath } = require('firebase-admin/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { processRule } = require('./processor');
const { ZONE, occurrenceDate } = require('./schedule');
initializeApp();

exports.postRecurringTransactions = onSchedule({
  schedule: '15 * * * *', timeZone: ZONE, region: 'europe-west1',
  timeoutSeconds: 540, memory: '256MiB', maxInstances: 1, retryCount: 3,
}, async () => {
  const db = getFirestore();
  const now = new Date();
  let cursor;
  let posted = 0;
  let failed = 0;
  do {
    let query = db.collectionGroup('recurringRules').where('enabled', '==', true).orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      try {
        posted += await processRule(db, doc.ref, now, date => Timestamp.fromDate(date), occurrenceDate);
      } catch (error) {
        failed++;
        logger.error('Recurring rule failed', { path: doc.ref.path, error: String(error) });
      }
    }
    cursor = page.docs.at(-1);
    if (page.size < 100) break;
  } while (cursor);
  logger.info('Recurring transaction run complete', { posted, failed });
  if (failed) throw new Error(`${failed} recurring rules failed; retry required`);
});
