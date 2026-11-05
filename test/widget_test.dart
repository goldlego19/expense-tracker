import 'package:expense_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login explains accounts and offers Google sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Pocket Ledger'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Joint is an account label'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Startup failure displays recovery message', (tester) async {
    await tester.pumpWidget(
      ExpenseApp(startupError: Exception('configuration')),
    );
    expect(find.textContaining('Firebase could not start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
