// lib/services/cost_service.dart
//
// Lee y escribe la colección `service_costs/{serviceId}`.
// Solo el dueño (admin) puede escribir. Los workers solo leen.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_stats.dart';
import '../models/period.dart';

class CostService {
  CostService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _costsCollection = 'service_costs';

  double _price(Map<String, dynamic> d) {
    final fp = d['finalPrice'];
    final bp = d['basePrice'] ?? d['total'] ?? 0;
    return ((fp ?? bp) as num).toDouble();
  }

  bool _countsAsRevenue(String s) => s == 'done' || s == 'scheduled';

  // ── Leer todos los costes registrados ─────────────────────────────────────

  Future<Map<String, ServiceCost>> fetchAllCosts() async {
    final snap = await _db.collection(_costsCollection).get();
    return {
      for (final doc in snap.docs)
        doc.id: ServiceCost.fromMap(doc.id, doc.data()),
    };
  }

  // ── Stats de servicios para el período con costes aplicados ───────────────

  Future<List<ServiceStats>> fetchServiceStats(Period period) async {
    // Query de appointments en el período
    final snap = await _db
        .collection('appointments')
        .where('appointmentDate',
            isGreaterThanOrEqualTo: period.fromTimestamp)
        .where('appointmentDate', isLessThan: period.toTimestamp)
        .get();

    // Costes registrados
    final costs = await fetchAllCosts();

    // Agrega por serviceId
    final Map<String, _Agg> agg = {};

    for (final doc in snap.docs) {
      final d      = doc.data();
      final status = (d['status'] ?? '').toString();
      if (!_countsAsRevenue(status)) continue;

      final sid   = (d['serviceId'] ?? d['serviceNameKey'] ?? '').toString();
      final sname = (d['serviceName'] ?? sid).toString();
      if (sid.isEmpty) continue;

      agg[sid] ??= _Agg(id: sid, name: sname);
      agg[sid]!.count++;
      agg[sid]!.revenue += _price(d);
    }

    // Construye ServiceStats con coste si existe
    final result = agg.values.map((a) {
      final cost = costs[a.id]?.costPerUnit ?? 0;
      return ServiceStats(
        serviceId:            a.id,
        serviceName:          a.name,
        count:                a.count,
        revenue:              a.revenue,
        materialCostPerUnit:  cost,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return result;
  }

  // ── Guardar coste de un servicio ──────────────────────────────────────────

  Future<void> saveCost({
    required String serviceId,
    required String serviceName,
    required double costPerUnit,
  }) async {
    await _db.collection(_costsCollection).doc(serviceId).set(
      ServiceCost(
        serviceId:   serviceId,
        serviceName: serviceName,
        costPerUnit: costPerUnit,
      ).toMap(),
      SetOptions(merge: true),
    );
  }

  // ── Eliminar coste (resetear a 0) ─────────────────────────────────────────

  Future<void> deleteCost(String serviceId) async {
    await _db.collection(_costsCollection).doc(serviceId).delete();
  }

  // ── Coste total de materiales del período ─────────────────────────────────

  Future<double> fetchTotalMaterialCost(Period period) async {
    final stats = await fetchServiceStats(period);
    return stats.fold<double>(0, (s, st) => s + st.totalMaterialCost);
  }
}

class _Agg {
  final String id;
  final String name;
  double revenue = 0;
  int    count   = 0;
  _Agg({required this.id, required this.name});
}
