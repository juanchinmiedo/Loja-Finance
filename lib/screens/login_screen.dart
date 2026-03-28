// lib/screens/login_screen.dart
// COMMIT 1 — Fix: línea verde loop, overflow horizontal, completedCount en mini-stats

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import 'package:financas_hub_app/generated/l10n.dart';

class _MiniStats {
  final double grossRevenue;
  final double changePercent;
  final int    completedCount;
  final double occupancyRate;

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

  final firstDayThisMonth = DateTime(now.year, now.month, 1);
  final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
  final firstDayNextMonth = DateTime(now.year, now.month + 1, 1);

  final snap = await db
      .collection('appointments')
      .where('appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayThisMonth))
      .where('appointmentDate',
          isLessThan: Timestamp.fromDate(firstDayNextMonth))
      .get();

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
  final  total       = snap.docs.length;

  for (final doc in snap.docs) {
    final data   = doc.data();
    final status = (data['status'] ?? '').toString();
    final price  = ((data['finalPrice'] ?? data['basePrice'] ?? data['total'] ?? 0) as num).toDouble();
    // FIX: 'scheduled' también cuenta como completado e ingreso
    if (status == 'done' || status == 'scheduled') {
      thisRevenue += price;
      completed++;
    }
  }

  for (final doc in snapPrev.docs) {
    final data   = doc.data();
    final status = (data['status'] ?? '').toString();
    final price  = ((data['finalPrice'] ?? data['basePrice'] ?? data['total'] ?? 0) as num).toDouble();
    if (status == 'done' || status == 'scheduled') {
      prevRevenue += price;
    }
  }

  final change    = prevRevenue == 0
      ? 0.0
      : ((thisRevenue - prevRevenue) / prevRevenue) * 100;
  final occupancy = total == 0 ? 0.0 : (completed / total) * 100;

  return _MiniStats(
    grossRevenue:   thisRevenue,
    changePercent:  change,
    completedCount: completed,
    occupancyRate:  occupancy,
  );
}

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

  _MiniStats? _stats;
  bool        _statsLoading = true;

  late final AnimationController _chartCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;

