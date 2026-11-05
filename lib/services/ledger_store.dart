import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ledger.dart';

class LedgerStore {
  LedgerStore(String uid)
    : _user = FirebaseFirestore.instance.collection('users').doc(uid);
  final DocumentReference<Map<String, dynamic>> _user;
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _user.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _entries =>
      _user.collection('transactions');
  Stream<List<BankAccount>> watchAccounts() => _accounts.snapshots().map(
    (s) =>
        s.docs.map(BankAccount.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
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

  Future<void> deleteEntry(String id) => _entries.doc(id).delete();
}
