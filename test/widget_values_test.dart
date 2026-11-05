import 'package:expense_tracker/models/home_widget_launch.dart';
import 'package:expense_tracker/services/appearance_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget launch preserves the chosen account and transaction type', () {
    final launch = HomeWidgetLaunch.parse({
      'requestId': 'one',
      'accountId': 'savings',
      'kind': 'income',
    });
    expect(launch?.accountId, 'savings');
    expect(launch?.kind, 'income');
    expect(launch?.requestId, 'one');
  });
  test('widget launch rejects unrecognized actions and malformed accounts', () {
    for (final value in [
      null,
      '',
      {'requestId': 'r', 'accountId': 'account', 'kind': 'transfer'},
      {'requestId': 'r', 'accountId': 'other/path', 'kind': 'expense'},
      {'requestId': '', 'accountId': 'account', 'kind': 'expense'},
      {'requestId': 'r', 'accountId': 12, 'kind': 'expense'},
    ]) {
      expect(HomeWidgetLaunch.parse(value), isNull);
    }
  });
  test('opaque custom RGB colours parse with or without a hash', () {
    expect(parseAccentHex('#7c3aed'), 0xff7c3aed);
    expect(parseAccentHex(' 60A5FA '), 0xff60a5fa);
    expect(accentHex(0xff60a5fa), '#60A5FA');
  });
  test('custom colours reject alpha, invalid characters and shorthand', () {
    for (final value in [
      '#fff',
      '#FF112233',
      '#zzzzzz',
      '',
      '##112233',
      '#1234567',
    ]) {
      expect(parseAccentHex(value), isNull);
    }
  });
}
