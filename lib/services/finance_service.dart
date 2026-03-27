// lib/services/finance_service.dart
//
// Todas las queries financieras a Firestore.
// Precio real = finalPrice ?? basePrice.
// Solo se cuentan ingresos de citas con status 'done' o 'scheduled'.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kpi_data.dart';
import '../models/period.dart';

class FinanceService {
  FinanceService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Precio efectivo de un documento ───────────────────────────────────────

  double _price(Map<String, dynamic> data) {
    final fp = data['finalPrice'];
    final bp = data['basePrice'] ?? data['total'] ?? 0;
    return ((fp ?? bp) as num).toDouble();
  }

  bool _countsAsRevenue(String status) =>
      status == 'done' || status == 'scheduled';

  // ── Query base para un período ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchPeriod(
    Period period, {
    String? workerId,
  }) async {
    Query q = _db
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: period.fromTimestamp)
        .where('appointmentDate', isLessThan: period.toTimestamp);

    if (workerId != null) {
      q = q.where('workerId', isEqualTo: workerId);
    }

    final snap = await q.get();
    return snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }

  // ── KPI summary para un período ────────────────────────────────────────────

  Future<KpiSummary> fetchKpiSummary(
    Period period, {
    String? workerId,     // null = todos los workers (admin)
    double materialCost = 0, // coste total de materiales del período
  }) async {
    final docs     = await _fetchPeriod(period, workerId: workerId);
    final prevDocs = await _fetchPeriod(period.previous, workerId: workerId);

    double grossRevenue = 0;
    double prevRevenue  = 0;
    int    completed    = 0;
    int    cancelled    = 0;
    int    noShow       = 0;

    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (_countsAsRevenue(status)) grossRevenue += _price(d);
      if (status == 'done')      completed++;
      if (status == 'cancelled') cancelled++;
      if (status == 'noShow')    noShow++;
    }

    for (final d in prevDocs) {
      final status = (d['status'] ?? '').toString();
      if (_countsAsRevenue(status)) prevRevenue += _price(d);
    }

    final netRevenue = grossRevenue - materialCost;
    final avgTicket  = completed == 0 ? 0.0 : grossRevenue / completed;

    return KpiSummary(
      grossRevenue:     grossRevenue,
      prevGrossRevenue: prevRevenue,
      netRevenue:       netRevenue,
      avgTicket:        avgTicket,
      completedCount:   completed,
      cancelledCount:   cancelled,
      noShowCount:      noShow,
      totalCount:       docs.length,
    );
  }

  // ── Gráfica: ingresos de los últimos 12 meses ─────────────────────────────

  Future<List<RevenuePoint>> fetchLast12Months({String? workerId}) async {
    final months = Period.last12Months();

    // Una sola query grande para los 12 meses
    final from = months.first.fromTimestamp;
    final to   = months.last.toTimestamp;

    Query q = _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: from)
        .where('appointmentDate', isLessThan: to);

    if (workerId != null) {
      q = q.where('workerId', isEqualTo: workerId);
    }

    final snap = await q.get();
    final docs  = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // Agrupa por mes
    final Map<String, double> byMonth = {};
    for (final m in months) {
      final key = '${m.from.year}-${m.from.month.toString().padLeft(2, '0')}';
      byMonth[key] = 0;
    }

    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;

      final ts = d['appointmentDate'];
      if (ts is! Timestamp) continue;
      final dt  = ts.toDate();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + _price(d);
    }

    return months.map((m) {
      final key = '${m.from.year}-${m.from.month.toString().padLeft(2, '0')}';
      return RevenuePoint(month: m.from, revenue: byMonth[key] ?? 0);
    }).toList();
  }

  // ── Ingresos totales históricos por worker ─────────────────────────────────

  Future<Map<String, double>> fetchRevenueByWorker(Period period) async {
    final docs = await _fetchPeriod(period);
    final Map<String, double> result = {};

    for (final d in docs) {
      final status   = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;
      final worker = (d['workerId'] ?? 'unknown').toString();
      result[worker] = (result[worker] ?? 0) + _price(d);
    }

    return result;
  }

  // ── Top servicios por frecuencia e ingresos ────────────────────────────────

  Future<List<_ServiceAgg>> fetchTopServices(
    Period period, {
    String? workerId,
    int limit = 8,
  }) async {
    final docs = await _fetchPeriod(period, workerId: workerId);
    final Map<String, _ServiceAgg> agg = {};

    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;

      final id   = (d['serviceId']   ?? d['serviceNameKey'] ?? 'unknown').toString();
      final name = (d['serviceName'] ?? id).toString();

      agg[id] = _ServiceAgg(
        id:       id,
        name:     name,
        count:    (agg[id]?.count    ?? 0) + 1,
        revenue:  (agg[id]?.revenue  ?? 0) + _price(d),
      );
    }

    final list = agg.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }
}

class _ServiceAgg {
  final String id;
  final String name;
  final int    count;
  final double revenue;
  const _ServiceAgg({
    required this.id,
    required this.name,
    required this.count,
    required this.revenue,
  });
}
