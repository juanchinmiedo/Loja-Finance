// lib/services/finance_service.dart
// COMMIT 2 — fetchChartPoints accepts serviceId for service comparator

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kpi_data.dart';
import '../models/period.dart';

class FinanceService {
  FinanceService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  double _price(Map<String, dynamic> data) {
    final fp = data['finalPrice'];
    final bp = data['basePrice'] ?? data['total'] ?? 0;
    return ((fp ?? bp) as num).toDouble();
  }

  bool _countsAsRevenue(String status)   => status == 'done' || status == 'scheduled';
  bool _countsAsCompleted(String status) => status == 'done' || status == 'scheduled';

  Future<List<Map<String, dynamic>>> _fetchPeriod(
    Period period, {
    String? workerId,
    String? serviceId, // FIX: filter by serviceId for service comparator
  }) async {
    Query q = _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: period.fromTimestamp)
        .where('appointmentDate', isLessThan: period.toTimestamp);

    if (workerId  != null) q = q.where('workerId',  isEqualTo: workerId);
    // NOTE: serviceId filter done in-memory (no compound index needed)

    final snap = await q.get();
    var docs = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    if (serviceId != null) {
      docs = docs.where((d) {
        final sid = (d['serviceId'] ?? d['serviceNameKey'] ?? '').toString();
        return sid == serviceId;
      }).toList();
    }

    return docs;
  }

  // ── KPI summary ────────────────────────────────────────────────────────────

  Future<KpiSummary> fetchKpiSummary(
    Period period, {
    String? workerId,
    double materialCost = 0,
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
      if (_countsAsRevenue(status))   grossRevenue += _price(d);
      if (_countsAsCompleted(status)) completed++;
      if (status == 'cancelled')      cancelled++;
      if (status == 'noShow')         noShow++;
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

  // ── Gráfica adaptativa ─────────────────────────────────────────────────────

  Future<List<RevenuePoint>> fetchChartPoints(
    Period activePeriod, {
    String? workerId,
    String? serviceId, // FIX: filter chart points by service
  }) async {
    List<Period> buckets = activePeriod.chartBuckets();

    if (activePeriod.type == PeriodType.year) {
      final yearAgo    = DateTime(DateTime.now().year - 1, 1, 1);
      final checkSnap  = await _db
          .collection('appointments')
          .where('appointmentDate', isLessThan: Timestamp.fromDate(yearAgo))
          .limit(1)
          .get();
      if (checkSnap.docs.isEmpty) {
        buckets = Period.last12Months();
      }
    }

    final from = buckets.first.fromTimestamp;
    final to   = buckets.last.toTimestamp;

    final allDocs = await _fetchPeriod(
      Period(type: activePeriod.type, from: buckets.first.from, to: buckets.last.to),
      workerId:  workerId,
      serviceId: serviceId,
    );
    final docs = allDocs;

    String bucketKey(Period b) =>
        '${b.from.year}-${b.from.month.toString().padLeft(2, '0')}-${b.from.day.toString().padLeft(2, '0')}';

    final Map<String, double> byBucket = {
      for (final b in buckets) bucketKey(b): 0.0,
    };

    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;
      final ts = d['appointmentDate'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      for (final b in buckets) {
        if (!dt.isBefore(b.from) && dt.isBefore(b.to)) {
          final key = bucketKey(b);
          byBucket[key] = (byBucket[key] ?? 0) + _price(d);
          break;
        }
      }
    }

    return buckets.map((b) => RevenuePoint(
      month:   b.from,
      revenue: byBucket[bucketKey(b)] ?? 0,
    )).toList();
  }

  // Alias para worker_service (sigue usando last12Months)
  Future<List<RevenuePoint>> fetchLast12Months({String? workerId}) =>
      fetchChartPoints(Period.thisMonth(), workerId: workerId);

  // ── Ingresos por worker ────────────────────────────────────────────────────

  Future<Map<String, double>> fetchRevenueByWorker(Period period) async {
    final docs = await _fetchPeriod(period);
    final Map<String, double> result = {};
    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;
      final worker = (d['workerId'] ?? 'unknown').toString();
      result[worker] = (result[worker] ?? 0) + _price(d);
    }
    return result;
  }

  // ── Top servicios ──────────────────────────────────────────────────────────

  Future<List<ServiceAgg>> fetchTopServices(
    Period period, {
    String? workerId,
    int limit = 8,
  }) async {
    final docs = await _fetchPeriod(period, workerId: workerId);
    final Map<String, ServiceAgg> agg = {};

    for (final d in docs) {
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;
      final id   = (d['serviceId']   ?? d['serviceNameKey'] ?? 'unknown').toString();
      final name = (d['serviceName'] ?? id).toString();
      agg[id] = ServiceAgg(
        id:      id,
        name:    name,
        count:   (agg[id]?.count   ?? 0) + 1,
        revenue: (agg[id]?.revenue ?? 0) + _price(d),
      );
    }

    return (agg.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue)))
        .take(limit)
        .toList();
  }
}

// Ahora público para que home_screen pueda usar el tipo
class ServiceAgg {
  final String id;
  final String name;
  final int    count;
  final double revenue;
  const ServiceAgg({
    required this.id,
    required this.name,
    required this.count,
    required this.revenue,
  });
}
