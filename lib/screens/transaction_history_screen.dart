import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transactions_repo.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kSoft = Color(0xFF8A9BAE);

// ─── Screen ───────────────────────────────────────────────────────────────────
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prettyDay(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(now.year, now.month, now.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtInr(Object? v) {
    final n = v is num ? v.toDouble() : double.tryParse((v ?? '').toString()) ?? 0;
    final sign = n < 0 ? '-' : '+';
    return '$sign₹${n.abs().toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = TransactionsRepo(auth: FirebaseAuth.instance, db: FirebaseFirestore.instance);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.streamLatest(limit: 100),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No transactions yet',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
                      ),
                    );
                  }

                  // Group by day
                  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groups = {};
                  final Map<String, DateTime> groupDate = {};
                  for (final doc in docs) {
                    final data = doc.data();
                    final ts = data['created_at'];
                    DateTime dt;
                    if (ts is Timestamp) {
                      dt = ts.toDate();
                    } else {
                      dt = DateTime.now();
                    }
                    final key = _dayKey(dt);
                    (groups[key] ??= []).add(doc);
                    groupDate[key] ??= dt;
                  }

                  final keys = groups.keys.toList()
                    ..sort((a, b) => groupDate[b]!.compareTo(groupDate[a]!));

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      for (final k in keys) ...[
                        _buildDateHeader(_prettyDay(groupDate[k]!)),
                        const SizedBox(height: 8),
                        _buildFirestoreSection(groups[k]!),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kDark),
            ),
          ),
          const Spacer(),
          Text('Transaction History',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _kDark)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.filter_list_rounded, size: 20, color: _kDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _kSoft, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildFirestoreSection(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Column(
      children: [
        for (int i = 0; i < docs.length; i++) ...[
          _buildFirestoreTxCard(docs[i].data()),
          if (i < docs.length - 1) const SizedBox(height: 10),
        ]
      ],
    );
  }

  Widget _buildFirestoreTxCard(Map<String, dynamic> d) {
    final title = (d['title'] ?? 'Transaction').toString();
    final earned = (d['type'] ?? 'earn') == 'earn';
    final amount = _fmtInr(d['amount_inr']);
    final status = (d['status'] ?? 'completed').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: earned ? _kEmerald.withValues(alpha: 0.10) : const Color(0xFFFEEBEB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              earned ? Icons.recycling_rounded : Icons.redeem_rounded,
              color: earned ? _kEmerald : const Color(0xFFE74C3C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(status, style: GoogleFonts.inter(fontSize: 11, color: _kSoft)),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: earned ? _kEmerald : const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Painter ─────────────────────────────────────────────────────────
class _TimelinePainter extends CustomPainter {
  final int count;
  const _TimelinePainter({required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    const dotR = 5.0;
    const dotSpacing = 10.0 + 80.0; // approx card height + gap

    final linePaint = Paint()
      ..color = const Color(0xFFDDE3EA)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = _kEmerald;
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    // Draw vertical line
    if (count > 1) {
      canvas.drawLine(
        Offset(cx, dotR * 2),
        Offset(cx, size.height - dotR * 2),
        linePaint,
      );
    }

    // Draw individual dots evenly spaced
    final step = count > 1 ? size.height / (count - 1) : size.height / 2;
    for (int i = 0; i < count; i++) {
      final y = count == 1 ? size.height / 2 : i * step;
      canvas.drawCircle(Offset(cx, y), dotR, dotPaint);
      canvas.drawCircle(Offset(cx, y), dotR, dotBorder);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.count != count;
}
