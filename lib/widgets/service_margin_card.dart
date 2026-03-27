// lib/widgets/service_margin_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/service_stats.dart';

class ServiceMarginCard extends StatelessWidget {
  const ServiceMarginCard({
    super.key,
    required this.stats,
    required this.isAdmin,
    required this.onEditCost,
    this.rank,
  });

  final ServiceStats stats;
  final bool         isAdmin;
  final VoidCallback onEditCost;
  final int?         rank;

  @override
  Widget build(BuildContext context) {
    final margin      = stats.marginPercent.clamp(0.0, 100.0);
    final marginColor = _marginColor(margin);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: nombre + botón editar ──────────────────────────────
          Row(
            children: [
              if (rank != null) ...[
                _RankDot(rank: rank!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  stats.serviceName,
                  style: GoogleFonts.nunito(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    color:      const Color(0xFF202124),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Solo el admin puede editar el coste
              if (isAdmin)
                GestureDetector(
                  onTap: onEditCost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Editar coste',
                      style: GoogleFonts.nunito(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      const Color(0xFF4285F4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Barra de margen ───────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           margin / 100,
              minHeight:       6,
              backgroundColor: const Color(0xFFF1F3F4),
              valueColor:      AlwaysStoppedAnimation(marginColor),
            ),
          ),
          const SizedBox(height: 10),

          // ── Métricas en fila ──────────────────────────────────────────────
          Row(
            children: [
              _Metric(
                label: 'Ingresos',
                value: '€${stats.revenue.toStringAsFixed(0)}',
                color: const Color(0xFF4285F4),
              ),
              const _Divider(),
              _Metric(
                label: 'Coste mat.',
                value: stats.materialCostPerUnit == 0
                    ? '—'
                    : '€${stats.totalMaterialCost.toStringAsFixed(0)}',
                color: const Color(0xFFEA4335),
              ),
              const _Divider(),
              _Metric(
                label: 'Neto',
                value: '€${stats.netRevenue.toStringAsFixed(0)}',
                color: const Color(0xFF34A853),
              ),
              const _Divider(),
              _Metric(
                label: 'Margen',
                value: stats.materialCostPerUnit == 0
                    ? '—'
                    : '${margin.toStringAsFixed(1)}%',
                color: marginColor,
              ),
              const _Divider(),
              _Metric(
                label: 'Veces',
                value: '${stats.count}',
                color: const Color(0xFF80868B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _marginColor(double margin) {
    if (margin >= 70) return const Color(0xFF34A853);
    if (margin >= 40) return const Color(0xFFFBBC04);
    return const Color(0xFFEA4335);
  }
}

class _RankDot extends StatelessWidget {
  const _RankDot({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F0FE),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: GoogleFonts.nunito(
          fontSize:   10,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 9,
              color:    const Color(0xFFBDC1C6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 28,
      color: const Color(0xFFF1F3F4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
