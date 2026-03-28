// lib/widgets/revenue_chart.dart
// COMMIT 1 — remove onActiveWorkersChanged (base selector now lives in home_screen)
//            comparator only manages additional overlay lines
//            para que los KPI cards se actualicen por worker

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/kpi_data.dart';
import '../models/period.dart';

class CompareSeries {
  final String             id;
  final String             label;
  final Color              color;
  final List<RevenuePoint> points;
  final String             type; // 'worker' | 'service' | 'period'
  const CompareSeries({
    required this.id,
    required this.label,
    required this.color,
    required this.points,
    required this.type,
  });
}

class CompareOption {
  final String id;
  final String label;
  const CompareOption({required this.id, required this.label});
}

class RevenueChart extends StatefulWidget {
  const RevenueChart({
    super.key,
    required this.points,
    this.isLoading        = false,
    this.activePeriod,
    this.workerOptions    = const [],
    this.serviceOptions   = const [],
    this.onFetchSeries,
    this.onFetchPeriodSeries,
  });

  final List<RevenuePoint>                           points;
  final bool                                         isLoading;
  final Period?                                      activePeriod;
  final List<CompareOption>                          workerOptions;
  final List<CompareOption>                          serviceOptions;
  final Future<List<RevenuePoint>> Function(String id, String type)? onFetchSeries;
  final Future<List<RevenuePoint>> Function(Period period)?          onFetchPeriodSeries;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _touchedIndex;

  final Map<String, CompareSeries> _activeSeries = {};
  final Set<String> _loadingIds = {};

