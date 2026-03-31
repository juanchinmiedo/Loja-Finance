// lib/screens/services_screen.dart
// COMMIT 3 — show errors, retry button

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/service_stats.dart';
import '../providers/period_provider.dart';
import '../services/auth_service.dart';
import '../services/cost_service.dart';
import '../widgets/period_selector.dart';
import '../widgets/service_margin_card.dart';
import '../widgets/top_services_chart.dart';
import 'package:financas_hub_app/generated/l10n.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _costService = CostService();
  final _authService = AuthService();

  List<ServiceStats>? _services;
  String? _error;
  bool _loading = true;
  bool _isAdmin = false;
  String? _lastPeriodKey;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final admin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

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
    setState(() { _loading = true; _error = null; });
    try {
      final period   = context.read<PeriodProvider>().current;
      final services = await _costService.fetchServiceStats(period);
      if (mounted) setState(() { _services = services; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return RefreshIndicator(
      color:     const Color(0xFF4285F4),
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),
          const PeriodSelector(),
          const SizedBox(height: 20),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(
                  color: Color(0xFF4285F4), strokeWidth: 2)),
            )
          else if (_error != null)
            _buildError(_error!)
          else if (_services == null || _services!.isEmpty)
            _buildEmpty(l10n)
          else ...[
            _buildNetSummary(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top servicios por ingresos',
                      style: GoogleFonts.nunito(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF202124))),
                  const SizedBox(height: 10),
                  TopServicesChart(services: _services!),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.serviceProfitability,
                      style: GoogleFonts.nunito(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF202124))),
                  const SizedBox(height: 12),
                  ..._services!.asMap().entries.map((e) => ServiceMarginCard(
                        stats:      e.value,
                        isAdmin:    _isAdmin,
                        rank:       e.key + 1,
                        onEditCost: () => _showEditCostSheet(e.value),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetSummary() {
    final s         = _services!;
    final totalGross = s.fold<double>(0, (sum, st) => sum + st.revenue);
    final totalCost  = s.fold<double>(0, (sum, st) => sum + st.totalMaterialCost);
    final totalNet   = totalGross - totalCost;
    final hasCosts   = totalCost > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: _SummaryCol(label: 'Ingresos brutos',
                value: '€${totalGross.toStringAsFixed(0)}',
                color: const Color(0xFF185FA5))),
            if (hasCosts) ...[
              const _VSep(),
              Expanded(child: _SummaryCol(label: 'Coste total',
                  value: '€${totalCost.toStringAsFixed(0)}',
                  color: const Color(0xFFC5221F))),
              const _VSep(),
              Expanded(child: _SummaryCol(label: 'Beneficio neto',
                  value: '€${totalNet.toStringAsFixed(0)}',
                  color: const Color(0xFF1E7E34))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCostSheet(ServiceStats service) async {
    final controller = TextEditingController(
      text: service.materialCostPerUnit == 0
          ? '' : service.materialCostPerUnit.toStringAsFixed(2),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE8EAED),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Coste de material', style: GoogleFonts.nunito(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: const Color(0xFF202124))),
            const SizedBox(height: 4),
            Text(service.serviceName, style: GoogleFonts.nunito(
                fontSize: 14, color: const Color(0xFF5F6368))),
            const SizedBox(height: 20),
            TextField(
              controller:   controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus:    true,
              decoration: InputDecoration(
                labelText:   'Coste por sesión (€)',
                labelStyle:  GoogleFonts.nunito(color: const Color(0xFF5F6368)),
                prefixText:  '€ ',
                prefixStyle: GoogleFonts.nunito(
                    color: const Color(0xFF202124), fontWeight: FontWeight.w600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADCE0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2)),
                hintText:  '0.00',
                hintStyle: GoogleFonts.nunito(color: const Color(0xFFBDC1C6)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8EAED))),
              child: Text(
                'Este coste se aplica a todas las sesiones de '
                '"${service.serviceName}" para calcular el beneficio neto.',
                style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF5F6368)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (service.materialCostPerUnit > 0) ...[
                  Expanded(child: OutlinedButton(
                    onPressed: () async {
                      await _costService.deleteCost(service.serviceId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEA4335)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text('Eliminar', style: GoogleFonts.nunito(
                        color: const Color(0xFFEA4335), fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(width: 12),
                ],
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    final val = double.tryParse(
                        controller.text.replaceAll(',', '.')) ?? 0;
                    await _costService.saveCost(
                      serviceId:   service.serviceId,
                      serviceName: service.serviceName,
                      costPerUnit: val,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Guardar', style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600)),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEA4335)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Error al cargar servicios',
              style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF80868B)),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _load,
          child: Text('Reintentar', style: GoogleFonts.nunito(color: const Color(0xFF4285F4))),
        ),
      ]),
    ));
  }

  Widget _buildEmpty(S l10n) {
    return Center(child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        const Icon(Icons.spa_outlined, size: 48, color: Color(0xFFBDC1C6)),
        const SizedBox(height: 12),
        Text(l10n.noData, style: GoogleFonts.nunito(
            fontSize: 14, color: const Color(0xFF80868B))),
      ]),
    ));
  }
}

class _SummaryCol extends StatelessWidget {
  const _SummaryCol({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.nunito(
        fontSize: 10, color: const Color(0xFF5F6368))),
  ]);
}

class _VSep extends StatelessWidget {
  const _VSep();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 36, color: const Color(0xFFCEEAD6),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}
