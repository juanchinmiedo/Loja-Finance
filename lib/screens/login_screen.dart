// lib/screens/login_screen.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import 'package:financas_hub_app/generated/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Mini-card data (se carga de Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStats {
  final double grossRevenue;   // ingresos brutos del mes actual
  final double changePercent;  // % vs mes anterior
  final int    completedCount; // citas completadas este mes
  final double occupancyRate;  // % ocupación (completadas / totales)

  const _MiniStats({
    required this.grossRevenue,
    required this.changePercent,
    required this.completedCount,
    required this.occupancyRate,
  });
}

Future<_MiniStats> _loadMiniStats() async {
  final db  = FirebaseFirestore.instance;
  final now = DateTime.now();

  final firstDayThisMonth  = DateTime(now.year, now.month, 1);
  final firstDayLastMonth  = DateTime(now.year, now.month - 1, 1);
  final firstDayNextMonth  = DateTime(now.year, now.month + 1, 1);

  // Rango del mes actual
  final snap = await db
      .collection('appointments')
      .where('appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayThisMonth))
      .where('appointmentDate',
          isLessThan: Timestamp.fromDate(firstDayNextMonth))
      .get();

  // Rango del mes anterior
  final snapPrev = await db
      .collection('appointments')
      .where('appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayLastMonth))
      .where('appointmentDate',
          isLessThan: Timestamp.fromDate(firstDayThisMonth))
      .get();

  double thisRevenue = 0;
  double prevRevenue = 0;
  int    completed   = 0;
  int    total       = snap.docs.length;

  for (final doc in snap.docs) {
    final data   = doc.data();
    final status = data['status'] ?? '';
    final price  = (data['finalPrice'] ?? data['basePrice'] ?? 0).toDouble();
    if (status == 'done' || status == 'scheduled') {
      thisRevenue += price;
    }
    if (status == 'done') completed++;
  }

  for (final doc in snapPrev.docs) {
    final data   = doc.data();
    final status = data['status'] ?? '';
    final price  = (data['finalPrice'] ?? data['basePrice'] ?? 0).toDouble();
    if (status == 'done' || status == 'scheduled') {
      prevRevenue += price;
    }
  }

  final change     = prevRevenue == 0
      ? 0.0
      : ((thisRevenue - prevRevenue) / prevRevenue) * 100;
  final occupancy  = total == 0 ? 0.0 : (completed / total) * 100;

  return _MiniStats(
    grossRevenue:  thisRevenue,
    changePercent: change,
    completedCount: completed,
    occupancyRate: occupancy,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  LoginScreen
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();

  bool    _loading      = false;
  String? _errorMessage;

  // Mini-stats
  _MiniStats? _stats;
  bool        _statsLoading = true;

  // Animaciones
  late final AnimationController _chartCtrl;   // línea de fondo
  late final AnimationController _pulseCtrl;   // logo pulse
  late final AnimationController _fadeCtrl;    // fade in de la UI

  late final Animation<double> _chartOffset;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _chartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _chartOffset = Tween<double>(begin: 0, end: -400).animate(
      CurvedAnimation(parent: _chartCtrl, curve: Curves.linear),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _loadMiniStats();
      if (mounted) setState(() { _stats = stats; _statsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  void dispose() {
    _chartCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Sign in ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final l10n = S.of(context);
    setState(() { _loading = true; _errorMessage = null; });

    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _loading      = false;
          _errorMessage = l10n.loginErrorUnauthorized;
        });
      }
      // Si user != null → _AuthGate navega sola vía authStateChanges
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading      = false;
        _errorMessage = e.code == 'network-request-failed'
            ? l10n.loginErrorNetwork
            : l10n.loginErrorGeneric(e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading      = false;
        _errorMessage = l10n.loginErrorGeneric(e.toString());
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Línea de cotización animada (fondo inferior) ──────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: AnimatedBuilder(
              animation: _chartOffset,
              builder: (_, __) => CustomPaint(
                painter: _ChartLinePainter(offset: _chartOffset.value),
              ),
            ),
          ),

          // ── Contenido principal ───────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo animado
                    ScaleTransition(
                      scale: _pulse,
                      child: const _FinancasLogo(size: 96),
                    ),

                    const SizedBox(height: 28),

                    // Título
                    Text(
                      l10n.appTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF202124),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.loginSubtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF5F6368),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Mini-cards
                    _buildMiniCards(l10n),

                    const SizedBox(height: 28),

                    // Error
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE8E6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFEA4335).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFEA4335), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.nunito(
                                  color: const Color(0xFFEA4335),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botón Google
                    _loading
                        ? _buildLoadingButton(l10n)
                        : _buildSignInButton(l10n),

                    const SizedBox(height: 16),

                    Text(
                      l10n.loginFooter,
                      style: GoogleFonts.nunito(
                        color: const Color(0xFFBDC1C6),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini-cards ─────────────────────────────────────────────────────────────

  Widget _buildMiniCards(S l10n) {
    if (_statsLoading) {
      return const SizedBox(
        height: 64,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF4285F4),
          ),
        ),
      );
    }

    final s = _stats;
    final changeStr = s == null
        ? '--'
        : '${s.changePercent >= 0 ? '+' : ''}${s.changePercent.toStringAsFixed(1)}%';
    final changeColor = (s?.changePercent ?? 0) >= 0
        ? const Color(0xFF34A853)
        : const Color(0xFFEA4335);

    final revenueStr = s == null
        ? '--'
        : '€${s.grossRevenue.toStringAsFixed(0)}';

    final occupancyStr = s == null
        ? '--'
        : '${s.occupancyRate.toStringAsFixed(0)}%';

    return Row(
      children: [
        _MiniCard(
          value: changeStr,
          label: l10n.miniCardMonth,
          valueColor: changeColor,
        ),
        const SizedBox(width: 10),
        _MiniCard(
          value: revenueStr,
          label: l10n.miniCardRevenue,
          valueColor: const Color(0xFF4285F4),
        ),
        const SizedBox(width: 10),
        _MiniCard(
          value: occupancyStr,
          label: l10n.miniCardOccupancy,
          valueColor: const Color(0xFFFBBC04),
        ),
      ],
    );
  }

  // ── Botones ────────────────────────────────────────────────────────────────

  Widget _buildSignInButton(S l10n) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleLogoWidget(),
            const SizedBox(width: 12),
            Text(
              l10n.loginButton,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingButton(S l10n) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.loginVerifying,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5F6368),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mini-card widget
// ─────────────────────────────────────────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color  valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: const Color(0xFF80868B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logo CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _FinancasLogo extends StatelessWidget {
  const _FinancasLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Barras de colores Google ──────────────────────────────────────────────
    final barW  = w * 0.135;
    final baseY = h * 0.92;
    final rx    = const Radius.circular(3);

    void drawBar(double x, double barH, Color color) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - barH, barW, barH),
        rx,
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }

    drawBar(w * 0.08,  h * 0.26, const Color(0xFF4285F4)); // azul
    drawBar(w * 0.24,  h * 0.38, const Color(0xFF34A853)); // verde
    drawBar(w * 0.40,  h * 0.30, const Color(0xFFFBBC04)); // amarillo
    drawBar(w * 0.56,  h * 0.50, const Color(0xFFEA4335)); // rojo

    // ── Círculo exterior de la lupa (borde blanco para separar de las barras) ─
    final lupaCenter = Offset(w * 0.60, h * 0.35);
    final lupaR      = w * 0.22;

    canvas.drawCircle(
      lupaCenter, lupaR + 2,
      Paint()..color = Colors.white,
    );

    // ── Círculo de la lupa (fondo azul Google) ────────────────────────────────
    canvas.drawCircle(
      lupaCenter, lupaR,
      Paint()..color = const Color(0xFF4285F4),
    );

    // ── Agujero blanco interior de la lupa ────────────────────────────────────
    canvas.drawCircle(
      lupaCenter, lupaR * 0.64,
      Paint()..color = Colors.white,
    );

    // ── Check blanco dentro de la lupa ────────────────────────────────────────
    final checkPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = w * 0.038
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final checkPath = Path()
      ..moveTo(lupaCenter.dx - lupaR * 0.32, lupaCenter.dy)
      ..lineTo(lupaCenter.dx - lupaR * 0.05, lupaCenter.dy + lupaR * 0.28)
      ..lineTo(lupaCenter.dx + lupaR * 0.35, lupaCenter.dy - lupaR * 0.30);

    canvas.drawPath(checkPath, checkPaint);

    // ── Mango de la lupa (path curvo orgánico con grosor real) ────────────────
    //    Sale del borde inferior-izquierdo del círculo y baja en curva suave
    final mangoStart = Offset(
      lupaCenter.dx - lupaR * 0.68,
      lupaCenter.dy + lupaR * 0.72,
    );
    final mangoEnd = Offset(
      lupaCenter.dx - lupaR * 1.35,
      lupaCenter.dy + lupaR * 1.55,
    );

    // Path exterior del mango
    final mangoPath = Path();
    final mangoW = w * 0.07; // grosor

    // Calculamos el vector perpendicular para dar grosor al mango
    final dx   = mangoEnd.dx - mangoStart.dx;
    final dy   = mangoEnd.dy - mangoStart.dy;
    final len  = math.sqrt(dx * dx + dy * dy);
    final nx   = -dy / len * mangoW / 2;
    final ny   =  dx / len * mangoW / 2;

    // Control point para la curva Bézier
    final ctrl = Offset(
      mangoStart.dx - lupaR * 0.4,
      mangoStart.dy + lupaR * 0.5,
    );

    mangoPath
      ..moveTo(mangoStart.dx + nx, mangoStart.dy + ny)
      ..quadraticBezierTo(
          ctrl.dx + nx, ctrl.dy + ny,
          mangoEnd.dx + nx, mangoEnd.dy + ny)
      ..lineTo(mangoEnd.dx - nx, mangoEnd.dy - ny)
      ..quadraticBezierTo(
          ctrl.dx - nx, ctrl.dy - ny,
          mangoStart.dx - nx, mangoStart.dy - ny)
      ..close();

    // Clip redondeado en los extremos con StrokeCap simulado
    canvas.drawPath(
      mangoPath,
      Paint()..color = const Color(0xFFEA4335),
    );

    // Sombra interior del mango (lado inferior más oscuro)
    final mangoShadowPath = Path();
    mangoShadowPath
      ..moveTo(mangoStart.dx, mangoStart.dy + ny * 0.3)
      ..quadraticBezierTo(
          ctrl.dx, ctrl.dy + ny * 0.3,
          mangoEnd.dx, mangoEnd.dy + ny * 0.3)
      ..lineTo(mangoEnd.dx - nx, mangoEnd.dy - ny)
      ..quadraticBezierTo(
          ctrl.dx - nx, ctrl.dy - ny,
          mangoStart.dx - nx, mangoStart.dy - ny)
      ..close();

    canvas.drawPath(
      mangoShadowPath,
      Paint()..color = const Color(0xFFC5221F).withOpacity(0.7),
    );

    // Tapa redondeada en el extremo inferior del mango
    canvas.drawCircle(
      mangoEnd,
      mangoW / 2,
      Paint()..color = const Color(0xFFC5221F),
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Línea de cotización animada (fondo inferior)
// ─────────────────────────────────────────────────────────────────────────────

class _ChartLinePainter extends CustomPainter {
  const _ChartLinePainter({required this.offset});
  final double offset;

  // Puntos de la línea (coordenadas en un espacio de 800×200)
  static const _points = [
    Offset(0, 160),   Offset(60, 130),  Offset(120, 145),
    Offset(180, 105), Offset(240, 90),  Offset(300, 115),
    Offset(360, 75),  Offset(420, 60),  Offset(480, 85),
    Offset(540, 45),  Offset(600, 30),  Offset(660, 55),
    Offset(720, 20),  Offset(780, 35),  Offset(840, 15),
    Offset(900, 40),  Offset(960, 10),  Offset(1020, 30),
    Offset(1080, 5),  Offset(1140, 25), Offset(1200, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (_points.isEmpty) return;

    final scaleX = size.width / 800;
    final scaleY = size.height / 200;

    // Transforma y desplaza los puntos
    List<Offset> pts = _points.map((p) {
      return Offset(
        (p.dx + offset) * scaleX,
        p.dy * scaleY,
      );
    }).toList();

    // Segunda vuelta para el loop continuo
    List<Offset> pts2 = _points.map((p) {
      return Offset(
        (p.dx + offset + 1200 * scaleX) * scaleX,
        p.dy * scaleY,
      );
    }).toList();

    final allPts = [...pts, ...pts2];

    // Path de la línea
    final linePath = Path()..moveTo(allPts.first.dx, allPts.first.dy);
    for (int i = 1; i < allPts.length; i++) {
      linePath.lineTo(allPts[i].dx, allPts[i].dy);
    }

    // Path del área rellena
    final areaPath = Path.from(linePath)
      ..lineTo(allPts.last.dx, size.height)
      ..lineTo(allPts.first.dx, size.height)
      ..close();

    // Degradado del área
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF34A853).withOpacity(0.12),
        const Color(0xFF34A853).withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, Paint()..shader = gradient);

    // Línea verde
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF34A853).withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChartLinePainter old) => old.offset != offset;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Google logo widget
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogoWidget extends StatelessWidget {
  const _GoogleLogoWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    const colors = [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC04),
      Color(0xFF34A853),
    ];

    final sweeps = [
      math.pi * 0.9, math.pi * 0.6,
      math.pi * 0.5, math.pi * 0.9,
    ];
    final starts = [
      -math.pi * 0.1, math.pi * 0.8,
       math.pi * 1.4, math.pi * 1.9,
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.65),
        starts[i], sweeps[i], false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.35
          ..strokeCap = StrokeCap.butt,
      );
    }

    canvas.drawCircle(c, r * 0.42,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.18, r * 0.9, r * 0.36),
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
