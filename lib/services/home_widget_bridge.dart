import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ledger.dart';
import '../models/home_widget_launch.dart';

/// Native Android launcher widgets use a small platform channel; no auth tokens
/// are copied to the widget's local preferences.
class HomeWidgetBridge {
  static const _channel = MethodChannel('pocket_ledger/home_widget');
  static final pendingLaunch = ValueNotifier<HomeWidgetLaunch?>(null);
  static final _seen = <String>[];
  static String? _authorizedUid;
  static bool _initialized = false;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static void authorize(String uid) {
    _authorizedUid = uid;
  }

  static void _receive(Object? data) {
    final launch = HomeWidgetLaunch.parse(data);
    if (launch == null || _seen.contains(launch.requestId)) return;
    _seen.add(launch.requestId);
    if (_seen.length > 32) _seen.removeAt(0);
    pendingLaunch.value = launch;
  }

  static Future<void> initialize() async {
    if (!supported) return;
    if (!_initialized) {
      _initialized = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'widgetLaunch') {
          _receive(call.arguments);
          final launch = HomeWidgetLaunch.parse(call.arguments);
          if (launch != null)
            await _channel.invokeMethod<void>('ackLaunch', {
              'requestId': launch.requestId,
            });
        }
      });
    }
    await consumeLaunch();
  }

  static Future<void> consumeLaunch() async {
    if (!supported) return;
    try {
      _receive(await _channel.invokeMethod<Object?>('consumeLaunch'));
    } on MissingPluginException {
      /* A full Android rebuild enables native widgets. */
    } on PlatformException {
      /* Normal app launch can still proceed. */
    }
  }

  static void complete(HomeWidgetLaunch launch) {
    if (pendingLaunch.value?.requestId == launch.requestId)
      pendingLaunch.value = null;
  }

  static Future<void> syncAccounts(
    String uid,
    List<BankAccount> accounts,
    List<LedgerEntry> entries,
  ) async {
    if (!supported || uid != _authorizedUid) return;
    await _channel.invokeMethod<void>('syncAccounts', {
      'authorized': true,
      'owner': uid,
      'accounts': jsonEncode(
        accounts
            .where((a) => !a.archived)
            .map(
              (a) => {
                'id': a.id,
                'name': a.name,
                'type': a.type,
                'balance': money(accountBalance(a, entries)),
              },
            )
            .toList(),
      ),
    });
  }

  static Future<void> clearAccounts() async {
    _authorizedUid = null;
    pendingLaunch.value = null;
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('syncAccounts', {
        'authorized': false,
        'accounts': '[]',
      });
    } on MissingPluginException {
      /* Previous app builds have no widget bridge. */
    } on PlatformException {
      /* Auth sign-out must not be blocked by a launcher. */
    }
  }

  static Future<void> syncAppearance({
    required int accent,
    required bool dark,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('syncAppearance', {
        'accent': accent,
        'dark': dark,
      });
    } on MissingPluginException {
      /* A full native rebuild is required. */
    } on PlatformException {
      /* The in-app appearance can still be applied. */
    }
  }
}
