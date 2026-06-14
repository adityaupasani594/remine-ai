import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_service.dart';

const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kForestGreen = Color(0xFF1E3932);
const Color kGold = Color(0xFFFFD700);
const Color kCopper = Color(0xFFB87333);
const Color kSilver = Color(0xFFC0C0C0);

// Colour palette for material segments
const List<Color> _segmentColours = [kGold, kCopper, Color(0xFFAED6F1), kSilver, Color(0xFF82E0AA), Color(0xFFF1948A)];

class ValuationScreen extends StatefulWidget {
  const ValuationScreen({super.key});
  @override
  State<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _valueAnim;
  late Animation<double> _donutAnim;

  DeviceAnalysis? _analysis;
  List<_DonutSegment> _segments = [];

  // Fallback mock data used when no Gemini result is passed
  static const _mockAnalysis = _MockAnalysis();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _valueAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _donutAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pull the DeviceAnalysis passed as route argument (may be null)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DeviceAnalysis && _analysis == null) {
      _analysis = args;
      _segments = _buildSegments(args.materials);
    }
    if (!_animController.isAnimating && _animController.value == 0) {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<_DonutSegment> _buildSegments(List<MaterialSegment> mats) {
    return mats.asMap().entries.map((e) {
      final colour = _segmentColours[e.key % _segmentColours.length];
      return _DonutSegment(label: e.value.label, value: e.value.fraction, color: colour);
    }).toList();
  }

  // ── Accessors that fall back to mock ──────────────────────────────────────
  String get _deviceName => _analysis?.deviceName ?? _mockAnalysis.deviceName;
  String get _deviceDetails => _analysis?.deviceDetails ?? _mockAnalysis.deviceDetails;
  double get _totalValue => _analysis?.totalValueInr ?? _mockAnalysis.totalValueInr;
  List<_DonutSegment> get _activeSegments =>
      _analysis != null ? _segments : _mockAnalysis.segments;

  String _formatInr(double v) {
    return v.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Future<void> _onRecycle() async {
    if (_analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a device first.')),
      );
      return;
    }

    // Navigate to the map screen to find a recycler instead of instant credits
    Navigator.pushNamed(
      context,
      '/map',
      arguments: _analysis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: kDarkSlate),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Valuation Report',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: kDarkSlate),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, size: 20, color: kDarkSlate),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── Device image / icon area ──
                    Container(
                      height: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.devices_rounded, size: 60, color: Color(0xFF8A9BAE)),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _analysis != null ? kEmerald : Colors.orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _analysis != null ? 'AI Verified ✓' : 'Mock Data',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Device name ──
                    Text(
                      _deviceName,
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: kDarkSlate),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _deviceDetails,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A9BAE)),
                    ),

                    const SizedBox(height: 24),

                    // ── Value display ──
                    AnimatedBuilder(
                      animation: _valueAnim,
                      builder: (_, __) => Text(
                        '₹${_formatInr(_totalValue * _valueAnim.value)}',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          color: kForestGreen,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    Text(
                      'Estimated scrap value',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE)),
                    ),

                    const SizedBox(height: 28),

                    // ── Donut chart card ──
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Material Breakdown',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: kDarkSlate),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _donutAnim,
                                builder: (_, __) => CustomPaint(
                                  size: const Size(130, 130),
                                  painter: _DonutPainter(
                                    segments: _activeSegments,
                                    progress: _donutAnim.value,
                                    centerLabel: '₹${_formatInr(_totalValue)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: _activeSegments
                                      .map((s) => Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(s.label, style: GoogleFonts.inter(fontSize: 12, color: kDarkSlate)),
                                                const Spacer(),
                                                Text(
                                                  '${(s.value * 100).toInt()}%',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: kDarkSlate,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Metal value pills ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _analysis != null
                          ? _buildRealMetalPills()
                          : Row(
                              children: [
                                _MetalPill(label: 'Au', sublabel: 'Gold', value: '₹810', color: kGold),
                                const SizedBox(width: 10),
                                _MetalPill(label: 'Cu', sublabel: 'Copper', value: '₹1,890', color: kCopper),
                                const SizedBox(width: 10),
                                _MetalPill(label: 'Ag', sublabel: 'Silver', value: '₹585', color: kSilver),
                              ],
                            ),
                    ),

                    const SizedBox(height: 28),

                    // ── CTA buttons ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _onRecycle,
                                icon: const Icon(Icons.recycling_rounded, size: 18, color: Colors.white),
                                label: Text(
                                   'Find Recycler',
                                   style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kEmerald,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kDarkSlate,
                                  side: const BorderSide(color: Color(0xFFDDE3E9), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  'Decline',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: kDarkSlate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealMetalPills() {
    final mats = _analysis!.materials;
    // Show up to 3 meaningful metal pills (skip Plastic / —)
    final metals = mats.where((m) => m.symbol != '—' && m.symbol != 'N/A').take(3).toList();
    final colours = [kGold, kCopper, kSilver];
    return Row(
      children: metals.asMap().entries.map((e) {
        final m = e.value;
        final col = colours[e.key % colours.length];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < metals.length - 1 ? 10 : 0),
            child: _MetalPill(
              label: m.symbol,
              sublabel: m.label,
              value: m.valueInr,
              color: col,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Mock fallback data ───────────────────────────────────────────────────────
class _MockAnalysis {
  const _MockAnalysis();
  String get deviceName => 'MacBook Pro 2018';
  String get deviceDetails => '15" · Intel Core i7 · 16GB RAM';
  double get totalValueInr => 4500;
  List<_DonutSegment> get segments => const [
    _DonutSegment(label: 'Gold', value: 0.18, color: kGold),
    _DonutSegment(label: 'Copper', value: 0.42, color: kCopper),
    _DonutSegment(label: 'Plastic', value: 0.27, color: Color(0xFFAED6F1)),
    _DonutSegment(label: 'Other', value: 0.13, color: kSilver),
  ];
}

// ─── Donut Segment Model ──────────────────────────────────────────────────────
class _DonutSegment {
  final String label;
  final double value;
  final Color color;
  const _DonutSegment({required this.label, required this.value, required this.color});
}

// ─── Donut Painter ────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double progress;
  final String centerLabel;
  const _DonutPainter({required this.segments, required this.progress, required this.centerLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeW = 22.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    var startAngle = -pi / 2;
    for (final seg in segments) {
      paint.color = seg.color;
      final sweep = seg.value * 2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeW / 2),
        startAngle,
        sweep - 0.04,
        false,
        paint,
      );
      startAngle += sweep;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: kForestGreen.withValues(alpha: progress),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Inter',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.centerLabel != centerLabel;
}

// ─── Metal Pill ───────────────────────────────────────────────────────────────
class _MetalPill extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final Color color;
  const _MetalPill({required this.label, required this.sublabel, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            Text(sublabel, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF8A9BAE))),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: kDarkSlate)),
          ],
        ),
      ),
    );
  }
}
