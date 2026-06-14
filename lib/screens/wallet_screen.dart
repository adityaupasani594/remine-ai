import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/formatters.dart';
import '../services/pickup_service.dart';

const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kForestGreen = Color(0xFF1E3932);
const Color kSageGreen = Color(0xFF88B04B);

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots();
  }

  String _fmtInr(Object? v) {
    final n = v is num ? v.toDouble() : double.tryParse((v ?? '').toString()) ?? 0;
    final sign = n < 0 ? '-' : '+';
    final abs = n.abs().toStringAsFixed(0);
    return '$sign₹$abs';
  }

  String _fmtGc(Object? v) {
    final n = v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? 0;
    final sign = n < 0 ? '-' : '+';
    return '$sign${n.abs()} GC';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final gc = (data['green_credits_balance'] ?? 0);
            final cash = (data['cash_balance_inr'] ?? 0);
            final co2 = (data['co2_saved_kg'] ?? 0);

            return Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      const Spacer(),
                      Text('Green Wallet', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: kDarkSlate)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile/edit'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.edit_outlined, size: 20, color: kDarkSlate),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildGlassCardDynamic(gc: gc, cash: cash, co2: co2),

                const SizedBox(height: 20),

                // ── Tabs ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(color: kEmerald, borderRadius: BorderRadius.circular(12)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF8A9BAE),
                      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Transactions'), Tab(text: 'Redeem')],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTxList(),
                      _emptyList('No rewards loaded', 'Add rewards in Firestore (collection: rewards) or wire this later.'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassCardDynamic({required Object gc, required Object cash, required Object co2}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.06, child: CustomPaint(painter: _GlowPainter()))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: kEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: kEmerald, size: 22),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: kForestGreen, borderRadius: BorderRadius.circular(20)),
                      child: Text('CO₂: ${AppFormatters.oneDecimal(co2)} kg', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Spacer(),
                Text('$gc GC', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: kForestGreen, letterSpacing: -1.2)),
                const SizedBox(height: 6),
                Text('Cash value: ₹$cash', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A9BAE), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyList(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: kDarkSlate)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE)), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                style: ElevatedButton.styleFrom(backgroundColor: kEmerald, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Edit My Data', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTxList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _txStream(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _emptyList('No transactions yet', 'Recycle a device to earn credits and cash.');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == docs.length) {
              return TextButton(
                onPressed: () => Navigator.pushNamed(context, '/transactions'),
                child: Text('View all', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: kEmerald)),
              );
            }

            final d = docs[i].data();
            final title = (d['title'] ?? 'Transaction').toString();
            final status = (d['status'] ?? '').toString();
            final amount = _fmtInr(d['amount_inr']);
            final gc = _fmtGc(d['gc_delta']);
            final earned = (d['type'] ?? 'earn') == 'earn';
            final isPending = status == 'pending';

            return InkWell(
              onTap: isPending ? () {
                final result = PickupRequestResult(
                  pickupDocId: (d['pickup_request_id'] ?? '').toString(),
                  handoffOtp: (d['handoff_otp'] ?? '').toString(),
                  transactionId: docs[i].id,
                  recyclerId: (d['recycler_id'] ?? '').toString(),
                  recyclerName: (d['recycler_name'] ?? '').toString(),
                  recyclerRating: 0.0, // not strictly needed for the display now
                  recyclerDistance: '', // not strictly needed
                  deviceName: (d['device_name'] ?? '').toString(),
                  deviceDetails: (d['device_details'] ?? '').toString(),
                  totalValueInr: (d['amount_inr'] as num?)?.toDouble() ?? 0.0,
                  greenCredits: (d['gc_delta'] as num?)?.toInt() ?? 0,
                );
                Navigator.pushNamed(context, '/active-deal', arguments: result);
              } : null,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
                  border: isPending ? Border.all(color: const Color(0xFFF1C40F).withValues(alpha: 0.5), width: 1.5) : null,
                ),
                child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: earned ? kEmerald.withValues(alpha: 0.12) : const Color(0xFFFEEBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      earned ? Icons.recycling_rounded : Icons.redeem_rounded,
                      color: earned ? kEmerald : const Color(0xFFE74C3C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: kDarkSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(status.isEmpty ? 'completed' : status, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A9BAE))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: earned ? kEmerald : const Color(0xFFE74C3C))),
                      const SizedBox(height: 2),
                      Text(gc, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: kForestGreen)),
                    ],
                  )
                  ]
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
