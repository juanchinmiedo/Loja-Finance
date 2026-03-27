// lib/widgets/kpi_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.changePercent,   // null = no mostrar flecha
    this.subtitle,
    this.accentColor = const Color(0xFF4285F4),
    this.icon,
  });

  final String  label;
  final String  value;
  final double? changePercent;
  final String? subtitle;
  final Color   accentColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color:       Colors.black.withOpacity(0.04),
            blurRadius:  8,
            offset:      const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: icono + label ────────────────────────────────────────
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize:   12,
                    fontWeight: FontWeight.w500,
                    color:      const Color(0xFF80868B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Valor principal ───────────────────────────────────────────────
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize:   22,
              fontWeight: FontWeight.w700,
              color:      const Color(0xFF202124),
              height:     1.1,
            ),
          ),

          // ── Cambio % vs período anterior ──────────────────────────────────
          if (changePercent != null) ...[
            const SizedBox(height: 6),
            _ChangeChip(percent: changePercent!),
          ],

          // ── Subtítulo opcional ────────────────────────────────────────────
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color:    const Color(0xFFBDC1C6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final isUp    = percent >= 0;
    final color   = isUp ? const Color(0xFF34A853) : const Color(0xFFEA4335);
    final bgColor = isUp
        ? const Color(0xFFE6F4EA)
        : const Color(0xFFFCE8E6);
    final icon    = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    final text    = '${isUp ? '+' : ''}${percent.toStringAsFixed(1)}%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 2),
              Text(
                text,
                style: GoogleFonts.nunito(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'vs anterior',
          style: GoogleFonts.nunito(
            fontSize: 11,
            color:    const Color(0xFFBDC1C6),
          ),
        ),
      ],
    );
  }
}
