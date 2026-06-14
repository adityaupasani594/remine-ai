import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kSoft = Color(0xFF8A9BAE);

class RecyclerProfileScreen extends StatelessWidget {
  const RecyclerProfileScreen({super.key});

  static const _materials = [
    (Icons.smartphone_rounded, 'Mobile'),
    (Icons.laptop_rounded, 'Laptop'),
    (Icons.battery_full_rounded, 'Battery'),
    (Icons.ac_unit_rounded, 'AC'),
    (Icons.tv_rounded, 'TV'),
    (Icons.print_rounded, 'Printer'),
  ];

  static const _stats = [
    (Icons.star_rounded, '4.8', 'Rating', Color(0xFFFFC107)),
    (Icons.recycling_rounded, '1.2k', 'Pickups', _kEmerald),
    (Icons.military_tech_rounded, 'Top', 'Rated', Color(0xFF9B59B6)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildCoverHeader(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameRow(),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Accepted Materials'),
                      const SizedBox(height: 12),
                      _buildMaterialsRow(),
                      const SizedBox(height: 24),
                      _buildPricingBadge(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('About'),
                      const SizedBox(height: 8),
                      _buildAboutText(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Recent Reviews'),
                      const SizedBox(height: 12),
                      _buildReviewCard(),
                      const SizedBox(height: 100), // bottom action bar space
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sticky bottom action bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildActionBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.white,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: _kDark, size: 20),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: _kDark, size: 18),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover photo gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3932), Color(0xFF2ECC71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative shapes
            Positioned(
              right: -30, top: -20,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              left: 40, bottom: 20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Cover text
            Positioned(
              left: 20, bottom: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text('Koramangala, Bengaluru',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Circular logo
            Positioned(
              left: 20, bottom: -30,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
                ),
                child: const Icon(Icons.recycling_rounded, color: _kEmerald, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 82),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Green Earth Scrap',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: _kDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: Color(0xFF3498DB), size: 18),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Verified Partner',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3498DB), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(_stats.length, (i) {
          final s = _stats[i];
          return Expanded(
            child: Column(
              children: [
                Icon(s.$1, color: s.$4, size: 22),
                const SizedBox(height: 6),
                Text(s.$2,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _kDark)),
                Text(s.$3,
                  style: GoogleFonts.inter(fontSize: 11, color: _kSoft)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark));
  }

  Widget _buildMaterialsRow() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _materials.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = _materials[i];
          return Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kEmerald.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(m.$1, color: _kEmerald, size: 22),
              ),
              const SizedBox(height: 4),
              Text(m.$2,
                style: GoogleFonts.inter(fontSize: 10, color: _kSoft, fontWeight: FontWeight.w500)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPricingBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _kEmerald,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text('Best Market Rates',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF3498DB), size: 14),
              const SizedBox(width: 6),
              Text('Same Day Pickup',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutText() {
    return Text(
      'Green Earth Scrap is a certified e-waste recycling partner committed to responsible disposal. '
      'We recover precious metals and ensure zero landfill for all collected devices.',
      style: GoogleFonts.inter(fontSize: 13, color: _kSoft, height: 1.6),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kEmerald.withValues(alpha: 0.15),
                child: const Text('R', style: TextStyle(color: _kEmerald, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rahul M.',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kDark)),
                    Row(
                      children: List.generate(5, (_) =>
                        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 13)),
                    ),
                  ],
                ),
              ),
              Text('2 days ago',
                style: GoogleFonts.inter(fontSize: 11, color: _kSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"Super smooth experience! They picked up my old laptop and paid more than the online estimate. Highly recommend 🌿"',
            style: GoogleFonts.inter(fontSize: 13, color: _kDark, height: 1.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Call'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kEmerald,
                side: const BorderSide(color: _kEmerald, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Schedule Pickup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kEmerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
