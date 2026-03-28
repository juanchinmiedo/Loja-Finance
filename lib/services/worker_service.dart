// lib/services/worker_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_stats.dart';
import '../models/kpi_data.dart';
import '../models/period.dart';

class WorkerService {
  WorkerService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  double _price(Map<String, dynamic> d) {
    final fp = d['finalPrice'];
    final bp = d['basePrice'] ?? d['total'] ?? 0;
    return ((fp ?? bp) as num).toDouble();
  }

  bool _countsAsRevenue(String s)   => s == 'done' || s == 'scheduled';
  bool _countsAsCompleted(String s) => s == 'done' || s == 'scheduled';

  // ── Nombres reales de workers ──────────────────────────────────────────────
  final Map<String, String> _workerNames = {};

  Future<void> _ensureWorkerNames() async {
    if (_workerNames.isNotEmpty) return;
    try {
      final snap = await _db.collection('workers').get();
      for (final doc in snap.docs) {
        final data        = doc.data();
        final displayName = (data['nameShown'] ?? data['name'] ?? '').toString().trim();
        _workerNames[doc.id] = displayName.isNotEmpty
            ? displayName
            : doc.id.replaceAll('_', ' ').trim();
      }
    } catch (_) {}
  }

  String _workerDisplayName(String workerId) =>
      _workerNames[workerId] ?? workerId.replaceAll('_', ' ').trim();

  // ── Stats de todos los workers para el período ────────────────────────────

  Future<List<WorkerStats>> fetchAllWorkers(Period period) async {
    await _ensureWorkerNames();

    final snap = await _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: period.fromTimestamp)
        .where('appointmentDate', isLessThan: period.toTimestamp)
        .get();

    final snapPrev = await _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: period.previous.fromTimestamp)
        .where('appointmentDate', isLessThan: period.previous.toTimestamp)
        .get();

    final Map<String, _WorkerAgg> agg     = {};
    final Map<String, _WorkerAgg> aggPrev = {};
    double totalRevenue = 0;

    for (final doc in snap.docs) {
      final d      = doc.data();
      final status = (d['status'] ?? '').toString();
      final wid    = (d['workerId'] ?? 'unknown').toString();
      final wname  = _workerDisplayName(wid);
      final price  = _price(d);

      agg[wid] ??= _WorkerAgg(id: wid, name: wname);
      agg[wid]!.totalCount++;
      if (_countsAsRevenue(status)) {
        agg[wid]!.revenue += price;
        totalRevenue       += price;
      }
      if (_countsAsCompleted(status)) agg[wid]!.completedCount++;

      final sid   = (d['serviceId'] ?? d['serviceNameKey'] ?? '').toString();
      final sname = (d['serviceName'] ?? sid).toString();
      if (sid.isNotEmpty && _countsAsRevenue(status)) {
        agg[wid]!.services[sid] ??= ServiceCount(
            serviceId: sid, serviceName: sname, count: 0, revenue: 0);
        agg[wid]!.services[sid] = ServiceCount(
          serviceId:   sid,
          serviceName: sname,
          count:       agg[wid]!.services[sid]!.count   + 1,
          revenue:     agg[wid]!.services[sid]!.revenue + price,
        );
      }
    }

    for (final doc in snapPrev.docs) {
      final d      = doc.data();
      final status = (d['status'] ?? '').toString();
      final wid    = (d['workerId'] ?? 'unknown').toString();
      if (!_countsAsRevenue(status)) continue;
      aggPrev[wid] ??= _WorkerAgg(id: wid, name: wid);
      aggPrev[wid]!.revenue += _price(d);
    }

    final monthlyByWorker = await _fetchMonthlyByWorker();

    return agg.values.map((a) {
      final topServices = (a.services.values.toList()
            ..sort((x, y) => y.revenue.compareTo(x.revenue)))
          .take(3)
          .toList();

      return WorkerStats(
        workerId:         a.id,
        workerName:       a.name,
        grossRevenue:     a.revenue,
        prevGrossRevenue: aggPrev[a.id]?.revenue ?? 0,
        completedCount:   a.completedCount,
        totalCount:       a.totalCount,
        sharePercent:     totalRevenue == 0 ? 0 : (a.revenue / totalRevenue) * 100,
        topServices:      topServices,
        monthlyPoints:    monthlyByWorker[a.id] ?? [],
      );
    }).toList()
      ..sort((a, b) => b.grossRevenue.compareTo(a.grossRevenue));
  }

  Future<WorkerStats?> fetchWorkerDetail(String workerId, Period period) async {
    final all = await fetchAllWorkers(period);
    try {
      return all.firstWhere((w) => w.workerId == workerId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, List<RevenuePoint>>> _fetchMonthlyByWorker() async {
    final months = Period.last12Months();
    final from   = months.first.fromTimestamp;
    final to     = months.last.toTimestamp;

    final snap = await _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: from)
        .where('appointmentDate', isLessThan: to)
        .get();

    final Map<String, Map<String, double>> byWorkerMonth = {};

    for (final doc in snap.docs) {
      final d      = doc.data();
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;

      final wid = (d['workerId'] ?? 'unknown').toString();
      final ts  = d['appointmentDate'];
      if (ts is! Timestamp) continue;
      final dt  = ts.toDate();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

      byWorkerMonth[wid] ??= {};
      byWorkerMonth[wid]![key] = (byWorkerMonth[wid]![key] ?? 0) + _price(d);
    }

    return byWorkerMonth.map((wid, monthMap) {
      final pts = months.map((m) {
        final key = '${m.from.year}-${m.from.month.toString().padLeft(2, '0')}';
        return RevenuePoint(month: m.from, revenue: monthMap[key] ?? 0);
      }).toList();
      return MapEntry(wid, pts);
    });
  }
}

class _WorkerAgg {
  final String id;
  final String name;
  double revenue        = 0;
  int    completedCount = 0;
  int    totalCount     = 0;
  final Map<String, ServiceCount> services = {};
  _WorkerAgg({required this.id, required this.name});
}
