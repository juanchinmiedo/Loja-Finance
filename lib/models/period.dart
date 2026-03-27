// lib/models/period.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PeriodType { week, month, year, custom }

class Period {
  final PeriodType type;
  final DateTime   from;
  final DateTime   to;

  const Period({required this.type, required this.from, required this.to});

  // ── Factories ──────────────────────────────────────────────────────────────

  factory Period.thisWeek() {
    final now   = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final from  = DateTime(start.year, start.month, start.day);
    final to    = from.add(const Duration(days: 7));
    return Period(type: PeriodType.week, from: from, to: to);
  }

  factory Period.thisMonth() {
    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to   = DateTime(now.year, now.month + 1, 1);
    return Period(type: PeriodType.month, from: from, to: to);
  }

  factory Period.thisYear() {
    final now  = DateTime.now();
    final from = DateTime(now.year, 1, 1);
    final to   = DateTime(now.year + 1, 1, 1);
    return Period(type: PeriodType.year, from: from, to: to);
  }

  factory Period.custom(DateTime from, DateTime to) {
    return Period(
      type: PeriodType.custom,
      from: DateTime(from.year, from.month, from.day),
      to:   DateTime(to.year,   to.month,   to.day + 1),
    );
  }

  // ── Previous period (para calcular % de cambio) ───────────────────────────

  Period get previous {
    final duration = to.difference(from);
    return Period(
      type: type,
      from: from.subtract(duration),
      to:   from,
    );
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────

  Timestamp get fromTimestamp => Timestamp.fromDate(from);
  Timestamp get toTimestamp   => Timestamp.fromDate(to);

  // ── Número de meses para la gráfica anual ─────────────────────────────────

  /// Devuelve los 12 meses anteriores al mes actual (inclusive).
  static List<Period> last12Months() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final month = now.month - 11 + i;
      final year  = now.year + (month - 1) ~/ 12;
      final m     = ((month - 1) % 12) + 1;
      return Period.thisMonth().copyWith(
        from: DateTime(year, m, 1),
        to:   DateTime(year, m + 1, 1),
      );
    });
  }

  Period copyWith({DateTime? from, DateTime? to, PeriodType? type}) {
    return Period(
      type: type ?? this.type,
      from: from ?? this.from,
      to:   to   ?? this.to,
    );
  }

  @override
  String toString() =>
      'Period(${type.name}: ${from.toIso8601String()} → ${to.toIso8601String()})';
}
