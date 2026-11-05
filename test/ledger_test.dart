import 'package:expense_tracker/models/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Zero debt stays positive zero for the Firestore web integer serializer', () {
    final zero = parseMoney('0.00')!;
    final loanCents = normalizeCents(-zero);
    expect(loanCents, 0);
    expect(1 / loanCents, double.infinity);
    expect(1 / parseMoney('-0.00')!, double.infinity);
    expect(normalizeCents(-12345), -12345);
    expect(normalizeCents(12345), 12345);
  });

  const current = BankAccount(
    id: 'current',
    name: 'Current',
    type: 'Current',
    openingCents: 100000,
    archived: false,
  );
  const loan = BankAccount(
    id: 'loan',
    name: 'Home loan',
    type: 'Loan',
    openingCents: -500000,
    archived: false,
  );
  LedgerEntry entry(String kind, int cents, {String? target}) => LedgerEntry(
    id: kind,
    kind: kind,
    accountId: 'current',
    targetId: target,
    amountCents: cents,
    category: 'Other',
    note: '',
    date: DateTime(2026),
  );
  test('Decimal amounts parse exactly as cents', () {
    expect(parseMoney('0.29'), 29);
    expect(parseMoney(' 123,4 '), 12340);
    expect(parseMoney('-15.01'), -1501);
    for (final invalid in ['1.234', 'NaN', '1e4', '', '1,000.00']) {
      expect(parseMoney(invalid), isNull);
    }
    expect(money(-123456), '-€1,234.56');
  });
  test('Totals include loan debt only when requested, and keep archived balances', () {
    const savings = BankAccount(id: 'savings', name: 'Savings', type: 'Savings', openingCents: 20000, archived: true);
    final accounts = [current, loan, savings];
    expect(totalBalance(accounts, []), -380000);
    expect(totalBalance(accounts, [], includeLoans: false), 120000);
    final repayment = entry('transfer', 25000, target: 'loan');
    expect(totalBalance(accounts, [repayment]), -380000);
    expect(totalBalance(accounts, [repayment], includeLoans: false), 95000);
    expect(totalBalance([], [], includeLoans: false), 0);
  });
  test('Income and expenses update an opening balance', () {
    expect(
      accountBalance(current, [entry('income', 50000), entry('expense', 2999)]),
      147001,
    );
  });
  test('Loan repayment transfers conserve net worth', () {
    final repayment = entry('transfer', 25000, target: 'loan');
    expect(accountBalance(current, [repayment]), 75000);
    expect(accountBalance(loan, [repayment]), -475000);
    expect(
      accountBalance(current, [repayment]) + accountBalance(loan, [repayment]),
      current.openingCents + loan.openingCents,
    );
  });
  test('Deleting an entry by removing it restores balances', () {
    final entries = [entry('expense', 1000)];
    expect(accountBalance(current, entries), 99000);
    entries.clear();
    expect(accountBalance(current, entries), 100000);
  });
}
