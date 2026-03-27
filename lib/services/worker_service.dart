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

  bool _countsAsRevenue(String s) => s == 'done' || s == 'scheduled';

  // ── Lista de workers registrados en Firestore (/users con workerId en claims)
  // Usamos la colección workers si existe, si no tiramos de appointments únicos
  Future<List<_RawWorker>> _fetchWorkerList() async {
    // Intentamos la colección 'workers' primero
    try {
      final snap = await _db.collection('workers').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) {
          final data = d.data();
          return _RawWorker(
            id:   (data['workerId'] ?? d.id).toString(),
            name: (data['name'] ?? data['displayName'] ?? d.id).toString(),
          );
        }).toList();
      }
    } catch (_) {}

    // Fallback: workers únicos de /users donde workerId != null
    try {
      final snap = await _db
          .collection('users')
          .where('workerId', isNull: false)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        final wid  = (data['workerId'] ?? '').toString();
        final name = (data['displayName'] ?? data['name'] ?? wid).toString();
        return _RawWorker(id: wid, name: name);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Stats de todos los workers para el período ────────────────────────────

  Future<List<WorkerStats>> fetchAllWorkers(Period period) async {
    // Una sola query para todo el período
    final snap = await _db
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: period.fromTimestamp)
        .where('appointmentDate', isLessThan: period.toTimestamp)
        .get();

    final snapPrev = await _db
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: period.previous.fromTimestamp)
        .where('appointmentDate',
            isLessThan: period.previous.toTimestamp)
        .get();

    // Agrupa por workerId
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
      if (status == 'done') agg[wid]!.completedCount++;

      // Top servicios
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

    // Gráfica de 12 meses por worker (una sola query grande)
    final monthlyByWorker = await _fetchMonthlyByWorker();

    // Construye la lista final
    final result = agg.values.map((a) {
      final topServices = (a.services.values.toList()
            ..sort((x, y) => y.revenue.compareTo(x.revenue)))
          .take(3)
          .toList();

      return WorkerStats(
        workerId:        a.id,
        workerName:      a.name,
        grossRevenue:    a.revenue,
        prevGrossRevenue: aggPrev[a.id]?.revenue ?? 0,
        completedCount:  a.completedCount,
        totalCount:      a.totalCount,
        sharePercent:    totalRevenue == 0
            ? 0
            : (a.revenue / totalRevenue) * 100,
        topServices:     topServices,
        monthlyPoints:   monthlyByWorker[a.id] ?? [],
      );
    }).toList()
      ..sort((a, b) => b.grossRevenue.compareTo(a.grossRevenue));

    return result;
  }

  // ── Stats de un worker concreto ───────────────────────────────────────────

  Future<WorkerStats?> fetchWorkerDetail(
      String workerId, Period period) async {
    final all = await fetchAllWorkers(period);
    try {
      return all.firstWhere((w) => w.workerId == workerId);
    } catch (_) {
      return null;
    }
  }

  // ── Gráfica mensual por worker (12 meses, una query) ─────────────────────

  Future<Map<String, List<RevenuePoint>>> _fetchMonthlyByWorker() async {
    final months = Period.last12Months();
    final from   = months.first.fromTimestamp;
    final to     = months.last.toTimestamp;

    final snap = await _db
        .collection('appointments')
        .where('appointmentDate', isGreaterThanOrEqualTo: from)
        .where('appointmentDate', isLessThan: to)
        .get();

    // Map: workerId → { 'YYYY-MM' → revenue }
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
      byWorkerMonth[wid]![key] =
          (byWorkerMonth[wid]![key] ?? 0) + _price(d);
    }

    // Convierte al formato List<RevenuePoint>
    return byWorkerMonth.map((wid, monthMap) {
      final pts = months.map((m) {
        final key = '${m.from.year}-${m.from.month.toString().padLeft(2, '0')}';
        return RevenuePoint(month: m.from, revenue: monthMap[key] ?? 0);
      }).toList();
      return MapEntry(wid, pts);
    });
  }

  // ── Nombre display de un workerId (convierte guiones bajos en espacios) ───
  String _workerDisplayName(String workerId) {
    return workerId.replaceAll('_', ' ').trim();
  }
}

class _WorkerAgg {
  final String id;
  final String name;
  double revenue       = 0;
  int    completedCount = 0;
  int    totalCount    = 0;
  final Map<String, ServiceCount> services = {};
  _WorkerAgg({required this.id, required this.name});
}

class _RawWorker {
  final String id;
  final String name;
  const _RawWorker({required this.id, required this.name});
}
