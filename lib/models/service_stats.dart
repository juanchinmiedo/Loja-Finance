// lib/models/service_stats.dart

class ServiceStats {
  final String serviceId;
  final String serviceName;

  /// Veces realizado en el período
  final int count;

  /// Ingresos brutos generados
  final double revenue;

  /// Precio medio cobrado (revenue / count)
  double get avgPrice => count == 0 ? 0 : revenue / count;

  /// Coste de material por unidad (lo introduce el dueño)
  final double materialCostPerUnit;

  /// Beneficio neto = revenue − (materialCostPerUnit × count)
  double get netRevenue => revenue - (materialCostPerUnit * count);

  /// Margen % = netRevenue / revenue × 100
  double get marginPercent =>
      revenue == 0 ? 0 : (netRevenue / revenue) * 100;

  /// Coste total de materiales en el período
  double get totalMaterialCost => materialCostPerUnit * count;

  const ServiceStats({
    required this.serviceId,
    required this.serviceName,
    required this.count,
    required this.revenue,
    required this.materialCostPerUnit,
  });
}

/// Documento en Firestore: service_costs/{serviceId}
class ServiceCost {
  final String serviceId;
  final String serviceName;
  final double costPerUnit;

  const ServiceCost({
    required this.serviceId,
    required this.serviceName,
    required this.costPerUnit,
  });

  factory ServiceCost.fromMap(String id, Map<String, dynamic> data) {
    return ServiceCost(
      serviceId:   id,
      serviceName: (data['serviceName'] ?? id).toString(),
      costPerUnit: (data['costPerUnit'] ?? 0 as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'serviceName': serviceName,
    'costPerUnit': costPerUnit,
    'updatedAt':   DateTime.now().toIso8601String(),
  };
}
