// lib/widgets/top_services_chart.dart
//
// Gráfica de barras horizontales — top servicios por ingresos.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/service_stats.dart';

class TopServicesChart extends StatelessWidget {
  const TopServicesChart({
    super.key,
    required this.services,
    this.maxItems = 6,
  });

  final List<ServiceStats> services;
  final int                maxItems;

  static const _barColors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC04),
    Color(0xFFEA4335),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    final items = services.take(maxItems).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final maxRevenue = items
        .map((s) => s.revenue)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: items.length * 44.0,
        child: BarChart(
          BarChartData(
            alignment:     BarChartAlignment.center,
            barTouchData:  BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF202124),
                getTooltipItem:  (group, _, rod, __) {
                  final s = items[group.x];
                  return BarTooltipItem(
                    '${s.serviceName}\n',
                    GoogleFonts.nunito(
                      color:      Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: '€${rod.toY.toStringAsFixed(0)}',
                        style: GoogleFonts.nunito(
                          color:    Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:   true,
                  reservedSize: 130,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= items.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        items[i].serviceName,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color:    const Color(0xFF5F6368),
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:   true,
                  reservedSize: 20,
                  getTitlesWidget: (value, _) => Text(
                    '€${_compact(value)}',
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      color:    const Color(0xFFBDC1C6),
                    ),
                  ),
                ),
              ),
            ),
            gridData: FlGridData(
              show:               true,
              drawHorizontalLine: false,
              verticalInterval:   maxRevenue == 0 ? 100 : maxRevenue / 4,
              getDrawingVerticalLine: (_) => const FlLine(
                color:       Color(0xFFF1F3F4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: items.asMap().entries.map((e) {
              final color = _barColors[e.key % _barColors.length];
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY:      e.value.revenue,
                    color:    color,
                    width:    16,
                    borderRadius: const BorderRadius.only(
                      topRight:    Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show:  true,
                      toY:   maxRevenue * 1.1,
                      color: const Color(0xFFF8F9FA),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          swapAnimationDuration: const Duration(milliseconds: 400),
          swapAnimationCurve:    Curves.easeInOut,
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
