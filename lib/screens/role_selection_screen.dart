import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _softGray = Color(0xFF8A9BAE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ── Logo ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: _emerald, size: 18),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Re-Mine ',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _forestGreen,
                          ),
                        ),
                        TextSpan(
                          text: 'AI',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Heading ──
              Text(
                'Welcome Back',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _forestGreen,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your workspace to begin',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _softGray,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              // ── Households Card ──
              _RoleCard(
                icon: Icons.home_rounded,
                title: 'For Households',
                subtitle: 'Turn waste into wealth',
                isPrimary: true,
                buttonLabel: 'Continue as Urban Miner',
                onTap: () => Navigator.pushNamed(context, '/login'),
              ),
              const SizedBox(height: 12),

              // ── Recyclers Card ──
              _RoleCard(
                icon: Icons.recycling_rounded,
                title: 'For Recyclers',
                subtitle: 'Source verified inventory',
                isPrimary: false,
                buttonLabel: 'Login as Partner',
                onTap: () => Navigator.pushNamed(context, '/recycler-login'),
              ),

              const Spacer(),

              // ── Decorative pill ──
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grass_rounded,
                          color: Color(0xFF52B57A), size: 28),
                      SizedBox(width: 6),
                      Icon(Icons.eco_rounded,
                          color: Color(0xFF2ECC71), size: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Create account ──
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: RichText(
                    text: TextSpan(
                      text: 'New here?  ',
                      style:
                          GoogleFonts.inter(fontSize: 13, color: _softGray),
                      children: [
                        TextSpan(
                          text: 'Create an account!',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _emerald,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: _emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Compact role card
// ─────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final String buttonLabel;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.buttonLabel,
    required this.onTap,
  });

  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _softGray = Color(0xFF8A9BAE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _emerald, size: 22),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _forestGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        GoogleFonts.inter(fontSize: 12, color: _softGray),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Full-width button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isPrimary
                ? ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: Colors.white),
                      ],
                    ),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _emerald,
                      side:
                          const BorderSide(color: _emerald, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _emerald,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.business_rounded,
                            size: 16, color: _emerald),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
