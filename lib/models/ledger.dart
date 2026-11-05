import 'package:cloud_firestore/cloud_firestore.dart';

const accountTypes = ['Current', 'Savings', 'Joint', 'Loan'];
const categories = [
  'Food & groceries',
  'Home',
  'Transport',
  'Shopping',
  'Health',
  'Entertainment',
  'Bills',
  'Salary',
  'Other',
];

/// Parse decimal input without floating point arithmetic. All amounts are EUR cents.
int? parseMoney(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^-?\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final negative = value.startsWith('-');
  final parts = value.replaceFirst('-', '').split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return normalizeCents(negative ? -cents : cents);
}

/// JavaScript preserves -0; Firestore serializes it as a double, not an int.
/// Always write a literal positive zero for zero-cent amounts.
int normalizeCents(int cents) => cents == 0 ? 0 : cents;

String money(int cents) =>
    '${cents < 0 ? '-' : ''}€${(cents.abs() ~/ 100).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
String moneyInput(int cents) =>
    '${cents < 0 ? '-' : ''}${cents.abs() ~/ 100}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.openingCents,
    required this.archived,
  });
  factory BankAccount.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return BankAccount(
      id: doc.id,
      name: data['name'] as String,
      type: data['type'] as String,
      openingCents: data['openingCents'] as int,
      archived: data['archived'] as bool,
    );
  }
  final String id;
  final String name;
  final String type;
  final int openingCents;
  final bool archived;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.targetId,
    required this.amountCents,
    required this.category,
    required this.note,
    required this.date,
  });
  factory LedgerEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return LedgerEntry(
      id: doc.id,
      kind: data['kind'] as String,
      accountId: data['accountId'] as String,
      targetId: data['targetId'] as String?,
      amountCents: data['amountCents'] as int,
      category: data['category'] as String,
      note: data['note'] as String,
      date: (data['date'] as Timestamp).toDate(),
    );
  }
  final String id;
  final String kind;
  final String accountId;
  final String? targetId;
  final int amountCents;
  final String category;
  final String note;
  final DateTime date;

  int effectOn(String id) {
    if (id == accountId) return kind == 'income' ? amountCents : -amountCents;
    if (kind == 'transfer' && id == targetId) return amountCents;
    return 0;
  }
}

int accountBalance(BankAccount account, Iterable<LedgerEntry> entries) =>
    entries.fold(
      account.openingCents,
      (sum, entry) => sum + entry.effectOn(account.id),
    );

int totalBalance(
  Iterable<BankAccount> accounts,
  Iterable<LedgerEntry> entries, {
  bool includeLoans = true,
}) => accounts
    .where((account) => includeLoans || account.type != 'Loan')
    .fold(0, (sum, account) => sum + accountBalance(account, entries));
