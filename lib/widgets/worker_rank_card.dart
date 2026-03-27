// lib/widgets/worker_rank_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/worker_stats.dart';

class WorkerRankCard extends StatelessWidget {
  const WorkerRankCard({
    super.key,
    required this.stats,
    required this.rank,
    required this.onTap,
  });

  final WorkerStats stats;
  final int         rank;
  final VoidCallback onTap;

  static const _rankColors = [
    Color(0xFFFBBC04), // 1° oro
    Color(0xFF9AA0A6), // 2° plata
    Color(0xFFE37400), // 3° bronce
  ];

  @override
  Widget build(BuildContext context) {
    final isUp       = stats.revenueChangePercent >= 0;
    final changeColor = isUp
        ? const Color(0xFF34A853)
        : const Color(0xFFEA4335);
    final changeIcon  = isUp
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final changeStr   =
        '${isUp ? '+' : ''}${stats.revenueChangePercent.toStringAsFixed(1)}%';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            // ── Medalla de posición ─────────────────────────────────────────
            _RankBadge(rank: rank, colors: _rankColors),
            const SizedBox(width: 12),

            // ── Avatar inicial ──────────────────────────────────────────────
            _WorkerAvatar(name: stats.workerName),
            const SizedBox(width: 12),

            // ── Nombre + top servicio ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.workerName,
                    style: GoogleFonts.nunito(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      const Color(0xFF202124),
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  if (stats.topServices.isNotEmpty)
                    Text(
                      stats.topServices.first.serviceName,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color:    const Color(0xFF80868B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Ingresos + cambio % ─────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${stats.grossRevenue.toStringAsFixed(0)}',
                  style: GoogleFonts.nunito(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(changeIcon, size: 12, color: changeColor),
                    Text(
                      changeStr,
                      style: GoogleFonts.nunito(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFBDC1C6), size: 20),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.colors});
  final int         rank;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final color = rank <= 3 ? colors[rank - 1] : const Color(0xFFF1F3F4);
    final textColor = rank <= 3 ? Colors.white : const Color(0xFF80868B);

    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color:  color,
        shape:  BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: GoogleFonts.nunito(
          fontSize:   12,
          fontWeight: FontWeight.w700,
          color:      textColor,
        ),
      ),
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.name});
  final String name;

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFEA4335),
    Color(0xFFFBBC04),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color   = _colors[name.codeUnitAt(0) % _colors.length];

    return CircleAvatar(
      radius:          20,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        initial,
        style: GoogleFonts.nunito(
          fontSize:   16,
          fontWeight: FontWeight.w700,
          color:      color,
        ),
      ),
    );
  }
}
