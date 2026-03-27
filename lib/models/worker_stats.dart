// lib/models/worker_stats.dart

import 'kpi_data.dart';

class WorkerStats {
  final String workerId;
  final String workerName;

  /// Ingresos brutos generados por este worker en el período
  final double grossRevenue;

  /// Ingresos del período anterior (para % cambio)
  final double prevGrossRevenue;

  /// Número de citas completadas (status == 'done')
  final int completedCount;

  /// Total de citas en el período
  final int totalCount;

  /// % de contribución al ingreso total del salón
  final double sharePercent;

  /// Top 3 servicios más realizados por este worker
  final List<ServiceCount> topServices;

  /// Ingresos por mes (últimos 12) para mini-gráfica
  final List<RevenuePoint> monthlyPoints;

  double get avgTicket =>
      completedCount == 0 ? 0 : grossRevenue / completedCount;

  double get revenueChangePercent {
    if (prevGrossRevenue == 0) return 0;
    return ((grossRevenue - prevGrossRevenue) / prevGrossRevenue) * 100;
  }

  double get occupancyRate =>
      totalCount == 0 ? 0 : (completedCount / totalCount) * 100;

  const WorkerStats({
    required this.workerId,
    required this.workerName,
    required this.grossRevenue,
    required this.prevGrossRevenue,
    required this.completedCount,
    required this.totalCount,
    required this.sharePercent,
    required this.topServices,
    required this.monthlyPoints,
  });
}

class ServiceCount {
  final String serviceId;
  final String serviceName;
  final int    count;
  final double revenue;
  const ServiceCount({
    required this.serviceId,
    required this.serviceName,
    required this.count,
    required this.revenue,
  });
}
