// lib/widgets/period_selector.dart
// COMMIT 3 — Día/Semana/Mes/Año; quita Personalizado; añade botón de rango custom

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/period.dart';
import '../providers/period_provider.dart';
import 'package:financas_hub_app/generated/l10n.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n     = S.of(context);
    final provider = context.watch<PeriodProvider>();
    final current  = provider.current.type;

    // Tabs principales: Día · Semana · Mes · Año
    final tabs = [
      (PeriodType.day,   l10n.periodDay),
      (PeriodType.week,  l10n.periodWeek),
      (PeriodType.month, l10n.periodMonth),
      (PeriodType.year,  l10n.periodYear),
    ];

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // Tabs desplazables
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (type, label) = tabs[i];
                final isActive = current == type;
                return _PeriodPill(
                  label:    label,
                  isActive: isActive,
                  onTap: () {
                    switch (type) {
                      case PeriodType.day:   provider.selectDay();   break;
                      case PeriodType.week:  provider.selectWeek();  break;
                      case PeriodType.month: provider.selectMonth(); break;
                      case PeriodType.year:  provider.selectYear();  break;
                      case PeriodType.custom: break;
                    }
                  },
                );
              },
            ),
          ),

          // Botón de rango personalizado (icono calendario)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: _CustomRangeButton(
              isActive: current == PeriodType.custom,
              onTap:    () => _showDateRangePicker(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker(
    BuildContext context,
    PeriodProvider provider,
  ) async {
    final now    = DateTime.now();
    final result = await showDateRangePicker(
      context:   context,
      firstDate: DateTime(now.year - 3),
      lastDate:  now,
      initialDateRange: DateTimeRange(
        start: provider.current.from,
        end:   provider.current.to.subtract(const Duration(days: 1)),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   Color(0xFF4285F4),
            onPrimary: Colors.white,
            surface:   Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      provider.selectCustom(result.start, result.end);
    }
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String     label;
  final bool       isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        isActive ? const Color(0xFF4285F4) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize:   13,
            fontWeight: FontWeight.w600,
            color:      isActive ? Colors.white : const Color(0xFF5F6368),
          ),
        ),
      ),
    );
  }
}

class _CustomRangeButton extends StatelessWidget {
  const _CustomRangeButton({
    required this.isActive,
    required this.onTap,
  });

  final bool         isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width:  36,
        height: 36,
        decoration: BoxDecoration(
          color:        isActive ? const Color(0xFF4285F4) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.calendar_month_outlined,
          size:  18,
          color: isActive ? Colors.white : const Color(0xFF5F6368),
        ),
      ),
    );
  }
}
