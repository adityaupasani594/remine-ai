import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _kEmerald = Color(0xFF2ECC71);
const Color _kDark = Color(0xFF2C3E50);
const Color _kSoft = Color(0xFF8A9BAE);

// ─── Model ────────────────────────────────────────────────────────────────────
enum _Tab { vouchers, donations, products }

class _RewardItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final int price;
  final Color color;
  final _Tab tab;
  const _RewardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
    required this.tab,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  _Tab _activeTab = _Tab.vouchers;

  static const _allItems = [
    _RewardItem(icon: Icons.shopping_bag_rounded, title: 'Amazon Voucher', subtitle: '₹200 off', price: 200, color: Color(0xFFFF9900), tab: _Tab.vouchers),
    _RewardItem(icon: Icons.fastfood_rounded, title: 'Swiggy Coupon', subtitle: '₹100 off', price: 150, color: Color(0xFFFF6B35), tab: _Tab.vouchers),
    _RewardItem(icon: Icons.local_movies_rounded, title: 'Netflix 1 Month', subtitle: 'Premium Plan', price: 350, color: Color(0xFFE50914), tab: _Tab.vouchers),
    _RewardItem(icon: Icons.electric_bolt_rounded, title: 'Electricity Bill', subtitle: 'BESCOM / MSEB', price: 120, color: Color(0xFF3498DB), tab: _Tab.vouchers),
    _RewardItem(icon: Icons.park_rounded, title: 'Plant a Tree', subtitle: 'Offset 10kg CO₂', price: 50, color: _kEmerald, tab: _Tab.donations),
    _RewardItem(icon: Icons.water_drop_rounded, title: 'Clean Water', subtitle: 'Charity: Water', price: 80, color: Color(0xFF3498DB), tab: _Tab.donations),
    _RewardItem(icon: Icons.favorite_rounded, title: 'NGO Donation', subtitle: 'Greenpeace India', price: 30, color: Color(0xFFE74C3C), tab: _Tab.donations),
    _RewardItem(icon: Icons.recycling_rounded, title: 'Compost Kit', subtitle: 'Home composting', price: 400, color: _kEmerald, tab: _Tab.products),
    _RewardItem(icon: Icons.light_mode_rounded, title: 'Solar Lamp', subtitle: 'Off-grid lighting', price: 600, color: Color(0xFFFFC107), tab: _Tab.products),
    _RewardItem(icon: Icons.backpack_rounded, title: 'Eco Tote Bag', subtitle: 'Recyclable fabric', price: 90, color: Color(0xFF9B59B6), tab: _Tab.products),
  ];

  List<_RewardItem> get _filtered => _allItems.where((i) => i.tab == _activeTab).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildBalanceCard(),
            const SizedBox(height: 20),
            _buildFilterTabs(),
            const SizedBox(height: 16),
            Expanded(child: _buildGrid()),
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
          Text('Marketplace',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _kDark)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search_rounded, size: 20, color: _kDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3932), Color(0xFF2ECC71)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: _kEmerald.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            // Glassmorphism circles
            Positioned(
              top: -20, right: -10,
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: 100,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Glass shimmer
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.eco_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 5),
                          Text('Available Balance',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('850 GC',
                        style: GoogleFonts.inter(
                          fontSize: 36, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1,
                        )),
                      const SizedBox(height: 4),
                      Text('≈ ₹850 cash value',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text('Redeem',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      (_Tab.vouchers, 'Vouchers'),
      (_Tab.donations, 'Donations'),
      (_Tab.products, 'Products'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: tabs.map((t) {
          final active = _activeTab == t.$1;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _kEmerald : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _kEmerald : const Color(0xFFDDE3EA),
                  width: 1.5,
                ),
              ),
              child: Text(
                t.$2,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _kSoft,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildRewardCard(items[i]),
    );
  }

  Widget _buildRewardCard(_RewardItem item) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const Spacer(),
            Text(item.title,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _kDark),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(item.subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: _kSoft),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            // Price pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_rounded, color: _kEmerald, size: 11),
                  const SizedBox(width: 4),
                  Text('${item.price} GC',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _kEmerald)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
