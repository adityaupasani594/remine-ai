import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/pickup_service.dart';

const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kForest = Color(0xFF1E3932);
const Color _kSoft = Color(0xFF8A9BAE);

class ActiveDealScreen extends StatefulWidget {
  const ActiveDealScreen({super.key});
  @override
  State<ActiveDealScreen> createState() => _ActiveDealScreenState();
}

class _ActiveDealScreenState extends State<ActiveDealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  PickupRequestResult? _pickupResult;
  bool _completing = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pickupResult == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is PickupRequestResult) {
        _pickupResult = args;
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCompleted() async {
    if (_completing || _completed || _pickupResult == null) return;
    setState(() => _completing = true);

    try {
      final result = await PickupService().completePickup(
        pickupDocId: _pickupResult!.pickupDocId,
      );
      if (!mounted) return;
      setState(() => _completed = true);

      // Small delay so the user sees the "Verified" state before navigating
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/success',
        (route) => route.settings.name == '/home',
        arguments: result,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing deal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pickupResult == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('No pickup data.', style: GoogleFonts.inter(color: _kSoft)),
        ),
      );
    }

    final pr = _pickupResult!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: PickupService().watchPickup(pr.pickupDocId),
          builder: (context, snapshot) {
            // Determine status from stream
            String status = 'pending';
            if (snapshot.hasData && snapshot.data!.exists) {
              status = (snapshot.data!.data()?['status'] as String?) ?? 'pending';
            }

            // Trigger completion when status becomes 'completed'
            if (status == 'completed' && !_completing && !_completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _onCompleted());
            }

            final bool isCompleted = status == 'completed' || _completed;

            return Column(
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
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Active Deal',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kDark),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // balance
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),

                        // ── Status chip ──
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? _kEmerald.withValues(alpha: 0.12)
                                : const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                size: 16,
                                color: isCompleted ? _kEmerald : const Color(0xFFE67E22),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompleted ? 'Verified ✓' : 'Waiting for Recycler…',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted ? _kForest : const Color(0xFF856404),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── QR Code ──
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, child) => Transform.scale(
                            scale: isCompleted ? 1.0 : _pulseAnim.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCompleted ? _kEmerald : _kSoft).withValues(alpha: 0.18),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                              border: Border.all(
                                color: isCompleted ? _kEmerald.withValues(alpha: 0.4) : const Color(0xFFE8ECF0),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: 'TX:${pr.transactionId}|OTP:${pr.handoffOtp}',
                                  version: QrVersions.auto,
                                  size: 200,
                                  eyeStyle: QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: isCompleted ? _kEmerald : _kDark,
                                  ),
                                  dataModuleStyle: QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: isCompleted ? _kEmerald : _kDark,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Handoff Code',
                                  style: GoogleFonts.inter(fontSize: 11, color: _kSoft, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    pr.handoffOtp,
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _kDark,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Deal summary card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deal Summary',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
                              ),
                              const SizedBox(height: 16),
                              _SummaryRow(label: 'Device', value: pr.deviceName),
                              _SummaryRow(label: 'Estimated Value', value: '₹${pr.totalValueInr.toStringAsFixed(0)}'),
                              _SummaryRow(label: 'Green Credits', value: '+${pr.greenCredits} GC'),
                              const Divider(height: 24, color: Color(0xFFF0F0F0)),
                              _SummaryRow(label: 'Recycler', value: pr.recyclerName),
                              _SummaryRow(
                                label: 'Rating',
                                value: '${pr.recyclerRating} ★',
                              ),
                              _SummaryRow(label: 'Distance', value: pr.recyclerDistance),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Instructions ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _kEmerald.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kEmerald.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 16, color: _kEmerald),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How it works',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kForest),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _InstructionStep(number: '1', text: 'Show this QR code to the recycler when they arrive.'),
                              _InstructionStep(number: '2', text: 'The recycler scans it to verify the handoff.'),
                              _InstructionStep(number: '3', text: 'Your Green Credits are awarded automatically!'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
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
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _kSoft)),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number, text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _kEmerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _kEmerald),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: _kDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
