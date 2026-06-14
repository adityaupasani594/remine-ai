import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/recycler_verification_service.dart';

class RecyclerTransactionScanScreen extends StatefulWidget {
  const RecyclerTransactionScanScreen({super.key});

  @override
  State<RecyclerTransactionScanScreen> createState() =>
      _RecyclerTransactionScanScreenState();
}

class _RecyclerTransactionScanScreenState
    extends State<RecyclerTransactionScanScreen> {
  bool _verifying = false;
  String? _error;
  bool _scanned = false;

  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  Map<String, dynamic> get _args {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) return args;
    return {};
  }

  String get _transactionId {
    final id = (_args['transaction_id'] ?? _args['id'] ?? '').toString();
    if (id.isEmpty) throw StateError('Missing transaction id');
    return id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(String raw) async {
    if (_verifying || _scanned) return;

    setState(() {
      _verifying = true;
      _error = null;
      _scanned = true;
    });

    try {
      // Accept either plain OTP or a structured payload.
      // Supported payload forms:
      // 1) OTP only: ABC123
      // 2) "TX:<id>|OTP:<otp>"
      final value = raw.trim();
      String otp = value;

      if (value.toUpperCase().startsWith('TX:')) {
        final parts = value.split('|');
        final txPart = parts.firstWhere(
          (p) => p.toUpperCase().startsWith('TX:'),
          orElse: () => '',
        );
        final otpPart = parts.firstWhere(
          (p) => p.toUpperCase().startsWith('OTP:'),
          orElse: () => '',
        );

        final scannedTxId = txPart.replaceFirst(RegExp(r'^TX:', caseSensitive: false), '').trim();
        otp = otpPart.replaceFirst(RegExp(r'^OTP:', caseSensitive: false), '').trim();

        if (scannedTxId.isNotEmpty && scannedTxId != _transactionId) {
          throw StateError('This QR belongs to a different transaction.');
        }
      }

      await RecyclerVerificationService().verifyAndComplete(
        transactionId: _transactionId,
        scannedOtp: otp,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanned = false;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Widget _infoTile(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8A9BAE)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = _args;
    final device = (tx['device_name'] ?? '').toString();
    final userId = (tx['user_id'] ?? '').toString();
    final amount = ((tx['amount_inr'] ?? 0.0) as num).toDouble();
    final gc = ((tx['gc_delta'] ?? 0) as num).toInt();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan QR', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue;
                    if (raw == null || raw.trim().isEmpty) return;
                    _onDetect(raw);
                  },
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _verifying ? 'Verifying…' : 'Scan the handoff QR/code shown by the user',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (_error != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom sheet info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transaction', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A3C2B))),
                const SizedBox(height: 10),
                _infoTile(Icons.qr_code_rounded, 'ID', _transactionId),
                _infoTile(Icons.devices_rounded, 'Device', device),
                _infoTile(Icons.person_outline_rounded, 'User', userId),
                _infoTile(Icons.currency_rupee_rounded, 'Value', '₹${amount.toStringAsFixed(0)}'),
                _infoTile(Icons.eco_outlined, 'Credits', '+$gc GC'),
                const SizedBox(height: 6),
                Text(
                  'After a successful scan, green credits are transferred immediately to the user.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
