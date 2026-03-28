// lib/models/kpi_data.dart

// ─────────────────────────────────────────────────────────────────────────────
//  KpiSummary — resumen financiero de un período
// ─────────────────────────────────────────────────────────────────────────────

class KpiSummary {
  final double grossRevenue;      // ingresos brutos del período
  final double prevGrossRevenue;  // ingresos del período anterior (para % cambio)
  final double netRevenue;        // ingresos brutos - costes de material
  final double avgTicket;         // ticket medio (grossRevenue / completedCount)
  final int    completedCount;    // citas con status done o scheduled
  final int    cancelledCount;    // citas canceladas
  final int    noShowCount;       // citas no show
  final int    totalCount;        // total de citas en el período

  // ── Métricas derivadas ────────────────────────────────────────────────────

  /// Ocupación: % de citas productivas sobre el total
  double get occupancyRate =>
      totalCount == 0 ? 0 : (completedCount / totalCount) * 100;

  /// Variación porcentual respecto al período anterior
  double get revenueChangePercent {
    if (prevGrossRevenue == 0) return 0;
    return ((grossRevenue - prevGrossRevenue) / prevGrossRevenue) * 100;
  }

  /// true si los ingresos mejoraron respecto al período anterior
  bool get isTrendingUp => revenueChangePercent >= 0;

  /// Ingresos netos formateados (€ con 2 decimales)
  String get netRevenueFormatted =>
      '€${netRevenue.toStringAsFixed(2)}';

  /// Gross revenue formateado
  String get grossRevenueFormatted =>
      '€${grossRevenue.toStringAsFixed(2)}';

  const KpiSummary({
    required this.grossRevenue,
    required this.prevGrossRevenue,
    required this.netRevenue,
    required this.avgTicket,
    required this.completedCount,
    required this.cancelledCount,
    required this.noShowCount,
    required this.totalCount,
  });

  factory KpiSummary.empty() => const KpiSummary(
    grossRevenue:     0,
    prevGrossRevenue: 0,
    netRevenue:       0,
    avgTicket:        0,
    completedCount:   0,
    cancelledCount:   0,
    noShowCount:      0,
    totalCount:       0,
  );

  /// Combina dos KpiSummary (útil para sumar períodos o workers)
  KpiSummary operator +(KpiSummary other) => KpiSummary(
    grossRevenue:     grossRevenue     + other.grossRevenue,
    prevGrossRevenue: prevGrossRevenue + other.prevGrossRevenue,
    netRevenue:       netRevenue       + other.netRevenue,
    avgTicket:        (completedCount + other.completedCount) == 0
        ? 0
        : (grossRevenue + other.grossRevenue) /
          (completedCount + other.completedCount),
    completedCount:   completedCount   + other.completedCount,
    cancelledCount:   cancelledCount   + other.cancelledCount,
    noShowCount:      noShowCount      + other.noShowCount,
    totalCount:       totalCount       + other.totalCount,
  );

  @override
  String toString() =>
      'KpiSummary(gross: $grossRevenue, net: $netRevenue, '
      'completed: $completedCount, cancelled: $cancelledCount)';
}

// ─────────────────────────────────────────────────────────────────────────────
//  RevenuePoint — punto de datos para la gráfica de ingresos
// ─────────────────────────────────────────────────────────────────────────────

class RevenuePoint {
  final DateTime month;    // inicio del bucket (día, semana, mes o año)
  final double   revenue;  // ingresos totales del bucket

  const RevenuePoint({required this.month, required this.revenue});

  /// true si este bucket tiene ingresos
  bool get hasRevenue => revenue > 0;

  /// Suma dos puntos del mismo bucket
  RevenuePoint operator +(RevenuePoint other) => RevenuePoint(
    month:   month,
    revenue: revenue + other.revenue,
  );

  @override
  String toString() => 'RevenuePoint(${month.toIso8601String()}: $revenue)';
}

// ─────────────────────────────────────────────────────────────────────────────
//  WorkerKpi — KPIs específicos de un worker para el comparador
// ─────────────────────────────────────────────────────────────────────────────

class WorkerKpi {
  final String workerId;
  final String workerName;
  final double grossRevenue;
  final int    completedCount;
  final double sharePercent;   // % del total del salón

  double get avgTicket =>
      completedCount == 0 ? 0 : grossRevenue / completedCount;

  const WorkerKpi({
    required this.workerId,
    required this.workerName,
    required this.grossRevenue,
    required this.completedCount,
    required this.sharePercent,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ServiceKpi — KPIs de un servicio para el comparador
// ─────────────────────────────────────────────────────────────────────────────

class ServiceKpi {
  final String serviceId;
  final String serviceName;
  final double revenue;
  final int    count;
  final double marginPercent;  // (revenue - cost) / revenue * 100

  double get avgPrice => count == 0 ? 0 : revenue / count;

  const ServiceKpi({
    required this.serviceId,
    required this.serviceName,
    required this.revenue,
    required this.count,
    required this.marginPercent,
  });
}
