import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ledger.dart';
import 'auth_service.dart';
import 'recurring_calendar.dart';

/// Runs only while this user's app session is active. Every payment and receipt
/// uses a Firestore transaction, so two devices can safely process the same rule.
class ClientRecurringScheduler extends ChangeNotifier {
  ClientRecurringScheduler(String uid, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance {
    _user = _db.collection('users').doc(uid);
  }
  final FirebaseFirestore _db;
  late final DocumentReference<Map<String, dynamic>> _user;
  Timer? _timer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _disposed = false;
  bool _active = true;
  bool _running = false;
  bool _repeat = false;
  String? _signature;
  String? error;
  DateTime? lastChecked;
  int lastPosted = 0;
  bool get running => _running;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    const fields = [
      'name',
      'accountId',
      'kind',
      'amountCents',
      'category',
      'frequency',
      'dayOfMonth',
      'weekday',
      'month',
      'startDate',
      'endDate',
      'enabled',
      'effectiveFrom',
    ];
    _subscription = _user
        .collection('recurringRules')
        .snapshots()
        .listen(
          (snapshot) {
            // Ignore unresolved server timestamps and our own progress/status writes.
            if (snapshot.metadata.hasPendingWrites) return;
            final docs = snapshot.docs.toList()
              ..sort((a, b) => a.id.compareTo(b.id));
            final signature = jsonEncode(
              docs
                  .map(
                    (doc) => [
                      doc.id,
                      ...fields.map((field) => doc.data()[field].toString()),
                    ],
                  )
                  .toList(),
            );
            if (_signature != signature) {
              _signature = signature;
              unawaited(check());
            }
          },
          onError: (Object failure) {
            error = friendlyError(failure);
            _notify();
          },
        );
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(check()),
    );
    unawaited(check());
  }

  Future<void> check() async {
    if (_disposed || !_active) return;
    if (_running) {
      _repeat = true;
      return;
    }
    _running = true;
    error = null;
    _notify();
    try {
      do {
        _repeat = false;
        final rules = await _user
            .collection('recurringRules')
            .where('enabled', isEqualTo: true)
            .get(const GetOptions(source: Source.server));
        if (rules.docs.isEmpty || _disposed || !_active) {
          lastPosted = 0;
          lastChecked = DateTime.now();
          break;
        }
        // Use Firebase time rather than trusting an incorrectly set device clock.
        final clock = _user.collection('recurringClock').doc('current');
        await clock.set({'at': FieldValue.serverTimestamp()});
        final clockData = await clock.get(
          const GetOptions(source: Source.server),
        );
        final now = (clockData.data()!['at'] as Timestamp).toDate();
        var posted = 0;
        for (final doc in rules.docs) {
          if (_disposed || !_active) break;
          // Bound a pass; large backlogs continue on the next pass/timer/resume.
          for (var i = 0; i < 100 && !_disposed && _active; i++) {
            final result = await _processOne(doc.reference, now);
            posted += result.posted;
            if (!result.more) break;
          }
        }
        lastPosted = posted;
        lastChecked = now;
      } while (_repeat && !_disposed && _active);
    } catch (failure) {
      error =
          '${friendlyError(failure)} Recurring payments will retry when online or on the next app check.';
    } finally {
      _running = false;
      _notify();
    }
  }

  Future<({int posted, bool more})> _processOne(
    DocumentReference<Map<String, dynamic>> ref,
    DateTime now,
  ) => _db.runTransaction((tx) async {
    final snapshot = await tx.get(ref);
    final d = snapshot.data();
    if (d == null || d['enabled'] != true) return (posted: 0, more: false);
    final accountRef = _user
        .collection('accounts')
        .doc(d['accountId'] as String);
    final account = await tx.get(accountRef);
    if (!account.exists || account.data()?['archived'] != false) {
      tx.update(ref, {
        'processedThrough': maltaDate(now),
        'lastRunAt': FieldValue.serverTimestamp(),
        'lastError': 'Account unavailable or archived. Skipped payments are not backfilled.',
      });
      return (posted: 0, more: false);
    }
    RecurringPlan plan;
    try {
      final amount = d['amountCents'];
      if (amount is! int ||
          amount <= 0 ||
          amount > 99999999999 ||
          !['income', 'expense'].contains(d['kind']) ||
          !categories.contains(d['category']) ||
          d['timeZone'] != 'Europe/Malta')
        throw const FormatException();
      plan = planRecurring(
        frequency: d['frequency'] as String,
        dayOfMonth: d['dayOfMonth'] as int,
        weekday: d['weekday'] as int,
        month: d['month'] as int,
        startDate: d['startDate'] as String,
        endDate: d['endDate'] as String,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
        effectiveFrom: (d['effectiveFrom'] as Timestamp).toDate(),
        now: now,
        processedThrough: d['processedThrough'] as String?,
        limit: 1,
      );
    } catch (_) {
      tx.update(ref, {
        'lastRunAt': FieldValue.serverTimestamp(),
        'lastError': 'Invalid rule. Edit and save its settings.',
      });
      return (posted: 0, more: false);
    }
    if (plan.dates.isEmpty) {
      tx.update(ref, {
        'processedThrough': plan.processedThrough,
        'lastRunAt': FieldValue.serverTimestamp(),
        'lastError': null,
      });
      return (posted: 0, more: false);
    }
    final date = plan.dates.single;
    final receiptRef = ref.collection('occurrences').doc(date);
    final entryRef = _user
        .collection('transactions')
        .doc('recurring_${ref.id}_$date');
    final receipt = await tx.get(receiptRef);
    final entry = await tx.get(entryRef);
    var posted = 0;
    if (!receipt.exists) {
      if (!entry.exists) {
        tx.set(entryRef, {
          'kind': d['kind'],
          'accountId': d['accountId'],
          'targetId': null,
          'amountCents': d['amountCents'],
          'category': d['category'],
          'note': d['name'],
          'date': Timestamp.fromDate(occurrenceInstant(date)),
        });
        posted = 1;
      }
      tx.set(receiptRef, {
        'transactionId': entryRef.id,
        'date': date,
        'postedAt': FieldValue.serverTimestamp(),
      });
    }
    tx.update(ref, {
      'processedThrough': date,
      'lastRunAt': FieldValue.serverTimestamp(),
      'lastError': null,
    });
    return (posted: posted, more: true);
  });
  void pause() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_disposed) return;
    _active = true;
    _timer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(check()),
    );
    unawaited(check());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
