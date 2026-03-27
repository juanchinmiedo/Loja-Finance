// lib/widgets/revenue_chart.dart
//
// Gráfica de línea de ingresos — 12 meses.
// Usa fl_chart (añadir en pubspec: fl_chart: ^0.68.0)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/kpi_data.dart';

class RevenueChart extends StatefulWidget {
  const RevenueChart({
    super.key,
    required this.points,
    this.isLoading = false,
  });

  final List<RevenuePoint> points;
  final bool isLoading;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: widget.isLoading
          ? const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4285F4),
                ),
              ),
            )
          : SizedBox(
              height: 180,
              child: LineChart(_buildChart()),
            ),
    );
  }

  LineChartData _buildChart() {
    final spots = widget.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    final maxY = widget.points.isEmpty
        ? 100.0
        : widget.points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

    return LineChartData(
      minX: 0,
      maxX: (widget.points.length - 1).toDouble(),
      minY: 0,
      maxY: maxY * 1.2,

      // ── Touch ─────────────────────────────────────────────────────────────
      lineTouchData: LineTouchData(
        touchCallback: (event, response) {
          setState(() {
            _touchedIndex = response?.lineBarSpots?.first.spotIndex;
          });
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF202124),
          getTooltipItems: (spots) => spots.map((s) {
            final point = widget.points[s.spotIndex];
            return LineTooltipItem(
              '€${s.y.toStringAsFixed(0)}\n',
              GoogleFonts.nunito(
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: DateFormat('MMM yyyy').format(point.month),
                  style: GoogleFonts.nunito(
                    color:    Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),

      // ── Grid ──────────────────────────────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY == 0 ? 100 : maxY / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color:       const Color(0xFFF1F3F4),
          strokeWidth: 1,
        ),
      ),

      // ── Bordes ────────────────────────────────────────────────────────────
      borderData: FlBorderData(show: false),

      // ── Ejes ──────────────────────────────────────────────────────────────
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles:    true,
            reservedSize:  48,
            interval:      maxY == 0 ? 100 : maxY / 4,
            getTitlesWidget: (value, _) => Text(
              '€${_compact(value)}',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color:    const Color(0xFFBDC1C6),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles:   true,
            reservedSize: 24,
            interval:     2,
            getTitlesWidget: (value, _) {
              final idx = value.toInt();
              if (idx < 0 || idx >= widget.points.length) {
                return const SizedBox.shrink();
              }
              final isTouched = idx == _touchedIndex;
              return Text(
                DateFormat('MMM').format(widget.points[idx].month),
                style: GoogleFonts.nunito(
                  fontSize:   10,
                  fontWeight: isTouched ? FontWeight.w700 : FontWeight.w400,
                  color: isTouched
                      ? const Color(0xFF4285F4)
                      : const Color(0xFFBDC1C6),
                ),
              );
            },
          ),
        ),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),

      // ── Línea ─────────────────────────────────────────────────────────────
      lineBarsData: [
        LineChartBarData(
          spots:         spots,
          isCurved:      true,
          curveSmoothness: 0.35,
          color:         const Color(0xFF4285F4),
          barWidth:      2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => spot.x.toInt() == _touchedIndex,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius:      5,
              color:       const Color(0xFF4285F4),
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                const Color(0xFF4285F4).withValues(alpha: 0.15),
                const Color(0xFF4285F4).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _compact(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}
