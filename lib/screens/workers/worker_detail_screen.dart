// lib/screens/workers/worker_detail_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/worker_stats.dart';
import '../../models/kpi_data.dart';
import '../../providers/period_provider.dart';
import '../../services/worker_service.dart';
import '../../widgets/kpi_card.dart';
import 'package:financas_hub_app/generated/l10n.dart';

class WorkerDetailScreen extends StatefulWidget {
  const WorkerDetailScreen({
    super.key,
    required this.initialStats,
    required this.workerId,
  });

  final WorkerStats initialStats;
  final String      workerId;

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final _service = WorkerService();
  late WorkerStats _stats;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _stats.workerName,
          style: GoogleFonts.nunito(
            fontSize:   18,
            fontWeight: FontWeight.w600,
            color:      const Color(0xFF202124),
          ),
        ),
        backgroundColor: Colors.white,
        elevation:       0,
        scrolledUnderElevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF202124)),
      ),
      body: RefreshIndicator(
        color:     const Color(0xFF4285F4),
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── KPI cards ─────────────────────────────────────────────────
            _buildKpiGrid(l10n),
            const SizedBox(height: 20),

            // ── % del salón ───────────────────────────────────────────────
            _buildShareBar(),
            const SizedBox(height: 20),

            // ── Gráfica mensual ───────────────────────────────────────────
            _buildMonthlyChart(l10n),
            const SizedBox(height: 20),

            // ── Top servicios ─────────────────────────────────────────────
            _buildTopServices(l10n),
          ],
        ),
      ),
    );
  }

  Future<void> _reload() async {
    final period = context.read<PeriodProvider>().current;
    final updated = await _service.fetchWorkerDetail(widget.workerId, period);
    if (mounted && updated != null) setState(() => _stats = updated);
  }

  // ── KPI grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(S l10n) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label:         l10n.workerRevenue,
                value:         '€${_stats.grossRevenue.toStringAsFixed(0)}',
                changePercent: _stats.revenueChangePercent,
                icon:          Icons.euro_rounded,
                accentColor:   const Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label:       l10n.kpiAvgTicket,
                value:       '€${_stats.avgTicket.toStringAsFixed(0)}',
                icon:        Icons.receipt_outlined,
                accentColor: const Color(0xFFFBBC04),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label:       l10n.kpiCompletedAppointments,
                value:       '${_stats.completedCount}',
                icon:        Icons.check_circle_outline,
                accentColor: const Color(0xFF34A853),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label:       l10n.kpiOccupancyRate,
                value:       '${_stats.occupancyRate.toStringAsFixed(1)}%',
                icon:        Icons.calendar_today_outlined,
                accentColor: const Color(0xFF4285F4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Barra de share ────────────────────────────────────────────────────────

  Widget _buildShareBar() {
    final pct = _stats.sharePercent.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('% del total del salón',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: const Color(0xFF80868B),
                      fontWeight: FontWeight.w500)),
              Text('${pct.toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: const Color(0xFF4285F4))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            pct / 100,
              minHeight:        8,
              backgroundColor:  const Color(0xFFF1F3F4),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4285F4)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfica mensual ───────────────────────────────────────────────────────

  Widget _buildMonthlyChart(S l10n) {
    final pts = _stats.monthlyPoints;
    if (pts.isEmpty) return const SizedBox.shrink();

    final spots = pts.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
        .toList();

    final maxY = pts.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'Ingresos últimos 12 meses',
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              minX: 0, maxX: (pts.length - 1).toDouble(),
              minY: 0, maxY: maxY * 1.25,
              lineTouchData: LineTouchData(
                touchCallback: (_, r) => setState(() =>
                    _touchedIndex = r?.lineBarSpots?.first.spotIndex),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF202124),
                  getTooltipItems: (spots) => spots.map((s) {
                    final p = pts[s.x.toInt()];
                    return LineTooltipItem(
                      '€${s.y.toStringAsFixed(0)}\n',
                      GoogleFonts.nunito(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700),
                      children: [TextSpan(
                          text: DateFormat('MMM yy').format(p.month),
                          style: GoogleFonts.nunito(
                              color: Colors.white70, fontSize: 10))],
                    );
                  }).toList(),
                ),
              ),
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                horizontalInterval: maxY == 0 ? 100 : maxY / 3,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFFF1F3F4), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles:   true,
                    reservedSize: 22,
                    interval:     3,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat('MMM').format(pts[i].month),
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          color: i == _touchedIndex
                              ? const Color(0xFF4285F4)
                              : const Color(0xFFBDC1C6),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots:            spots,
                  isCurved:         true,
                  curveSmoothness:  0.35,
                  color:            const Color(0xFF34A853),
                  barWidth:         2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (s, _) => s.x.toInt() == _touchedIndex,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4, color: const Color(0xFF34A853),
                      strokeWidth: 2, strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF34A853).withValues(alpha: 0.12),
                        const Color(0xFF34A853).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // ── Top servicios ─────────────────────────────────────────────────────────

  Widget _buildTopServices(S l10n) {
    if (_stats.topServices.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.workerTopServices,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: const Color(0xFF202124))),
          const SizedBox(height: 12),
          ..._stats.topServices.asMap().entries.map((e) =>
              _ServiceRow(service: e.value, index: e.key)),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.index});
  final ServiceCount service;
  final int          index;

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC04),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color:        color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.serviceName,
                    style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: const Color(0xFF202124)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${service.count} veces',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: const Color(0xFF80868B))),
              ],
            ),
          ),
          Text('€${service.revenue.toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124))),
        ],
      ),
    );
  }
}