  late final Animation<double> _chartAnim;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _chartCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // FIX: animación de 0→1 (se mapea a offset dentro del painter)
    _chartAnim = Tween<double>(begin: 0, end: 1).animate(
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

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      // FIX: resizeToAvoidBottomInset false evita overflow al girar
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Línea de cotización animada
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, __) => CustomPaint(
                painter: _ChartLinePainter(progress: _chartAnim.value),
              ),
            ),
          ),

          // Contenido principal — FIX: LayoutBuilder para responsivo
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // En landscape reducimos padding horizontal
                  final isLandscape = constraints.maxWidth > constraints.maxHeight;
                  final hPad = isLandscape ? 48.0 : 32.0;

                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Column(
                          children: [
                            Spacer(flex: isLandscape ? 1 : 2),

                            ScaleTransition(
                              scale: _pulse,
                              child: _FinancasLogo(size: isLandscape ? 72 : 96),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              l10n.appTitle,
                              style: GoogleFonts.nunito(
                                fontSize:   isLandscape ? 24 : 30,
                                fontWeight: FontWeight.w600,
                                color:      const Color(0xFF202124),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.loginSubtitle,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color:    const Color(0xFF5F6368),
                              ),
                            ),

                            Spacer(flex: isLandscape ? 1 : 2),

                            _buildMiniCards(l10n),

                            const SizedBox(height: 24),

                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCE8E6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFEA4335)
                                          .withOpacity(0.3)),
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
                                          color:      const Color(0xFFEA4335),
                                          fontSize:   13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            _loading
                                ? _buildLoadingButton(l10n)
                                : _buildSignInButton(l10n),

                            const SizedBox(height: 16),

                            Text(
                              l10n.loginFooter,
                              style: GoogleFonts.nunito(
                                color:    const Color(0xFFBDC1C6),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    return Row(
      children: [
        _MiniCard(
          value:      changeStr,
          label:      l10n.miniCardMonth,
          valueColor: changeColor,
        ),
        const SizedBox(width: 10),
        _MiniCard(
          value:      s == null ? '--' : '€${s.grossRevenue.toStringAsFixed(0)}',
          label:      l10n.miniCardRevenue,
          valueColor: const Color(0xFF4285F4),
        ),
        const SizedBox(width: 10),
        _MiniCard(
          value:      s == null ? '--' : '${s.occupancyRate.toStringAsFixed(0)}%',
          label:      l10n.miniCardOccupancy,
          valueColor: const Color(0xFFFBBC04),
        ),
      ],
    );
  }

  Widget _buildSignInButton(S l10n) {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          elevation:       1,
          shadowColor:     Colors.black.withOpacity(0.1),
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
                fontSize:   15,
                fontWeight: FontWeight.w500,
                color:      const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingButton(S l10n) {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation:       1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth:  2.5,
                valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.loginVerifying,
              style: GoogleFonts.nunito(
                fontSize:   15,
                fontWeight: FontWeight.w500,
                color:      const Color(0xFF5F6368),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mini-card
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
          color:        const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize:   17,
                fontWeight: FontWeight.w600,
                color:      valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color:    const Color(0xFF80868B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logo
// ─────────────────────────────────────────────────────────────────────────────

class _FinancasLogo extends StatelessWidget {
  const _FinancasLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        border:       Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final barW  = w * 0.135;
    final baseY = h * 0.92;
    final rx    = const Radius.circular(3);

    void drawBar(double x, double barH, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseY - barH, barW, barH), rx),
        Paint()..color = color,
      );
    }

    drawBar(w * 0.08, h * 0.26, const Color(0xFF4285F4));
    drawBar(w * 0.24, h * 0.38, const Color(0xFF34A853));
    drawBar(w * 0.40, h * 0.30, const Color(0xFFFBBC04));
    drawBar(w * 0.56, h * 0.50, const Color(0xFFEA4335));

    final lupaCenter = Offset(w * 0.60, h * 0.35);
    final lupaR      = w * 0.22;

    canvas.drawCircle(lupaCenter, lupaR + 2, Paint()..color = Colors.white);
    canvas.drawCircle(lupaCenter, lupaR,     Paint()..color = const Color(0xFF4285F4));
    canvas.drawCircle(lupaCenter, lupaR * 0.64, Paint()..color = Colors.white);

    final checkPaint = Paint()
      ..color       = const Color(0xFF4285F4)
      ..strokeWidth = w * 0.038
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(lupaCenter.dx - lupaR * 0.32, lupaCenter.dy)
        ..lineTo(lupaCenter.dx - lupaR * 0.05, lupaCenter.dy + lupaR * 0.28)
        ..lineTo(lupaCenter.dx + lupaR * 0.35, lupaCenter.dy - lupaR * 0.30),
      checkPaint,
    );

    final mangoStart = Offset(lupaCenter.dx - lupaR * 0.68, lupaCenter.dy + lupaR * 0.72);
    final mangoEnd   = Offset(lupaCenter.dx - lupaR * 1.35, lupaCenter.dy + lupaR * 1.55);
    final mangoW     = w * 0.07;
    final dx = mangoEnd.dx - mangoStart.dx;
    final dy = mangoEnd.dy - mangoStart.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = -dy / len * mangoW / 2;
    final ny =  dx / len * mangoW / 2;
    final ctrl = Offset(mangoStart.dx - lupaR * 0.4, mangoStart.dy + lupaR * 0.5);

    final mangoPath = Path()
      ..moveTo(mangoStart.dx + nx, mangoStart.dy + ny)
      ..quadraticBezierTo(ctrl.dx + nx, ctrl.dy + ny, mangoEnd.dx + nx, mangoEnd.dy + ny)
      ..lineTo(mangoEnd.dx - nx, mangoEnd.dy - ny)
      ..quadraticBezierTo(ctrl.dx - nx, ctrl.dy - ny, mangoStart.dx - nx, mangoStart.dy - ny)
      ..close();

    canvas.drawPath(mangoPath, Paint()..color = const Color(0xFFEA4335));
    canvas.drawCircle(mangoEnd, mangoW / 2, Paint()..color = const Color(0xFFC5221F));
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIX: _ChartLinePainter con loop correcto
//  El bug anterior: pts2 multiplicaba scaleX dos veces → la segunda copia
//  aparecía muy lejos a la derecha en vez de justo detrás de la primera.
// ─────────────────────────────────────────────────────────────────────────────

class _ChartLinePainter extends CustomPainter {
  const _ChartLinePainter({required this.progress});
  final double progress; // 0→1, se mapea al ancho del canvas

  static const _rawW = 1200.0; // ancho del espacio de coordenadas
  static const _rawH = 200.0;

  static const _points = [
    Offset(0,    160), Offset(60,  130), Offset(120, 145),
    Offset(180,  105), Offset(240,  90), Offset(300, 115),
    Offset(360,   75), Offset(420,  60), Offset(480,  85),
    Offset(540,   45), Offset(600,  30), Offset(660,  55),
    Offset(720,   20), Offset(780,  35), Offset(840,  15),
    Offset(900,   40), Offset(960,  10), Offset(1020, 30),
    Offset(1080,   5), Offset(1140, 25), Offset(1200,  0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _rawW;
    final scaleY = size.height / _rawH;
    // offset en píxeles de pantalla: avanza de 0 → ancho del canvas
    final offset = -progress * size.width;

    // Dos copias de la misma curva para el loop sin costura
    List<Offset> transform(double extraX) => _points.map((p) {
      return Offset(p.dx * scaleX + offset + extraX, p.dy * scaleY);
    }).toList();

    final pts1 = transform(0);
    final pts2 = transform(size.width); // segunda copia exactamente 1 ancho después
    final all  = [...pts1, ...pts2];

    final linePath = Path()..moveTo(all.first.dx, all.first.dy);
    for (int i = 1; i < all.length; i++) {
      linePath.lineTo(all[i].dx, all[i].dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(all.last.dx,  size.height)
      ..lineTo(all.first.dx, size.height)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            const Color(0xFF34A853).withOpacity(0.10),
            const Color(0xFF34A853).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color       = const Color(0xFF34A853).withOpacity(0.45)
        ..strokeWidth = 1.8
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChartLinePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Google logo
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogoWidget extends StatelessWidget {
  const _GoogleLogoWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
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
      Color(0xFF4285F4), Color(0xFFEA4335),
      Color(0xFFFBBC04), Color(0xFF34A853),
    ];
    final sweeps = [math.pi * 0.9, math.pi * 0.6, math.pi * 0.5, math.pi * 0.9];
    final starts = [
      -math.pi * 0.1, math.pi * 0.8,
       math.pi * 1.4, math.pi * 1.9,
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.65),
        starts[i], sweeps[i], false,
        Paint()
          ..color       = colors[i]
          ..style       = PaintingStyle.stroke
          ..strokeWidth = r * 0.35
          ..strokeCap   = StrokeCap.butt,
      );
    }

    canvas.drawCircle(c, r * 0.42, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.18, r * 0.9, r * 0.36),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
