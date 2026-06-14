import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/formatters.dart';
import '../widgets/add_review_sheet.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kSageGreen = Color(0xFF88B04B);
const Color kForestGreen = Color(0xFF1E3932);
const Color kOffWhite = Color(0xFFF5F5F7);
const Color kGold = Color(0xFFFFD700);
const Color kCopper = Color(0xFFB87333);
const Color kSilver = Color(0xFFC0C0C0);

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(uid).snapshots();
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
            final rawName = (data['name'] ?? '').toString().trim();
            final name = rawName.isEmpty ? 'Urban Miner' : rawName;
            final gc = (data['green_credits_balance'] ?? 0);
            final cash = (data['cash_balance_inr'] ?? 0);

            final co2 = (data['co2_saved_kg'] ?? 0);
            final metals = (data['metals_recovered_g'] ?? 0);
            final energy = (data['energy_saved_kwh'] ?? 0);
            final water = (data['water_saved_l'] ?? 0);

            final impactCards = [
              {'icon': Icons.cloud_outlined, 'value': '${AppFormatters.oneDecimal(co2)} kg', 'label': 'CO₂ Saved', 'color': kEmerald},
              {'icon': Icons.hardware_outlined, 'value': '${AppFormatters.oneDecimal(metals)} g', 'label': 'Metals Recovered', 'color': kCopper},
              {'icon': Icons.bolt_outlined, 'value': '${AppFormatters.oneDecimal(energy)} kWh', 'label': 'Energy Saved', 'color': kGold},
              {'icon': Icons.water_drop_outlined, 'value': '${AppFormatters.oneDecimal(water)} L', 'label': 'Water Saved', 'color': const Color(0xFF3498DB)},
            ];

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(name),
                        const SizedBox(height: 24),
                        _buildEarningsBanner(gc: gc, cash: cash),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Impact at a Glance', onTrailingTap: () {}),
                        const SizedBox(height: 12),
                        _buildImpactCards(impactCards),
                        const SizedBox(height: 28),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Recent Activity', trailing: 'View all', onTrailingTap: () => Navigator.pushNamed(context, '/transactions')),
                        const SizedBox(height: 12),
                        _buildEmptyRecentActivity(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Feedback', onTrailingTap: () {}),
                        const SizedBox(height: 12),
                        _buildAddReviewCard(name),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddReviewCard(String userName) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddReviewSheet(userName: userName),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kOffWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EBE8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kEmerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_rounded, color: kEmerald, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Review / Complaint', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: kDarkSlate)),
                  const SizedBox(height: 4),
                  Text('Rate your experience with a recycler', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A9BAE)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: kEmerald.withValues(alpha: 0.15),
          child: const Icon(Icons.person_rounded, color: kEmerald, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello,', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A9BAE))),
            Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: kDarkSlate)),
          ],
        ),
        const Spacer(),
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kOffWhite, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.settings_outlined, color: kDarkSlate, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEarningsBanner({required Object gc, required Object cash}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3932), Color(0xFF2ECC71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kEmerald.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Green Wallet', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('₹$cash', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text('$gc Green Credits', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kForestGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, {String? trailing, VoidCallback? onTrailingTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: kDarkSlate)),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing, style: GoogleFonts.inter(fontSize: 13, color: kEmerald, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildImpactCards(List<Map<String, dynamic>> cards) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: cards.map((c) => _buildImpactCard(c)).toList(),
    );
  }

  Widget _buildEmptyRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kOffWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No activity yet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: kDarkSlate)),
          const SizedBox(height: 6),
          Text('Scan a device to generate your first report.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE))),
        ],
      ),
    );
  }

  Widget _buildImpactCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (c['color'] as Color).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (c['color'] as Color).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(c['icon'] as IconData, color: c['color'] as Color, size: 22),
          const Spacer(),
          Text(c['value'] as String, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kDarkSlate)),
          const SizedBox(height: 2),
          Text(c['label'] as String, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF8A9BAE))),
        ],
      ),
    );
  }
}
