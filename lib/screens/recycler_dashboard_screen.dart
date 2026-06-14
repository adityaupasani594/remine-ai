import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/recycler_transactions_repo.dart';
import '../services/recycler_verification_service.dart';

class RecyclerDashboardScreen extends StatefulWidget {
  const RecyclerDashboardScreen({super.key});

  @override
  State<RecyclerDashboardScreen> createState() =>
      _RecyclerDashboardScreenState();
}

class _RecyclerDashboardScreenState extends State<RecyclerDashboardScreen> {
  int _selectedTab = 0;
  late Razorpay _razorpay;
  double _pendingTopupAmount = 0.0;

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _softGray = Color(0xFF8A9BAE);
  static const Color _inputBg = Color(0xFFF4F7F5);

  final _txRepo = RecyclerTransactionsRepo();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final rid = (_recyclerData['uid'] ?? _recyclerData['document_id'] ?? '').toString();
    if (rid.isEmpty || _pendingTopupAmount <= 0) return;
    
    await FirebaseFirestore.instance.collection('recyclers').doc(rid).update({
      'wallet_balance_inr': FieldValue.increment(_pendingTopupAmount),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully added ₹${_pendingTopupAmount.toStringAsFixed(0)} to wallet!'), backgroundColor: _emerald),
      );
    }
    _pendingTopupAmount = 0.0;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: Colors.red),
      );
    }
    _pendingTopupAmount = 0.0;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External wallet selected: ${response.walletName}')),
      );
    }
    _pendingTopupAmount = 0.0;
  }

  // Firestore – live stream of all incoming pickups
  Stream<QuerySnapshot> get _pickupsStream => FirebaseFirestore.instance
      .collection('pickups')
      .orderBy('created_at', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _recyclerTxStream {
    final rid = (_recyclerData['uid'] ?? _recyclerData['document_id'] ?? '')
        .toString();
    if (rid.isEmpty) {
      return const Stream.empty();
    }
    return _txRepo.streamForRecycler(rid, limit: 200);
  }

  Map<String, dynamic> get _recyclerData {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) return args;
    return {};
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _updatePickupStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('pickups').doc(docId).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _recyclerData;
    final businessName = data['business_name'] ?? 'Recycler';
    final ownerName = data['owner_name'] ?? '';
    final city = data['city'] ?? '';
    final rating = (data['rating'] ?? 0.0).toDouble();
    final totalReviews = data['total_reviews'] ?? 0;
    final isVerified = data['is_verified'] ?? false;
    final isMsme = data['is_msme'] ?? false;
    final gst = data['gst_number'] ?? '';
    final address = data['address'] ?? '';
    final operatingHours = data['operating_hours'] ?? '';
    final categories = List<String>.from(data['accepted_categories'] ?? []);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(
            businessName,
            ownerName,
            city,
            rating,
            totalReviews,
            isVerified,
            isMsme,
          ),
          _buildTabBar(),
          Expanded(
            child: _selectedTab == 0
                ? _buildPickupsTab()
                : _selectedTab == 1
                ? _buildProfileTab(
                    data: data,
                    gst: gst,
                    address: address,
                    operatingHours: operatingHours,
                    categories: categories,
                    isVerified: isVerified,
                    isMsme: isMsme,
                  )
                : _selectedTab == 2
                ? _buildWalletTab()
                : _buildAnalyticsTab(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────
  Widget _buildHeader(
    String businessName,
    String ownerName,
    String city,
    double rating,
    int totalReviews,
    bool isVerified,
    bool isMsme,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3C2B), Color(0xFF2ECC71)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: logo + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.recycling_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Re-Mine AI',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Sign Out',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Business avatar + name
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ownerName.isNotEmpty ? 'Owner: $ownerName' : city,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Stats row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _headerStat(
                    Icons.star_rounded,
                    '${rating.toStringAsFixed(1)}★',
                    'Rating',
                  ),
                  _headerStat(
                    Icons.rate_review_rounded,
                    '$totalReviews',
                    'Reviews',
                  ),
                  if (isVerified)
                    _headerBadge(Icons.verified_rounded, 'Verified'),
                  if (isMsme)
                    _headerBadge(Icons.workspace_premium_rounded, 'MSME'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _amber, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Tab bar
  // ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (Icons.inbox_rounded, 'Pickups'),
      (Icons.badge_rounded, 'Profile'),
      (Icons.account_balance_wallet_rounded, 'Wallet'),
      (Icons.bar_chart_rounded, 'Analytics'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? _emerald.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? _emerald.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      tabs[i].$1,
                      color: selected ? _emerald : _softGray,
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].$2,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? _emerald : _softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Pickups Tab
  // ──────────────────────────────────────────────────────────────
  Widget _buildPickupsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recyclerTxStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _emerald),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Pickups Error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading pickups',
                    style: GoogleFonts.inter(color: _softGray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final rawDocs = snapshot.data?.docs ?? const [];
        final docs = rawDocs.toList()
          ..sort((a, b) {
            final aDate =
                (a.data()['created_at'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            final bDate =
                (b.data()['created_at'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            return bDate.compareTo(aDate); // Descending
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _inputBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    color: _softGray,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pickup requests yet',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Requests assigned to your recycler will appear here.',
                  style: GoogleFonts.inter(fontSize: 13, color: _softGray),
                ),
              ],
            ),
          );
        }

        final pending = docs
            .where((d) => (d.data()['status'] ?? '') == 'pending')
            .toList();
        final others = docs
            .where((d) => (d.data()['status'] ?? '') != 'pending')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              _sectionHeader('🔔 Pending Pickups', pending.length, _amber),
              const SizedBox(height: 8),
              ...pending.map((d) => _transactionCard(d)),
              const SizedBox(height: 20),
            ],
            if (others.isNotEmpty) ...[
              _sectionHeader('📦 History', others.length, _softGray),
              const SizedBox(height: 8),
              ...others.map((d) => _transactionCard(d)),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _forestGreen,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final deviceName = (data['device_name'] ?? 'Device').toString();
    final status = (data['status'] ?? 'pending').toString();
    final userId = (data['user_id'] ?? '').toString();
    final amount = ((data['amount_inr'] ?? 0.0) as num).toDouble();

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = _forestGreen;
        statusIcon = Icons.task_alt_rounded;
        statusLabel = 'Completed';
        break;
      default:
        statusColor = _amber;
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    color: _emerald,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _forestGreen,
                        ),
                      ),
                      Text(
                        'Est. ₹${amount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (userId.isNotEmpty)
              _infoRow(Icons.person_outline_rounded, 'User: $userId'),
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _amber,
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: Text(
                      'Scan QR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () async {
                      final ok = await Navigator.pushNamed(
                        context,
                        '/recycler/scan-transaction',
                        arguments: {...data, 'transaction_id': doc.id},
                      );
                      if (ok == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Verified and completed.',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            backgroundColor: _emerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showManualOtpDialog(doc.id, data),
                    child: Text(
                      'Enter Code',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _emerald,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _softGray, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: _softGray),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _showManualOtpDialog(
    String txId,
    Map<String, dynamic> data,
  ) async {
    final ctrl = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Verification',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _forestGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you cannot scan the QR, ask the user for the 6-character Handoff Code.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _softGray,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. AXY48V',
                      filled: true,
                      fillColor: _inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final code = ctrl.text.trim();
                              if (code.isEmpty) return;

                              setModalState(() => busy = true);
                              try {
                                await RecyclerVerificationService()
                                    .verifyAndComplete(
                                      transactionId: txId,
                                      scannedOtp: code,
                                    );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Verified manually.',
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                    backgroundColor: _emerald,
                                  ),
                                );
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setModalState(() => busy = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Verify Code',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Profile Tab
  // ──────────────────────────────────────────────────────────────
  Widget _buildProfileTab({
    required Map<String, dynamic> data,
    required String gst,
    required String address,
    required String operatingHours,
    required List<String> categories,
    required bool isVerified,
    required bool isMsme,
  }) {
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final city = data['city'] ?? '';
    final distanceKm = (data['distance_km'] ?? 0.0).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/recycler-profile-form',
                arguments: data,
              );
            },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _emerald,
              side: const BorderSide(color: _emerald, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Business Info Card
        _profileCard(
          title: 'Business Details',
          icon: Icons.business_rounded,
          children: [
            _profileRow('Business Name', data['business_name'] ?? ''),
            _profileRow('Owner', data['owner_name'] ?? ''),
            _profileRow('GST Number', gst),
            _profileRow('City', city),
            _profileRow('Address', address),
            _profileRow('Operating Hours', operatingHours),
            _profileRow(
              'Distance',
              '${distanceKm.toStringAsFixed(1)} km from hub',
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Contact Card
        _profileCard(
          title: 'Contact',
          icon: Icons.contact_phone_rounded,
          children: [_profileRow('Email', email), _profileRow('Phone', phone)],
        ),

        const SizedBox(height: 14),

        // Verification Card
        _profileCard(
          title: 'Verification Status',
          icon: Icons.verified_user_rounded,
          children: [
            _profileBadgeRow('GST Verified', isVerified),
            _profileBadgeRow('MSME Certified', isMsme),
          ],
        ),

        const SizedBox(height: 14),

        // Accepted categories
        _profileCard(
          title: 'Accepted Categories',
          icon: Icons.category_rounded,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) => _categoryChip(cat)).toList(),
            ),
          ],
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _profileCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _emerald, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE5EBE8), height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: _softGray),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileBadgeRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: _softGray)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: value
                  ? _emerald.withValues(alpha: 0.1)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  value ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: value ? _emerald : const Color(0xFFDC2626),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  value ? 'Yes' : 'No',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: value ? _emerald : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
    final icons = {
      'laptop': Icons.laptop_rounded,
      'mobile': Icons.smartphone_rounded,
      'cpu': Icons.memory_rounded,
      'battery': Icons.battery_full_rounded,
      'ac': Icons.ac_unit_rounded,
      'tv': Icons.tv_rounded,
      'printer': Icons.print_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _emerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _emerald.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[label.toLowerCase()] ?? Icons.devices_rounded,
            color: _emerald,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _emerald,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Analytics Tab
  // ──────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recyclerTxStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final total = docs.length;
        final completed = docs
            .where((d) => (d.data()['status'] ?? '') == 'completed')
            .length;
        final pending = docs
            .where((d) => (d.data()['status'] ?? '') == 'pending')
            .length;
        final totalValue = docs.fold<double>(
          0,
          (sum, d) =>
              sum + (((d.data()['amount_inr'] ?? 0.0) as num).toDouble()),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Performance Overview',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 14),

            // Stat grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _analyticCard(
                  'Total Requests',
                  '$total',
                  Icons.inbox_rounded,
                  _emerald,
                ),
                _analyticCard(
                  'Completed',
                  '$completed',
                  Icons.task_alt_rounded,
                  _forestGreen,
                ),
                _analyticCard(
                  'Pending',
                  '$pending',
                  Icons.hourglass_top_rounded,
                  _amber,
                ),
                _analyticCard(
                  'In Progress',
                  '${total - pending - completed}',
                  Icons.local_shipping_rounded,
                  Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Revenue card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A3C2B), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Estimated Value',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${totalValue.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'across $total assigned transactions',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _analyticCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EBE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _forestGreen,
            ),
          ),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: _softGray)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Wallet Tab
  // ──────────────────────────────────────────────────────────────
  Widget _buildWalletTab() {
    final rid = (_recyclerData['uid'] ?? _recyclerData['document_id'] ?? '').toString();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('recyclers').doc(rid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _emerald));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final walletBalance = (data['wallet_balance_inr'] as num?)?.toDouble() ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recycler Wallet',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _forestGreen),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3C2B), Color(0xFF2ECC71)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: _emerald.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Balance', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${walletBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Top Up Wallet',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _forestGreen),
              ),
              const SizedBox(height: 8),
              Text(
                'Add funds to your wallet to pay users when completing recycling transactions.',
                style: GoogleFonts.inter(fontSize: 13, color: _softGray, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTopUpDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text('Add Funds', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTopUpDialog() {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Top Up Wallet', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _forestGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter amount (in ₹) to add to your wallet:', style: GoogleFonts.inter(fontSize: 13, color: _softGray)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: _forestGreen),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: _forestGreen),
                hintText: 'e.g. 1000',
                filled: true,
                fillColor: _inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _softGray, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountCtrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                _initiateRazorpayPayment(val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Proceed', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _initiateRazorpayPayment(double amountInr) {
    _pendingTopupAmount = amountInr;
    final key = dotenv.env['RAZORPAY_KEY'];
    if (key == null || key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Razorpay key not found in .env file'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final options = {
      'key': key,
      'amount': (amountInr * 100).toInt(), // amount in the smallest currency sub-unit.
      'name': 'Re-Mine AI',
      'description': 'Wallet Top-up',
      'prefill': {
        'contact': _recyclerData['phone'] ?? '',
        'email': _recyclerData['email'] ?? '',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start payment. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
