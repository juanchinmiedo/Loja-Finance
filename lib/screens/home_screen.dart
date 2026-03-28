// lib/screens/home_screen.dart
// COMMIT 1 — Base selector: Total salón / workers como fuente de KPIs y línea principal
//            El comparador debajo de la gráfica sigue igual para líneas adicionales

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/kpi_data.dart';
import '../models/period.dart';
import '../providers/period_provider.dart';
import '../services/auth_service.dart';
import '../services/finance_service.dart';
import '../services/worker_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/revenue_chart.dart';
import 'package:financas_hub_app/generated/l10n.dart';

import 'workers_screen.dart';
import 'services_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PeriodProvider())],
      child: _HomeShell(user: user),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.user});
  final User user;
  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n    = S.of(context);
    final screens = [const _DashboardTab(), const WorkersScreen(), const ServicesScreen()];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar:              _buildAppBar(context, l10n),
      body:                screens[_tab],
      bottomNavigationBar: _buildBottomNav(context, l10n),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, S l10n) {
    return AppBar(
      backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFE8EAED)),
            ),
            child: const _MiniLogo(),
          ),
          const SizedBox(width: 10),
          Text(l10n.appTitle,
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF202124))),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _showSignOutDialog(context, l10n),
            child: CircleAvatar(
              radius: 16, backgroundColor: const Color(0xFF4285F4),
              backgroundImage:
                  widget.user.photoURL != null ? NetworkImage(widget.user.photoURL!) : null,
              child: widget.user.photoURL == null
                  ? Text((widget.user.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  NavigationBar _buildBottomNav(BuildContext context, S l10n) {
    return NavigationBar(
      backgroundColor: Colors.white,
      indicatorColor:  const Color(0xFFE8F0FE),
      selectedIndex:   _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart, color: Color(0xFF4285F4)),
            label: l10n.navDashboard),
        NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people, color: Color(0xFF4285F4)),
            label: l10n.navWorkers),
        NavigationDestination(
            icon: const Icon(Icons.spa_outlined),
            selectedIcon: const Icon(Icons.spa, color: Color(0xFF4285F4)),
            label: l10n.navServices),
      ],
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, S l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   Text(l10n.signOut, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
        content: Text('¿Cerrar sesión de ${widget.user.email}?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.signOut,
                  style: const TextStyle(color: Color(0xFFEA4335)))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await AuthService().signOut();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashboard Tab
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _financeService = FinanceService();
  final _workerService  = WorkerService();

  // ── Estado del selector de base ───────────────────────────────────────────
  // null = Total salón, String = workerId seleccionado
  String? _baseWorkerId;

  // KPIs y puntos de la base seleccionada
  KpiSummary?         _kpi;
  List<RevenuePoint>? _chartPoints;
  bool _kpiLoading   = true;
  bool _chartLoading = true;

  // Lista de workers para el selector de base
  List<CompareOption> _workerOptions  = [];
  // Lista de servicios para el comparador
  List<CompareOption> _serviceOptions = [];

  Period? _lastPeriod;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final period = context.watch<PeriodProvider>().current;
    if (_lastPeriod == null ||
        _lastPeriod!.from != period.from ||
        _lastPeriod!.to   != period.to   ||
        _lastPeriod!.type != period.type) {
      _lastPeriod = period;
      _loadData(period);
    }
  }

  Future<void> _loadData(Period period) async {
    setState(() { _kpiLoading = true; _chartLoading = true; });
    await Future.wait([
      _loadKpiAndChart(period),
      _loadCompareOptions(period),
    ]);
  }

  Future<void> _loadKpiAndChart(Period period) async {
    try {
      final kpi = await _financeService.fetchKpiSummary(period, workerId: _baseWorkerId);
      if (mounted) setState(() { _kpi = kpi; _kpiLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _kpiLoading = false);
    }

    try {
      final pts = await _financeService.fetchChartPoints(period, workerId: _baseWorkerId);
      if (mounted) setState(() { _chartPoints = pts; _chartLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  Future<void> _loadCompareOptions(Period period) async {
    try {
      final workers = await _workerService.fetchAllWorkers(period);
      if (mounted) {
        setState(() {
          _workerOptions = workers
              .map((w) => CompareOption(id: w.workerId, label: w.workerName))
              .toList();
        });
      }
    } catch (_) {}

    try {
      final top = await _financeService.fetchTopServices(period, limit: 8);
      if (mounted) {
        setState(() {
          _serviceOptions = top
              .map((s) => CompareOption(id: s.id, label: s.name))
              .toList();
        });
      }
    } catch (_) {}
  }

  // Cambia la base: null = salón, workerId = worker concreto
  Future<void> _selectBase(String? workerId) async {
    if (_baseWorkerId == workerId) return;
    setState(() {
      _baseWorkerId  = workerId;
      _kpiLoading    = true;
      _chartLoading  = true;
    });
    await _loadKpiAndChart(_lastPeriod!);
  }

  // Callbacks para el comparador (líneas adicionales)
  Future<List<RevenuePoint>> _fetchCompareSeries(String id, String type) {
    final period = context.read<PeriodProvider>().current;
    if (type == 'worker') return _financeService.fetchChartPoints(period, workerId: id);
    return _financeService.fetchChartPoints(period);
  }

  Future<List<RevenuePoint>> _fetchPeriodSeries(Period period) =>
      _financeService.fetchChartPoints(period, workerId: _baseWorkerId);

  @override
  Widget build(BuildContext context) {
    final l10n   = S.of(context);
    final period = context.watch<PeriodProvider>().current;

    return RefreshIndicator(
      color:     const Color(0xFF4285F4),
      onRefresh: () async {
        _chartPoints = null;
        _workerOptions  = [];
        _serviceOptions = [];
        await _loadData(context.read<PeriodProvider>().current);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),

          // ── Period selector ────────────────────────────────────────────────
          const PeriodSelector(),
          const SizedBox(height: 12),

          // ── Base selector: Total salón + workers ───────────────────────────
          _buildBaseSelector(),
          const SizedBox(height: 20),

          // ── KPI cards ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _kpiLoading ? const _KpiSkeleton() : _buildKpiGrid(l10n),
          ),
          const SizedBox(height: 20),

          // ── Gráfica + comparador ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chartTitle(period.type),
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: const Color(0xFF202124)),
                ),
                const SizedBox(height: 10),
                RevenueChart(
                  points:              _chartPoints ?? [],
                  isLoading:           _chartLoading,
                  activePeriod:        period,
                  // El comparador no incluye el worker base (ya es la línea principal)
                  workerOptions:       _workerOptions
                      .where((w) => w.id != _baseWorkerId)
                      .toList(),
                  serviceOptions:      _serviceOptions,
                  onFetchSeries:       _fetchCompareSeries,
                  onFetchPeriodSeries: _fetchPeriodSeries,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Base selector widget ──────────────────────────────────────────────────

  Widget _buildBaseSelector() {
    if (_workerOptions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Chip "Total salón" (siempre primero)
          _BaseChip(
            label:    'Total salón',
            isActive: _baseWorkerId == null,
            color:    const Color(0xFF4285F4),
            onTap:    () => _selectBase(null),
          ),
          const SizedBox(width: 8),
          // Un chip por worker
          ..._workerOptions.map((w) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _BaseChip(
              label:    w.label,
              isActive: _baseWorkerId == w.id,
              color:    const Color(0xFF4285F4),
              onTap:    () => _selectBase(w.id),
            ),
          )),
        ],
      ),
    );
  }

  // ── Chart title ───────────────────────────────────────────────────────────

  String _chartTitle(PeriodType type) {
    final base = _baseWorkerId == null
        ? 'salón'
        : (_workerOptions.firstWhere((w) => w.id == _baseWorkerId,
                orElse: () => const CompareOption(id: '', label: 'worker'))
            .label);
    switch (type) {
      case PeriodType.day:   return 'Últimos 12 días — $base';
      case PeriodType.week:  return 'Últimas 12 semanas — $base';
      case PeriodType.year:  return 'Últimos 12 años — $base';
      default:               return 'Últimos 12 meses — $base';
    }
  }

  // ── KPI grid ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(S l10n) {
    final kpi = _kpi ?? KpiSummary.empty();
    return Column(
      children: [
        Row(children: [
          Expanded(child: KpiCard(
              label: l10n.kpiGrossRevenue,
              value: '€${kpi.grossRevenue.toStringAsFixed(0)}',
              changePercent: kpi.revenueChangePercent,
              icon: Icons.euro_rounded,
              accentColor: const Color(0xFF4285F4))),
          const SizedBox(width: 12),
          Expanded(child: KpiCard(
              label: l10n.kpiNetRevenue,
              value: '€${kpi.netRevenue.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
              accentColor: const Color(0xFF34A853))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: KpiCard(
              label: l10n.kpiAvgTicket,
              value: '€${kpi.avgTicket.toStringAsFixed(0)}',
              icon: Icons.receipt_outlined,
              accentColor: const Color(0xFFFBBC04))),
          const SizedBox(width: 12),
          Expanded(child: KpiCard(
              label: l10n.kpiOccupancyRate,
              value: '${kpi.occupancyRate.toStringAsFixed(1)}%',
              icon: Icons.calendar_today_outlined,
              accentColor: const Color(0xFF4285F4))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: KpiCard(
              label: l10n.kpiCompletedAppointments,
              value: '${kpi.completedCount}',
              icon: Icons.check_circle_outline,
              accentColor: const Color(0xFF34A853))),
          const SizedBox(width: 12),
          Expanded(child: KpiCard(
              label: l10n.kpiCancelledAppointments,
              value: '${kpi.cancelledCount + kpi.noShowCount}',
              icon: Icons.cancel_outlined,
              accentColor: const Color(0xFFEA4335))),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Base selector chip — estilo distinto al comparador:
//  activo = fondo azul sólido, inactivo = pill gris outline
// ─────────────────────────────────────────────────────────────────────────────

class _BaseChip extends StatelessWidget {
  const _BaseChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final String     label;
  final bool       isActive;
  final Color      color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? color : const Color(0xFFDADCE0),
            width: isActive ? 0 : 1,
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Skeleton + MiniLogo
// ─────────────────────────────────────────────────────────────────────────────

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: _SkeletonBox(height: 84)),
          const SizedBox(width: 12),
          Expanded(child: _SkeletonBox(height: 84)),
        ]),
      )),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(12)),
  );
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MiniLogoPainter());
}

class _MiniLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final barW = w * 0.16; final baseY = h * 0.92;
    final rx = const Radius.circular(1.5);
    void bar(double x, double bh, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, baseY - bh, barW, bh), rx),
        Paint()..color = c,
      );
    }
    bar(w * 0.05, h * 0.28, const Color(0xFF4285F4));
    bar(w * 0.26, h * 0.42, const Color(0xFF34A853));
    bar(w * 0.47, h * 0.32, const Color(0xFFFBBC04));
    bar(w * 0.68, h * 0.55, const Color(0xFFEA4335));
    final cc = Offset(w * 0.72, h * 0.36);
    final r  = w * 0.24;
    canvas.drawCircle(cc, r + 1.5, Paint()..color = Colors.white);
    canvas.drawCircle(cc, r,       Paint()..color = const Color(0xFF4285F4));
    canvas.drawCircle(cc, r * 0.6, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_MiniLogoPainter _) => false;
}
