// lib/models/period.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PeriodType { day, week, month, year, custom }

class Period {
  final PeriodType type;
  final DateTime   from;
  final DateTime   to;

  const Period({required this.type, required this.from, required this.to});

  factory Period.today() {
    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    return Period(type: PeriodType.day, from: from, to: from.add(const Duration(days: 1)));
  }

  factory Period.thisWeek() {
    final now   = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final from  = DateTime(start.year, start.month, start.day);
    return Period(type: PeriodType.week, from: from, to: from.add(const Duration(days: 7)));
  }

  factory Period.thisMonth() {
    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    return Period(type: PeriodType.month, from: from, to: DateTime(now.year, now.month + 1, 1));
  }

  factory Period.thisYear() {
    final now  = DateTime.now();
    final from = DateTime(now.year, 1, 1);
    return Period(type: PeriodType.year, from: from, to: DateTime(now.year + 1, 1, 1));
  }

  factory Period.custom(DateTime from, DateTime to) {
    return Period(
      type: PeriodType.custom,
      from: DateTime(from.year, from.month, from.day),
      to:   DateTime(to.year,   to.month,   to.day + 1),
    );
  }

  Period get previous {
    final duration = to.difference(from);
    return Period(type: type, from: from.subtract(duration), to: from);
  }

  Timestamp get fromTimestamp => Timestamp.fromDate(from);
  Timestamp get toTimestamp   => Timestamp.fromDate(to);

  static List<Period> last12Days() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month, now.day - 11 + i);
      return Period(type: PeriodType.day, from: d, to: d.add(const Duration(days: 1)));
    });
  }

  static List<Period> last12Weeks() {
    final now             = DateTime.now();
    final today           = DateTime(now.year, now.month, now.day);
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(12, (i) {
      final weekStart = startOfThisWeek.subtract(Duration(days: (11 - i) * 7));
      return Period(type: PeriodType.week, from: weekStart, to: weekStart.add(const Duration(days: 7)));
    });
  }

  static List<Period> last12Months() {
    final now        = DateTime.now();
    final startYear  = now.year;
    final startMonth = now.month - 11;
    return List.generate(12, (i) {
      final from = DateTime(startYear, startMonth + i, 1);
      final to   = DateTime(startYear, startMonth + i + 1, 1);
      return Period(type: PeriodType.month, from: from, to: to);
    });
  }

  static List<Period> last12Years() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final y = now.year - 11 + i;
      return Period(type: PeriodType.year, from: DateTime(y, 1, 1), to: DateTime(y + 1, 1, 1));
    });
  }

  List<Period> chartBuckets() {
    switch (type) {
      case PeriodType.day:    return last12Days();
      case PeriodType.week:   return last12Weeks();
      case PeriodType.month:  return last12Months();
      case PeriodType.year:   return last12Years();
      case PeriodType.custom: return last12Months();
    }
  }

  Period copyWith({DateTime? from, DateTime? to, PeriodType? type}) {
    return Period(type: type ?? this.type, from: from ?? this.from, to: to ?? this.to);
  }

  @override
  String toString() =>
      'Period(${type.name}: ${from.toIso8601String()} → ${to.toIso8601String()})';
}
