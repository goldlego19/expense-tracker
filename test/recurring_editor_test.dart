import 'package:expense_tracker/models/ledger.dart';
import 'package:expense_tracker/models/recurring_rule.dart';
import 'package:expense_tracker/services/ledger_store.dart';
import 'package:expense_tracker/widgets/recurring_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RuleRecordingStore implements LedgerStore {
  Map<String, Object?>? saved;
  @override
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
    saved = {
      'name': name,
      'accountId': accountId,
      'amountCents': amountCents,
      'frequency': frequency,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const account = BankAccount(
    id: 'current',
    name: 'BOV Current',
    type: 'Current',
    openingCents: 0,
    archived: false,
  );
  const example = RecurringRule(
    id: 'insurance',
    name: 'Insurance',
    accountId: 'current',
    kind: 'expense',
    amountCents: 9600,
    category: 'Bills',
    frequency: 'monthly',
    dayOfMonth: 15,
    weekday: 1,
    month: 1,
    startDate: '2026-11-05',
    endDate: '2028-10-31',
    enabled: true,
  );
  testWidgets(
    'monthly rule editor saves the requested €96 schedule and account',
    (tester) async {
      final store = RuleRecordingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    editRecurringRule(context, store, [account], example),
                child: const Text('Open rule'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open rule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save rule'));
      await tester.pumpAndSettle();
      expect(store.saved, {
        'name': 'Insurance',
        'accountId': 'current',
        'amountCents': 9600,
        'frequency': 'monthly',
        'dayOfMonth': 15,
        'startDate': '2026-11-05',
        'endDate': '2028-10-31',
      });
      expect(find.text('Save rule'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('zero recurring amounts are rejected before saving', (
    tester,
  ) async {
    final store = RuleRecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringEditor(
            store: store,
            accounts: const [account],
            rule: example,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(1), '0.00');
    await tester.tap(find.text('Save rule'));
    await tester.pump();
    expect(store.saved, isNull);
    expect(
      find.text('Enter a positive amount with up to 2 decimals'),
      findsOneWidget,
    );
  });
}
