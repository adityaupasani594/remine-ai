import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/gemini_service.dart';

const Color kEmerald = Color(0xFF2ECC71);
const Color kDarkSlate = Color(0xFF2C3E50);
const Color kForestGreen = Color(0xFF1E3932);

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late AnimationController _scanLineController;
  late AnimationController _progressController;
  late Animation<double> _scanLineAnim;
  late Animation<double> _progressAnim;

  // ── State machine ──────────────────────────────────────────────────────────
  _ScanState _state = _ScanState.idle;
  File? _capturedImage;
  String? _errorMsg;
  String? _errorDetails;
  DeviceAnalysis? _analysis;

  final List<String> _statusMessages = [
    'Initialising AI model…',
    'Detecting materials…',
    'Calculating scrap value…',
    'Finalising report…',
  ];
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Open camera immediately on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ── Camera & Gemini ────────────────────────────────────────────────────────
  Future<void> _openCamera() async {
    final picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1280,
        requestFullMetadata: false,
      );

      if (photo == null) {
        if (!mounted) return;
        setState(() => _state = _ScanState.idle);
        return;
      }

      await _handlePickedFile(photo);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Camera unavailable (${e.code}). Try gallery.';
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Camera plugin not loaded. Restart app and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Could not open camera. Try again or use gallery.';
      });
    }
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        requestFullMetadata: false,
      );

      if (photo == null) return;
      await _handlePickedFile(photo);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Gallery unavailable (${e.code}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMsg = 'Could not open gallery.';
      });
    }
  }

  Future<void> _handlePickedFile(XFile photo) async {
    setState(() {
      _capturedImage = File(photo.path);
      _state = _ScanState.analysing;
      _statusIndex = 0;
      _errorMsg = null;
    });

    _progressController
      ..reset()
      ..forward();

    _startStatusCycle();
    await _runGeminiAnalysis();
  }

  void _startStatusCycle() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _state != _ScanState.analysing) return;
      setState(() => _statusIndex = (_statusIndex + 1) % _statusMessages.length);
      _startStatusCycle();
    });
  }

  Future<void> _runGeminiAnalysis() async {
    try {
      final analysis = await GeminiService.analyseImage(_capturedImage!);
      if (!mounted) return;

      if (!analysis.isElectronic) {
        _progressController.stop();
        setState(() {
          _state = _ScanState.error;
          _errorMsg = analysis.userMessage.isNotEmpty
              ? analysis.userMessage
              : 'That doesn’t look like an electronic item. Please scan e-waste (phone, laptop, charger, PCB, etc.)';
          _errorDetails = 'Gemini classified image as non-electronic.';
        });
        return;
      }

      setState(() {
        _analysis = analysis;
        _state = _ScanState.done;
      });
      // Navigate after brief pause so user sees 100%
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/valuation',
          arguments: analysis,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _progressController.stop();

      final raw = e.toString();
      final friendly = raw.contains('Gemini API key not set')
          ? 'Gemini API key not configured.'
          : raw.contains('Network error')
              ? 'Network error. Check your connection.'
              : raw.contains('Gemini API error:')
                  ? 'Gemini request failed.'
                  : raw.contains('Could not parse Gemini response:')
                      ? 'Gemini returned an unexpected response format.'
                      : 'Analysis failed. Please try again.';

      setState(() {
        _state = _ScanState.error;
        _errorMsg = friendly;
        _errorDetails = raw;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: captured image or gradient
          if (_capturedImage != null)
            Image.file(_capturedImage!, fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF1A2A1A), Color(0xFF050A05)],
                ),
              ),
            ),

          // Dark overlay when analysing
          if (_state == _ScanState.analysing || _state == _ScanState.done)
            Container(color: Colors.black.withValues(alpha: 0.55)),

          // Noise texture
          CustomPaint(painter: _NoisePainter()),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _state == _ScanState.idle ? 'AI Scan' : 'Analysing…',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      // Retake button when showing image
                      if (_state == _ScanState.error || _state == _ScanState.idle)
                        GestureDetector(
                          onTap: _openCamera,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          ),
                        )
                      else
                        const SizedBox(width: 36),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Viewfinder / spinner ──
                if (_state == _ScanState.analysing || _state == _ScanState.done)
                  _buildAnalysingIndicator()
                else if (_state == _ScanState.error)
                  _buildErrorWidget()
                else
                  _buildViewfinder(),

                const Spacer(),

                // ── Bottom sheet ──
                _buildBottomSheet(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────
  Widget _buildViewfinder() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _scanLineAnim,
            builder: (_, __) => Positioned(
              top: _scanLineAnim.value * 250,
              left: 10,
              right: 10,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      kEmerald.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          ..._buildBrackets(),
        ],
      ),
    );
  }

  Widget _buildAnalysingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                color: kEmerald,
                value: _state == _ScanState.done ? 1.0 : null,
              ),
              Icon(
                _state == _ScanState.done
                    ? Icons.check_rounded
                    : Icons.memory_rounded,
                color: Colors.white,
                size: 32,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _state == _ScanState.done
              ? 'Analysis complete!'
              : _statusMessages[_statusIndex],
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
        const SizedBox(height: 16),
        Text(
          _errorMsg ?? 'Something went wrong.',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (_errorDetails != null) ...[
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              _errorDetails!,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                height: 1.25,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Camera'),
              style: ElevatedButton.styleFrom(backgroundColor: kEmerald),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _openGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Use Gallery'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _state == _ScanState.analysing
                      ? Colors.orange
                      : _state == _ScanState.done
                          ? kEmerald
                          : _state == _ScanState.error
                              ? Colors.redAccent
                              : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _state == _ScanState.idle
                      ? 'Opening camera…'
                      : _state == _ScanState.analysing
                          ? _statusMessages[_statusIndex]
                          : _state == _ScanState.done
                              ? 'Redirecting to report…'
                              : 'Analysis failed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kDarkSlate,
                  ),
                ),
              ),
              if (_state == _ScanState.analysing)
                AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => Text(
                    '${(_progressAnim.value * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kEmerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => LinearProgressIndicator(
                value: _state == _ScanState.done
                    ? 1.0
                    : _state == _ScanState.analysing
                        ? _progressAnim.value
                        : null,
                minHeight: 6,
                backgroundColor: const Color(0xFFE8F5EE),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _state == _ScanState.error ? Colors.redAccent : kEmerald,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Detected components:',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A9BAE)),
          ),
          const SizedBox(height: 8),
          if (_state == _ScanState.analysing)
            Text(
              'Running Gemini AI analysis on your photo…',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE)),
            )
          else if (_state == _ScanState.done && _analysis != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _analysis!.detectedComponents
                  .map((item) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kEmerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: kForestGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            )
          else
            Text(
              'Point camera at your e-waste device.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8A9BAE)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildBrackets() {
    const size = 30.0;
    const thickness = 3.0;
    const color = Colors.white;
    return [
      Positioned(top: 0, left: 0, child: _Bracket(size: size, stroke: thickness, color: color, corners: {0})),
      Positioned(top: 0, right: 0, child: _Bracket(size: size, stroke: thickness, color: color, corners: {1})),
      Positioned(bottom: 0, left: 0, child: _Bracket(size: size, stroke: thickness, color: color, corners: {2})),
      Positioned(bottom: 0, right: 0, child: _Bracket(size: size, stroke: thickness, color: color, corners: {3})),
    ];
  }
}

