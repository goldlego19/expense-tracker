import 'package:expense_tracker/models/ledger.dart';
import 'package:expense_tracker/services/ledger_store.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:expense_tracker/widgets/editors.dart';
import 'package:expense_tracker/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingStore implements LedgerStore {
  String? savedKind;
  int? savedAmount;
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
    savedKind = kind;
    savedAmount = amountCents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const account = BankAccount(
    id: 'current',
    name: 'Current',
    type: 'Current',
    openingCents: 10000,
    archived: false,
  );
  for (final kind in ['expense', 'income']) {
    testWidgets('$kind shortcut saves exact cents and closes the editor', (
      tester,
    ) async {
      final store = RecordingStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: ledgerTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    editEntry(context, store, [account], null, kind),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '12.34');
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(store.savedKind, kind);
      expect(store.savedAmount, 1234);
      expect(find.text('Save transaction'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid transaction amount is not saved', (tester) async {
    final store = RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryEditor(store: store, accounts: const [account]),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '-1');
    await tester.tap(find.text('Save transaction'));
    await tester.pump();
    expect(store.savedAmount, isNull);
    expect(
      find.text('Enter a positive amount with up to 2 decimals'),
      findsOneWidget,
    );
  });
  testWidgets('appearance menu switches the whole app to light', (
    tester,
  ) async {
    final controller = ThemeController();
    await tester.pumpWidget(
      ThemeScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => MaterialApp(
            theme: ledgerTheme(Brightness.light),
            darkTheme: ledgerTheme(Brightness.dark),
            themeMode: controller.mode,
            home: Scaffold(
              appBar: AppBar(actions: const [AppearanceButton()]),
              body: Builder(
                builder: (context) => Text(Theme.of(context).brightness.name),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('dark'), findsOneWidget);
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.light);
    expect(find.text('light'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('reduced motion disables transitions', (tester) async {
    late Duration duration;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = motionDuration(context);
              return const Reveal(child: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(duration, Duration.zero);
    expect(find.text('Ready'), findsOneWidget);
  });
}
