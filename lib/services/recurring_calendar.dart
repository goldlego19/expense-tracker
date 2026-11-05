import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;
tz.Location get maltaZone {
  if (!_initialized) {
    data.initializeTimeZones();
    _initialized = true;
  }
  return tz.getLocation('Europe/Malta');
}

String maltaDate(DateTime instant) {
  final d = tz.TZDateTime.from(instant, maltaZone);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime occurrenceInstant(String date) {
  final d = DateTime.parse(date);
  return tz.TZDateTime(maltaZone, d.year, d.month, d.day).toUtc();
}

class RecurringPlan {
  const RecurringPlan({required this.dates, required this.processedThrough});
  final List<String> dates;
  final String? processedThrough;
}

String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);
bool _calendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && _dayKey(parsed) == value;
}

RecurringPlan planRecurring({
  required String frequency,
  required int dayOfMonth,
  required int weekday,
  required int month,
  required String startDate,
  required String endDate,
  required DateTime createdAt,
  required DateTime effectiveFrom,
  required DateTime now,
  String? processedThrough,
  int limit = 20,
}) {
  if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency) ||
      dayOfMonth < 1 ||
      dayOfMonth > 31 ||
      weekday < 1 ||
      weekday > 7 ||
      month < 1 ||
      month > 12 ||
      !_calendarDate(startDate) ||
      !_calendarDate(endDate) ||
      startDate.compareTo(endDate) > 0 ||
      startDate.compareTo('2000-01-01') < 0 ||
      endDate.compareTo('2100-12-31') > 0 ||
      (processedThrough != null && !_calendarDate(processedThrough)) ||
      limit < 1) {
    throw const FormatException('Invalid recurring schedule');
  }
  final bounds = [
    startDate,
    maltaDate(createdAt),
    maltaDate(effectiveFrom),
    if (processedThrough != null)
      _dayKey(
        DateTime.parse('${processedThrough}T00:00:00Z')
            .add(const Duration(days: 1)),
      ),
  ];
  bounds.sort();
  final today = maltaDate(now);
  final last = endDate.compareTo(today) < 0 ? endDate : today;
  final dates = <String>[];
  var cursor = processedThrough;
  for (
    var d = DateTime.parse('${bounds.last}T00:00:00Z');
    _dayKey(d).compareTo(last) <= 0;
    d = d.add(const Duration(days: 1))
  ) {
    final daysInMonth = DateTime.utc(d.year, d.month + 1, 0).day;
    final paymentDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;
    final due = switch (frequency) {
      'daily' => true,
      'weekly' => d.weekday == weekday,
      'monthly' => d.day == paymentDay,
      _ => d.month == month && d.day == paymentDay,
    };
    cursor = _dayKey(d);
    if (due) dates.add(cursor);
    if (dates.length == limit) break;
  }
  return RecurringPlan(dates: dates, processedThrough: cursor);
}
