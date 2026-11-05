import 'package:expense_tracker/services/recurring_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecurringPlan plan({
    String frequency = 'monthly',
    int day = 15,
    int weekday = 1,
    int month = 1,
    String start = '2026-11-05',
    String end = '2028-10-31',
    String? cursor,
    String effective = '2026-11-05T09:00:00Z',
    String now = '2028-11-01T10:00:00Z',
    int limit = 100,
  }) => planRecurring(
    frequency: frequency,
    dayOfMonth: day,
    weekday: weekday,
    month: month,
    startDate: start,
    endDate: end,
    createdAt: DateTime.parse('2026-11-05T09:00:00Z'),
    effectiveFrom: DateTime.parse(effective),
    now: DateTime.parse(now),
    processedThrough: cursor,
    limit: limit,
  );
  test('monthly €96 example ends with the October 2028 payment', () {
    final result = plan();
    expect(result.dates.length, 24);
    expect(result.dates.first, '2026-11-15');
    expect(result.dates.last, '2028-10-15');
    expect(result.processedThrough, '2028-10-31');
  });
  test('start and end dates are inclusive', () {
    expect(plan(start: '2026-11-15', end: '2026-11-15').dates, ['2026-11-15']);
    expect(plan(end: '2026-11-14').dates, isEmpty);
    expect(
      plan(start: '2026-11-16', now: '2026-11-20T10:00:00Z').dates,
      isEmpty,
    );
  });
  test('monthly 31st clamps to leap February and does not drift', () {
    expect(plan(day: 31, start: '2028-01-01', end: '2028-03-31').dates, [
      '2028-01-31',
      '2028-02-29',
      '2028-03-31',
    ]);
  });
  test('weekly, daily and yearly frequencies use their chosen days', () {
    expect(plan(frequency: 'weekly', end: '2026-11-16').dates, [
      '2026-11-09',
      '2026-11-16',
    ]);
    expect(plan(frequency: 'daily', end: '2026-11-07').dates, [
      '2026-11-05',
      '2026-11-06',
      '2026-11-07',
    ]);
    expect(plan(frequency: 'yearly', month: 2, day: 29).dates, [
      '2027-02-28',
      '2028-02-29',
    ]);
  });
  test('Malta calendar and UTC timestamps remain correct across DST', () {
    expect(
      occurrenceInstant('2027-01-15').toIso8601String(),
      '2027-01-14T23:00:00.000Z',
    );
    expect(
      occurrenceInstant('2027-07-15').toIso8601String(),
      '2027-07-14T22:00:00.000Z',
    );
    expect(plan(now: '2026-11-14T23:20:00Z').dates, ['2026-11-15']);
  });
  test(
    'new rules and resumed rules skip dates before they became effective',
    () {
      expect(
        plan(
          start: '2020-01-01',
          effective: '2027-01-20T12:00:00Z',
          now: '2027-03-20T10:00:00Z',
        ).dates,
        ['2027-02-15', '2027-03-15'],
      );
    },
  );
  test('catch-up chunks do not repeat or skip an occurrence', () {
    final first = plan(frequency: 'daily', end: '2027-02-01', limit: 20);
    final next = plan(
      frequency: 'daily',
      end: '2027-02-01',
      limit: 20,
      cursor: first.processedThrough,
    );
    expect(first.dates.length, 20);
    expect(next.dates.first, '2026-11-25');
    expect({...first.dates, ...next.dates}.length, 40);
    expect(plan(cursor: '2028-10-31').dates, isEmpty);
  });
  test('malformed schedules fail closed', () {
    expect(() => plan(start: '2027-02-30'), throwsFormatException);
    expect(() => plan(frequency: 'invalid'), throwsFormatException);
    expect(() => plan(end: '2020-01-01'), throwsFormatException);
  });
}
