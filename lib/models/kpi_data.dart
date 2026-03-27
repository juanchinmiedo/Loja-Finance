// lib/models/kpi_data.dart
// (Renombrado de kpi_summary.dart — Windows rechaza ese nombre en algunos casos)

class KpiSummary {
  final double grossRevenue;
  final double prevGrossRevenue;
  final double netRevenue;
  final double avgTicket;
  final int    completedCount;
  final int    cancelledCount;
  final int    noShowCount;
  final int    totalCount;

  double get occupancyRate =>
      totalCount == 0 ? 0 : (completedCount / totalCount) * 100;

  double get revenueChangePercent {
    if (prevGrossRevenue == 0) return 0;
    return ((grossRevenue - prevGrossRevenue) / prevGrossRevenue) * 100;
  }

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
    grossRevenue: 0, prevGrossRevenue: 0, netRevenue: 0,
    avgTicket: 0, completedCount: 0, cancelledCount: 0,
    noShowCount: 0, totalCount: 0,
  );
}

class RevenuePoint {
  final DateTime month;
  final double   revenue;
  const RevenuePoint({required this.month, required this.revenue});
}
