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
  for (final option in ['Income', 'Expense', 'Transfer']) {
    testWidgets('widget picker opens $option with its account selected', (
      tester,
    ) async {
      final store = QuickRecordingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Widget +'),
                onPressed: () async {
                  final kind = await chooseTransactionKind(context);
                  if (kind != null && context.mounted) {
                    await editEntry(
                      context,
                      store,
                      accounts,
                      null,
                      kind,
                      'savings',
                    );
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Widget +'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      expect(fields[0].initialValue, option.toLowerCase());
      expect(fields[1].initialValue, 'savings');
      if (option == 'Transfer') {
        expect(find.text('From account'), findsOneWidget);
        expect(find.text('To account'), findsOneWidget);
        expect(fields[2].initialValue, isNull);
      }
      expect(store.account, isNull);
    });
  }
  testWidgets('dismissing the transaction picker does not create an entry', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Widget +'),
              onPressed: () async {
                chosen = await chooseTransactionKind(context);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Widget +'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(find.text('Add transaction'), findsNothing);
  });
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
