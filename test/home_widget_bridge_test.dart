import 'dart:convert';

import 'package:expense_tracker/models/ledger.dart';
import 'package:expense_tracker/services/home_widget_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pocket_ledger/home_widget');
  test('only authorized accounts are mirrored, with calculated balances; logout clears the mirror', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    const accounts = [
      BankAccount(
        id: 'current',
        name: 'Current',
        type: 'Current',
        openingCents: 10000,
        archived: false,
      ),
      BankAccount(
        id: 'old',
        name: 'Archived',
        type: 'Savings',
        openingCents: 30000,
        archived: true,
      ),
    ];
    final entries = [
      LedgerEntry(
        id: 'expense',
        kind: 'expense',
        accountId: 'current',
        targetId: null,
        amountCents: 9600,
        category: 'Bills',
        note: 'Insurance',
        date: DateTime(2026),
      ),
    ];
    HomeWidgetBridge.authorize('owner');
    await HomeWidgetBridge.syncAccounts('stranger', accounts, entries);
    expect(calls, isEmpty);
    await HomeWidgetBridge.syncAccounts('owner', accounts, entries);
    final payload = calls.single.arguments as Map;
    final mirrored = jsonDecode(payload['accounts'] as String) as List;
    expect(mirrored.length, 1);
    expect(mirrored.single['name'], 'Current');
    expect(mirrored.single['type'], 'Current');
    expect(mirrored.single['balance'], '€4.00');
    await HomeWidgetBridge.clearAccounts();
    expect((calls.last.arguments as Map)['authorized'], false);
    final count = calls.length;
    await HomeWidgetBridge.syncAccounts('owner', accounts, entries);
    expect(calls.length, count);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
