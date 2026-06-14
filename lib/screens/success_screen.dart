import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/recycle_service.dart';

const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kForestGreen = Color(0xFF1E3932);
const Color kGold = Color(0xFFFFD700);

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});
  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _confettiController;
  late AnimationController _cardController;
  late Animation<double> _checkScale;
  late Animation<double> _cardSlide;
  final List<_Confetti> _confetti = [];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    for (var i = 0; i < 60; i++) {
      _confetti.add(_Confetti(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.6,
        speed: 0.3 + rng.nextDouble() * 0.7,
        size: 6 + rng.nextDouble() * 8,
        color: [kEmerald, kGold, const Color(0xFF3498DB), const Color(0xFFE74C3C), Colors.white, const Color(0xFF88B04B)][rng.nextInt(6)],
        angle: rng.nextDouble() * 2 * pi,
        swing: (rng.nextDouble() - 0.5) * 0.04,
      ));
    }

    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _checkScale = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);
    _cardSlide = CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic);

    _checkController.forward().then((_) {
      _confettiController.forward();
      Future.delayed(const Duration(milliseconds: 200), () => _cardController.forward());
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _confettiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final args = ModalRoute.of(context)?.settings.arguments;
    final result = args is RecycleResult ? args : null;

    final cashText = result == null ? '₹0' : '₹${result.cashDeltaInr.toStringAsFixed(0)}';
    final gcText = result == null ? '+0 GC' : '+${result.creditsDelta} GC';
    final deviceText = result?.deviceName ?? 'Device';
    final co2Text = result == null ? '0 kg' : '${result.co2DeltaKg.toStringAsFixed(1)} kg';
    final metalsText = result == null ? '0 g' : '${result.metalsDeltaG.toStringAsFixed(0)} g';
    final energyText = result == null ? '0 kWh' : '${result.energyDeltaKwh.toStringAsFixed(1)} kWh';
    final waterText = result == null ? '0 L' : '${result.waterDeltaL.toStringAsFixed(0)} L';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Confetti ──
            AnimatedBuilder(
              animation: _confettiController,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _ConfettiPainter(confetti: _confetti, progress: _confettiController.value),
              ),
            ),

            // ── Main content ──
            Column(
              children: [
                const Spacer(),

                // Checkmark
                AnimatedBuilder(
                  animation: _checkScale,
                  builder: (_, __) => Transform.scale(
                    scale: _checkScale.value,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: kEmerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: kEmerald.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5),
                          BoxShadow(color: kEmerald.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text('Recycled Successfully!',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: kDarkSlate, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Your rewards have been added to your wallet.',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF8A9BAE)), textAlign: TextAlign.center),

                const SizedBox(height: 32),

                // ── Summary card ──
                AnimatedBuilder(
                  animation: _cardSlide,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, (1 - _cardSlide.value) * 40),
                    child: Opacity(
                      opacity: _cardSlide.value,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kForestGreen, kEmerald],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _RewardBadge(value: cashText, label: 'Sent to Wallet', icon: Icons.account_balance_wallet_rounded),
                                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                                  _RewardBadge(value: gcText, label: 'Credits Added', icon: Icons.eco_rounded),
                                ],
                              ),
                            ),

                            // Details
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _DetailRow(label: 'Device', value: deviceText),
                                  _DetailRow(label: 'CO₂ Offset', value: co2Text),
                                  _DetailRow(label: 'Metals recovered', value: metalsText),
                                  _DetailRow(label: 'Energy saved', value: energyText),
                                  _DetailRow(label: 'Water saved', value: waterText),
                                  _DetailRow(label: 'Date', value: DateTime.now().toLocal().toString().split(' ').first),
                                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                                  // Blockchain TX
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.cloud_done_rounded, size: 14, color: kEmerald),
                                          const SizedBox(width: 6),
                                          Text('Saved to Firestore', style: GoogleFonts.inter(fontSize: 11, color: kEmerald, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Wallet updated immediately. Transactions will appear once wired to the history screen.',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A9BAE)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Back to Home', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {},
                        child: Text('Share your impact 🌍', style: GoogleFonts.inter(fontSize: 14, color: kEmerald, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _RewardBadge({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE))),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kDarkSlate)),
        ],
      ),
    );
  }
}

// ─── Confetti Model & Painter ──────────────────────────────────────────────────
class _Confetti {
  final double x, delay, speed, size, angle, swing;
  final Color color;
  const _Confetti({required this.x, required this.delay, required this.speed, required this.size, required this.color, required this.angle, required this.swing});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> confetti;
  final double progress;
  const _ConfettiPainter({required this.confetti, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      final t = ((progress - c.delay) / c.speed).clamp(0, 1).toDouble();
      if (t <= 0) continue;
      final y = t * size.height * 1.1;
      final x = c.x * size.width + sin(t * 6 + c.angle) * 30 * c.swing * size.width;
      final paint = Paint()..color = c.color.withValues(alpha: (1 - t * 0.6).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.angle + t * 4);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