enum _ScanState { idle, analysing, done, error }

// ── Reused helpers ─────────────────────────────────────────────────────────────
class _Bracket extends StatelessWidget {
  final double size;
  final double stroke;
  final Color color;
  final Set<int> corners;
  const _Bracket({required this.size, required this.stroke, required this.color, required this.corners});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _BracketPainter(stroke: stroke, color: color, corners: corners),
      );
}

class _BracketPainter extends CustomPainter {
  final double stroke;
  final Color color;
  final Set<int> corners;
  const _BracketPainter({required this.stroke, required this.color, required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final d = size.width;
    for (final c in corners) {
      switch (c) {
        case 0:
          canvas.drawLine(const Offset(0, 0), Offset(d, 0), paint);
          canvas.drawLine(const Offset(0, 0), Offset(0, d), paint);
          break;
        case 1:
          canvas.drawLine(Offset(0, 0), Offset(d, 0), paint);
          canvas.drawLine(Offset(d, 0), Offset(d, d), paint);
          break;
        case 2:
          canvas.drawLine(Offset(0, 0), Offset(0, d), paint);
          canvas.drawLine(Offset(0, d), Offset(d, d), paint);
          break;
        case 3:
          canvas.drawLine(Offset(0, d), Offset(d, d), paint);
          canvas.drawLine(Offset(d, 0), Offset(d, d), paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.015);
    for (var i = 0; i < 2000; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
