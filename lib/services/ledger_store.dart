import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ledger.dart';
import '../models/recurring_rule.dart';

class LedgerStore {
  LedgerStore(String uid)
    : _user = FirebaseFirestore.instance.collection('users').doc(uid);
  final DocumentReference<Map<String, dynamic>> _user;
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _user.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _entries =>
      _user.collection('transactions');
  Stream<List<BankAccount>> watchAccounts() => _accounts.snapshots().map(
    (s) => s.docs.map(BankAccount.fromDoc).toList()..sort(compareAccountOrder),
  );
  Stream<List<LedgerEntry>> watchEntries() => _entries.snapshots().map(
    (s) =>
        s.docs.map(LedgerEntry.fromDoc).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
  );

  Future<void> saveAccount({
    String? id,
    required String name,
    required String type,
    required int openingCents,
  }) async {
    final doc = id == null ? _accounts.doc() : _accounts.doc(id);
    await doc.set({
      'name': name.trim(),
      'type': type,
      'openingCents': normalizeCents(openingCents),
      'currency': 'EUR',
      if (id == null) 'archived': false,
    }, SetOptions(merge: true));
  }

  Future<void> reorderAccounts(List<String> ids) async {
    if (ids.length > 500 || ids.toSet().length != ids.length) {
      throw ArgumentError(
        'Account order must contain at most 500 unique accounts.',
      );
    }
    final batch = FirebaseFirestore.instance.batch();
    for (var index = 0; index < ids.length; index++) {
      batch.update(_accounts.doc(ids[index]), {'sortOrder': index});
    }
    await batch.commit();
  }

  Future<void> archiveAccount(BankAccount account) =>
      _accounts.doc(account.id).update({'archived': !account.archived});
  Future<void> saveEntry({
    String? id,
    required String kind,
    required String accountId,
    String? targetId,
    required int amountCents,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    final doc = id == null ? _entries.doc() : _entries.doc(id);
    await doc.set({
      'kind': kind,
      'accountId': accountId,
      'targetId': kind == 'transfer' ? targetId : null,
      'amountCents': amountCents,
      'category': category,
      'note': note.trim(),
      'date': Timestamp.fromDate(date),
    });
  }

  CollectionReference<Map<String, dynamic>> get _rules =>
      _user.collection('recurringRules');
  Stream<List<RecurringRule>> watchRecurringRules() => _rules.snapshots().map(
    (snapshot) =>
        snapshot.docs.map(RecurringRule.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );
  Future<void> saveRecurringRule({
    String? id,
    required String name,
    required String accountId,
    required String kind,
    required int amountCents,
    required String category,
    required String frequency,
    required int dayOfMonth,
    required int weekday,
    required int month,
    required String startDate,
    required String endDate,
  }) async {
    await (id == null ? _rules.doc() : _rules.doc(id)).set({
      'name': name.trim(),
      'accountId': accountId,
      'kind': kind,
      'amountCents': amountCents,
      'category': category,
      'frequency': frequency,
      'dayOfMonth': dayOfMonth,
      'weekday': weekday,
      'month': month,
      'startDate': startDate,
      'endDate': endDate,
      'timeZone': 'Europe/Malta',
      'effectiveFrom': FieldValue.serverTimestamp(),
      if (id == null) ...{
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'processedThrough': null,
        'lastRunAt': null,
        'lastError': null,
      },
    }, SetOptions(merge: true));
  }

  Future<void> setRecurringEnabled(RecurringRule rule, bool enabled) =>
      _rules.doc(rule.id).update({
        'enabled': enabled,
        if (enabled) 'effectiveFrom': FieldValue.serverTimestamp(),
      });
  Future<void> deleteRecurringRule(String id) => _rules.doc(id).delete();

  Future<void> deleteEntry(String id) => _entries.doc(id).delete();
}
