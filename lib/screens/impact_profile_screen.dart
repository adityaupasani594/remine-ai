import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/formatters.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kSoft = Color(0xFF8A9BAE);
const Color _kOffWhite = Color(0xFFF5F5F7);
const Color _kCopper = Color(0xFFB87333);

// ─── Screen ───────────────────────────────────────────────────────────────────
class ImpactProfileScreen extends StatefulWidget {
  const ImpactProfileScreen({super.key});
  @override
  State<ImpactProfileScreen> createState() => _ImpactProfileScreenState();
}

class _ImpactProfileScreenState extends State<ImpactProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const _badges = [
    (_kCopper, Icons.shield_rounded, 'Copper Guardian', 'Level 1'),
    (_kEmerald, Icons.emoji_events_rounded, 'E-Waste Warrior', 'Level 3'),
    (Color(0xFF3498DB), Icons.stars_rounded, 'Eco Pioneer', 'Level 2'),
    (Color(0xFF9B59B6), Icons.local_fire_department_rounded, 'Green Streak', 'Level 4'),
  ];

  static const _menuItems = [
    (Icons.person_outline_rounded, 'Account'),
    (Icons.payment_rounded, 'Payment Methods'),
    (Icons.language_rounded, 'Language'),
    (Icons.notifications_none_rounded, 'Notifications'),
    (Icons.help_outline_rounded, 'Help & Support'),
    (Icons.logout_rounded, 'Log Out'),
  ];

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots();
  }

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ringAnim = Tween<double>(begin: 0.0, end: 0.72).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
    _ringCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final name = (data['name'] ?? 'User').toString();
            final co2 = AppFormatters.oneDecimal(data['co2_saved_kg'] ?? 0);
            final metals = AppFormatters.oneDecimal(data['metals_recovered_g'] ?? 0);
            final gc = (data['green_credits_balance'] ?? 0).toString();
            final items = (data['total_items_recycled'] ?? 0).toString();

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildAvatarRing(),
                  const SizedBox(height: 8),
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _kDark)),
                  const SizedBox(height: 4),
                  _buildLevelBadge(),
                  const SizedBox(height: 28),
                  _buildImpactStatsDynamic(co2: co2, metals: metals, gc: gc, items: items),
                  const SizedBox(height: 28),
                  _buildBadgesSection(),
                  const SizedBox(height: 28),
                  _buildMenu(),
                  const SizedBox(height: 24),
                  _buildVersionFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Spacer(),
          Text('My Profile',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kDark)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile/edit'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _kOffWhite, borderRadius: BorderRadius.circular(12)),
              child:
                  const Icon(Icons.edit_outlined, size: 20, color: _kDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRing() {
    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (_, __) {
        return SizedBox(
          width: 124, height: 124,
          child: CustomPaint(
            painter: _RingPainter(progress: _ringAnim.value),
            child: Center(
              child: Container(
                width: 92, height: 92,
                decoration: const BoxDecoration(
                  color: _kOffWhite,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: _kEmerald, size: 48),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _kEmerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: _kEmerald, size: 14),
          const SizedBox(width: 4),
          Text('Level 5 — Urban Miner',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kEmerald)),
        ],
      ),
    );
  }

  Widget _buildImpactStatsDynamic({required String co2, required String metals, required String gc, required String items}) {
    final stats = <({Color color, IconData icon, String label, String value})>[
      (color: _kEmerald, icon: Icons.cloud_outlined, label: 'CO₂ Saved', value: '$co2 kg'),
      (color: _kCopper, icon: Icons.hardware_outlined, label: 'Metals', value: '$metals g'),
      (color: const Color(0xFF3498DB), icon: Icons.eco_outlined, label: 'Green Credits', value: gc),
      (color: const Color(0xFF9B59B6), icon: Icons.recycling_rounded, label: 'Items Recycled', value: items),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: s.color.withValues(alpha: 0.18)),
              ),
              child: Column(
                children: [
                  Icon(s.icon, color: s.color, size: 18),
                  const SizedBox(height: 8),
                  Text(
                    s.value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(s.label, style: GoogleFonts.inter(fontSize: 10, color: _kSoft)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badges',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
              Text('View all',
                style: GoogleFonts.inter(fontSize: 12, color: _kEmerald, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final b = _badges[i];
              return Column(
                children: [
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      color: b.$1.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: b.$1.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Icon(b.$2, color: b.$1, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(b.$3,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _kDark)),
                  Text(b.$4,
                    style: GoogleFonts.inter(fontSize: 9, color: _kSoft)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_menuItems.length, (i) {
          final item = _menuItems[i];
          final isLast = i == _menuItems.length - 1;
          return GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              decoration: BoxDecoration(
                border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: const Color(0xFFE8ECF0), width: 1)),
              ),
              child: Row(
                children: [
                  Icon(item.$1,
                    color: isLast ? const Color(0xFFE74C3C) : _kSoft, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(item.$2,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isLast ? const Color(0xFFE74C3C) : _kDark,
                      )),
                  ),
                  if (!isLast)
                    const Icon(Icons.chevron_right_rounded, color: _kSoft, size: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Text('Version 2.0.1',
      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCCD3DB)));
  }
}

// ─── Ring Painter ─────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeW = 7.0;

    // Track
    canvas.drawCircle(center, radius,
      Paint()
        ..color = const Color(0xFFEEEEEE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = _kEmerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, paint);

    // Glow dot at end
    if (progress > 0) {
      final angle = -pi / 2 + 2 * pi * progress;
      final dotX = center.dx + radius * cos(angle);
      final dotY = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 5,
        Paint()..color = _kEmerald);
      canvas.drawCircle(Offset(dotX, dotY), 5,
        Paint()
          ..color = _kEmerald.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