  static const _palette = [
    Color(0xFF34A853),
    Color(0xFFEA4335),
    Color(0xFFFBBC04),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF6D00),
  ];

  late final List<Color> _availableColors = List.from(_palette);

  Color _pickColor() {
    if (_availableColors.isEmpty) {
      final inUse = _activeSeries.values.map((s) => s.color).toSet();
      _availableColors.addAll(_palette.where((c) => !inUse.contains(c)));
      if (_availableColors.isEmpty) _availableColors.addAll(_palette);
    }
    return _availableColors.removeAt(0);
  }

  void _returnColor(Color color) {
    if (!_availableColors.contains(color)) _availableColors.insert(0, color);
  }


  Future<void> _toggleSeries(String id, String label, String type) async {
    if (_activeSeries.containsKey(id)) {
      setState(() {
        _returnColor(_activeSeries[id]!.color);
        _activeSeries.remove(id);
      });
      return;
    }
    if (widget.onFetchSeries == null) return;

    final color = _pickColor();
    setState(() => _loadingIds.add(id));
    try {
      final pts = await widget.onFetchSeries!(id, type);
      if (mounted) {
        setState(() {
          _activeSeries[id] = CompareSeries(
              id: id, label: label, color: color, points: pts, type: type);
          _loadingIds.remove(id);
        });
      }
    } catch (_) {
      if (mounted) {
        _returnColor(color);
        setState(() => _loadingIds.remove(id));
      }
    }
  }

  Future<void> _comparePeriod(BuildContext context) async {
    final now    = DateTime.now();
    final result = await showDateRangePicker(
      context:   context,
      firstDate: DateTime(now.year - 3),
      lastDate:  now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4285F4), onPrimary: Colors.white, surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (result == null || widget.onFetchPeriodSeries == null) return;

    final period = Period.custom(result.start, result.end);
    final id     = 'period_${result.start.millisecondsSinceEpoch}';
    final label  = '${DateFormat('dd/MM').format(result.start)}–'
                   '${DateFormat('dd/MM/yy').format(result.end)}';

    if (_activeSeries.containsKey(id)) {
      setState(() { _returnColor(_activeSeries[id]!.color); _activeSeries.remove(id); });
      return;
    }

    final color = _pickColor();
    setState(() => _loadingIds.add(id));
    try {
      final pts = await widget.onFetchPeriodSeries!(period);
      if (mounted) {
        setState(() {
          _activeSeries[id] = CompareSeries(
              id: id, label: label, color: color, points: pts, type: 'period');
          _loadingIds.remove(id);
        });
      }
    } catch (_) {
      if (mounted) { _returnColor(color); setState(() => _loadingIds.remove(id)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: const Color(0xFFE8EAED)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: widget.isLoading
              ? const SizedBox(height: 180,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4))))
              : SizedBox(height: 180, child: LineChart(_buildChart())),
        ),

        const SizedBox(height: 12),

        if (_activeSeries.isNotEmpty) ...[
          Wrap(
            spacing: 8, runSpacing: 4,
            children: [
              _LegendChip(label: 'Total salón', color: const Color(0xFF4285F4), onRemove: null),
              ..._activeSeries.values.map((s) => _LegendChip(
                    label: s.label, color: s.color,
                    onRemove: () => setState(() { _returnColor(s.color); _activeSeries.remove(s.id); }),
                  )),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (widget.workerOptions.isNotEmpty) ...[
          _SectionLabel(label: 'Workers'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.workerOptions.map((opt) {
                final isActive  = _activeSeries.containsKey(opt.id);
                final isLoading = _loadingIds.contains(opt.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CompareChip(
                    label: opt.label, isActive: isActive, isLoading: isLoading,
                    color: isActive ? _activeSeries[opt.id]!.color : const Color(0xFF4285F4),
                    onTap: () => _toggleSeries(opt.id, opt.label, 'worker'),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (widget.serviceOptions.isNotEmpty) ...[
          _SectionLabel(label: 'Servicios'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.serviceOptions.map((opt) {
                final isActive  = _activeSeries.containsKey(opt.id);
                final isLoading = _loadingIds.contains(opt.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CompareChip(
                    label: opt.label, isActive: isActive, isLoading: isLoading,
                    color: isActive ? _activeSeries[opt.id]!.color : const Color(0xFF34A853),
                    onTap: () => _toggleSeries(opt.id, opt.label, 'service'),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (widget.onFetchPeriodSeries != null)
          GestureDetector(
            onTap: () => _comparePeriod(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:        const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: const Color(0xFFE8EAED)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14, color: Color(0xFF5F6368)),
                  const SizedBox(width: 6),
                  Text('Comparar período',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF5F6368))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  LineChartData _buildChart() {
    final basePts = widget.points;
    if (basePts.isEmpty) {
      return LineChartData(
        lineBarsData: [], titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false), gridData: const FlGridData(show: false),
      );
    }

    double maxY = basePts.fold<double>(0, (a, b) => a > b.revenue ? a : b.revenue);
    for (final s in _activeSeries.values) {
      final m = s.points.fold<double>(0, (a, b) => a > b.revenue ? a : b.revenue);
      if (m > maxY) maxY = m;
    }
    if (maxY == 0) maxY = 100;

    return LineChartData(
      minX: 0, maxX: (basePts.length - 1).toDouble(), minY: 0, maxY: maxY * 1.2,
      lineTouchData: LineTouchData(
        touchCallback: (event, response) =>
            setState(() => _touchedIndex = response?.lineBarSpots?.first.spotIndex),
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF202124),
          getTooltipItems: (spots) => spots.asMap().entries.map((e) {
            final idx  = e.key;
            final spot = e.value;
            final pt   = basePts[spot.spotIndex];
            final label = idx == 0 ? 'Total'
                : (idx - 1 < _activeSeries.length
                    ? _activeSeries.values.toList()[idx - 1].label : '');
            return LineTooltipItem(
              idx == 0 ? '${_formatTooltipDate(pt.month)}\n' : '',
              GoogleFonts.nunito(color: Colors.white70, fontSize: 10),
              children: [TextSpan(
                text: '$label  €${spot.y.toStringAsFixed(0)}\n',
                style: GoogleFonts.nunito(color: spot.bar.color, fontSize: 12, fontWeight: FontWeight.w700),
              )],
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true, drawVerticalLine: false, horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F3F4), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 48, interval: maxY / 4,
          getTitlesWidget: (v, _) => Text('€${_compact(v)}',
              style: GoogleFonts.nunito(fontSize: 10, color: const Color(0xFFBDC1C6))),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          interval: _bottomInterval(basePts.length),
          getTitlesWidget: (value, _) {
            final idx = value.toInt();
            if (idx < 0 || idx >= basePts.length) return const SizedBox.shrink();
            return Text(_formatBottomLabel(basePts[idx].month),
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: idx == _touchedIndex ? FontWeight.w700 : FontWeight.w400,
                  color: idx == _touchedIndex ? const Color(0xFF4285F4) : const Color(0xFFBDC1C6),
                ));
          },
        )),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        _buildBar(basePts, const Color(0xFF4285F4)),
        ..._activeSeries.values.map((s) => _buildBar(s.points, s.color)),
      ],
    );
  }

  LineChartBarData _buildBar(List<RevenuePoint> pts, Color color) {
    return LineChartBarData(
      spots: pts.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(),
      isCurved: true, curveSmoothness: 0.35,
      color: color, barWidth: 2.5, isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, _) => spot.x.toInt() == _touchedIndex,
        getDotPainter: (_, __, ___, ____) =>
            FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: Colors.white),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.10), color.withOpacity(0.0)],
        ),
      ),
    );
  }

  String _formatTooltipDate(DateTime dt) {
    switch (widget.activePeriod?.type ?? PeriodType.month) {
      case PeriodType.day:  return DateFormat('dd MMM').format(dt);
      case PeriodType.week: return DateFormat('dd/MM').format(dt);
      case PeriodType.year: return DateFormat('yyyy').format(dt);
      default:              return DateFormat('MMM yyyy').format(dt);
    }
  }

  String _formatBottomLabel(DateTime dt) {
    switch (widget.activePeriod?.type ?? PeriodType.month) {
      case PeriodType.day:  return DateFormat('dd/MM').format(dt);
      case PeriodType.week: return DateFormat('dd/MM').format(dt);
      case PeriodType.year: return DateFormat('yyyy').format(dt);
      default:              return DateFormat('MMM').format(dt);
    }
  }

  double _bottomInterval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    return (count / 6).ceilToDouble();
  }

  String _compact(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF80868B), letterSpacing: 0.5));
}

class _CompareChip extends StatelessWidget {
  const _CompareChip({
    required this.label, required this.isActive, required this.isLoading,
    required this.color, required this.onTap,
  });
  final String label; final bool isActive; final bool isLoading;
  final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        isActive ? color.withOpacity(0.12) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: isActive ? color : const Color(0xFFE8EAED), width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
            else
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? color : const Color(0xFFBDC1C6))),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : const Color(0xFF5F6368))),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color, required this.onRemove});
  final String label; final Color color; final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.9))),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 12, color: color.withOpacity(0.7))),
          ],
        ],
      ),
    );
  }
}
