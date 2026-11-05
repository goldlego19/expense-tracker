import 'package:cloud_firestore/cloud_firestore.dart';

const frequencies = ['daily', 'weekly', 'monthly', 'yearly'];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.name,
    required this.accountId,
    required this.kind,
    required this.amountCents,
    required this.category,
    required this.frequency,
    required this.dayOfMonth,
    required this.weekday,
    required this.month,
    required this.startDate,
    required this.endDate,
    required this.enabled,
    this.lastError,
    this.processedThrough,
    this.lastRunAt,
  });
  factory RecurringRule.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return RecurringRule(
      id: doc.id,
      name: d['name'] as String,
      accountId: d['accountId'] as String,
      kind: d['kind'] as String,
      amountCents: d['amountCents'] as int,
      category: d['category'] as String,
      frequency: d['frequency'] as String,
      dayOfMonth: d['dayOfMonth'] as int,
      weekday: d['weekday'] as int,
      month: d['month'] as int,
      startDate: d['startDate'] as String,
      endDate: d['endDate'] as String,
      enabled: d['enabled'] as bool,
      lastError: d['lastError'] as String?,
      processedThrough: d['processedThrough'] as String?,
      lastRunAt: (d['lastRunAt'] as Timestamp?)?.toDate(),
    );
  }
  final String id,
      name,
      accountId,
      kind,
      category,
      frequency,
      startDate,
      endDate;
  final int amountCents, dayOfMonth, weekday, month;
  final bool enabled;
  final String? lastError, processedThrough;
  final DateTime? lastRunAt;
  String get scheduleLabel => switch (frequency) {
    'daily' => 'Every day',
    'weekly' => 'Every ${weekdayNames[weekday - 1]}',
    'yearly' => 'Every year on ${monthNames[month - 1]} $dayOfMonth',
    _ => 'Every month on day $dayOfMonth',
  };
}
