import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kForestGreen = Color(0xFF1E3932);

class LogisticsScreen extends StatefulWidget {
  const LogisticsScreen({super.key});
  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pingController;
  late Animation<double> _pingAnim;

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _pingAnim = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _pingController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Map background ──
            Positioned.fill(
              child: CustomPaint(painter: _MapPainter()),
            ),

            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: kDarkSlate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A9BAE)),
                          const SizedBox(width: 8),
                          Text('Find nearby recyclers…', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A9BAE))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Driver / route markers on map ──
            _buildMapPins(context),

            // ── Bottom recycler card ──
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildRecyclerCard(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPins(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Pickup location pin (house)
        Positioned(
          left: size.width * 0.28,
          top: size.height * 0.35,
          child: _MapPin(icon: Icons.home_rounded, primary: false),
        ),
        // Recycler pin (animated ping)
        Positioned(
          left: size.width * 0.58,
          top: size.height * 0.28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pingAnim,
                builder: (_, __) => Opacity(
                  opacity: (1.5 - _pingAnim.value).clamp(0, 1).toDouble(),
                  child: Transform.scale(
                    scale: _pingAnim.value,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: kEmerald.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
              _MapPin(icon: Icons.recycling_rounded, primary: true),
            ],
          ),
        ),
        // Driver marker
        Positioned(
          left: size.width * 0.44,
          top: size.height * 0.31,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
            ),
            child: const Icon(Icons.local_shipping_rounded, color: kEmerald, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildRecyclerCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ETA chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: kEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: kEmerald, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Driver en route · ETA 12 min', style: GoogleFonts.inter(fontSize: 12, color: kForestGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: kEmerald.withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded, color: kEmerald, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GreenCycle Partners', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: kDarkSlate)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(Icons.star_rounded, size: 13, color: i < 4 ? const Color(0xFFFFD700) : const Color(0xFFDDD))),
                        const SizedBox(width: 4),
                        Text('4.9 · 1.2 km away', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A9BAE))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: kEmerald, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Route steps
          _RouteStep(icon: Icons.home_rounded, label: 'Your location', detail: '12 MG Road, Mumbai', isFirst: true),
          _RouteStep(icon: Icons.recycling_rounded, label: 'Drop-off point', detail: 'GreenCycle Facility, Andheri', isFirst: false),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Schedule Pickup', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final bool primary;
  const _MapPin({required this.icon, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: primary ? kEmerald : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
          ),
          child: Icon(icon, color: primary ? Colors.white : kEmerald, size: 20),
        ),
        CustomPaint(size: const Size(8, 6), painter: _PinTailPainter(color: primary ? kEmerald : Colors.white)),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _RouteStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool isFirst;
  const _RouteStep({required this.icon, required this.label, required this.detail, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isFirst ? const Color(0xFFEEF8F2) : kEmerald.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: kEmerald),
              ),
              if (!isFirst) const SizedBox() else Container(width: 1.5, height: 14, color: const Color(0xFFDDE3E9)),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A9BAE))),
              Text(detail, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kDarkSlate)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Custom Map Painter ────────────────────────────────────────────────────────
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFEBF0E8));

    final roadPaint = Paint()..color = Colors.white..strokeWidth = 10..strokeCap = StrokeCap.round;
    final minorPaint = Paint()..color = Colors.white..strokeWidth = 5;
    final blockPaint = Paint()..color = const Color(0xFFDEE8D8);

    // Blocks
    final blocks = [
      Rect.fromLTRB(40, 80, 160, 200),
      Rect.fromLTRB(180, 80, 310, 200),
      Rect.fromLTRB(40, 220, 180, 360),
      Rect.fromLTRB(200, 220, 340, 380),
      Rect.fromLTRB(20, 380, 180, 500),
    ];
    for (final b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), blockPaint);
    }

    // Major roads
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.45, size.height), roadPaint);

    // Minor roads
    canvas.drawLine(Offset(0, size.height * 0.22), Offset(size.width, size.height * 0.22), minorPaint);
    canvas.drawLine(Offset(0, size.height * 0.55), Offset(size.width, size.height * 0.55), minorPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), minorPaint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), minorPaint);

    // Route polyline
    final routePaint = Paint()
      ..color = kEmerald
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.38)
      ..lineTo(size.width * 0.45, size.height * 0.38)
      ..lineTo(size.width * 0.45, size.height * 0.30)
      ..lineTo(size.width * 0.60, size.height * 0.30);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
