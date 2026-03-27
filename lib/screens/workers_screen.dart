// lib/screens/workers_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/worker_stats.dart';
import '../providers/period_provider.dart';
import '../services/worker_service.dart';
import '../widgets/period_selector.dart';
import '../widgets/worker_rank_card.dart';
import 'workers/worker_detail_screen.dart';
import 'package:financas_hub_app/generated/l10n.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final _service = WorkerService();

  List<WorkerStats>? _workers;
  bool _loading = true;
  String? _lastPeriodKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final period    = context.watch<PeriodProvider>().current;
    final periodKey = '${period.from}${period.to}';
    if (_lastPeriodKey != periodKey) {
      _lastPeriodKey = periodKey;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final period  = context.read<PeriodProvider>().current;
      final workers = await _service.fetchAllWorkers(period);
      if (mounted) setState(() { _workers = workers; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return RefreshIndicator(
      color:     const Color(0xFF4285F4),
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),
          const PeriodSelector(),
          const SizedBox(height: 20),

          if (_workers != null && _workers!.isNotEmpty)
            _buildSummaryHeader(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _loading
                ? _buildSkeleton()
                : _workers == null || _workers!.isEmpty
                    ? _buildEmpty(l10n)
                    : _buildList(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final total = _workers!.fold<double>(0, (s, w) => s + w.grossRevenue);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_rounded, color: Color(0xFF4285F4), size: 20),
            const SizedBox(width: 10),
            Text('${_workers!.length} workers · ',
                style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF185FA5), fontWeight: FontWeight.w500)),
            Text('Total €${total.toStringAsFixed(0)}',
                style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF185FA5), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.workerRanking,
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF202124))),
        const SizedBox(height: 12),
        ...(_workers!.asMap().entries.map((e) => WorkerRankCard(
              stats: e.value,
              rank:  e.key + 1,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => WorkerDetailScreen(
                        initialStats: e.value,
                        workerId:     e.value.workerId,
                      ))),
            ))),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(4, (_) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(12),
        ),
      )),
    );
  }

  Widget _buildEmpty(S l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.people_outline, size: 48, color: Color(0xFFBDC1C6)),
            const SizedBox(height: 12),
            Text(l10n.noData, style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF80868B))),
          ],
        ),
      ),
    );
  }
}
