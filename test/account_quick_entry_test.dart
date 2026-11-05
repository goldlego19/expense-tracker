import 'package:expense_tracker/models/ledger.dart';
import 'package:expense_tracker/services/ledger_store.dart';
import 'package:expense_tracker/widgets/editors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class QuickRecordingStore implements LedgerStore {
  String? account;
  int? amount;
  @override
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
    account = accountId;
    amount = amountCents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const accounts = [
    BankAccount(
      id: 'current',
      name: 'Current',
      type: 'Current',
      openingCents: 0,
      archived: false,
    ),
    BankAccount(
      id: 'savings',
      name: 'Savings',
      type: 'Savings',
      openingCents: 0,
      archived: false,
    ),
  ];
  testWidgets(
    'account-specific entry opens with the requested account selected',
    (tester) async {
      final store = QuickRecordingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editEntry(
                  context,
                  store,
                  accounts,
                  null,
                  'expense',
                  'savings',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '25.00');
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(store.account, 'savings');
      expect(store.amount, 2500);
    },
  );
}
