import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_screen.dart';
import 'map_screen.dart';
import 'wallet_screen.dart';
import 'impact_profile_screen.dart';

const Color kEmerald = Color(0xFF2ECC71);

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboardScreen(),
    MapScreen(),
    WalletScreen(),
    ImpactProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildScanFab() {
    return FloatingActionButton(
      onPressed: () => Navigator.pushNamed(context, '/scan'),
      backgroundColor: kEmerald,
      elevation: 8,
      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.map_rounded, 'Map'),
      (Icons.account_balance_wallet_rounded, 'Wallet'),
      (Icons.person_outline_rounded, 'Profile'),
    ];
    return BottomAppBar(
      height: 68,
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black12,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < 2; i++)
            _NavItem(
              icon: items[i].$1,
              label: items[i].$2,
              selected: _selectedIndex == i,
              onTap: () => _onItemTapped(i),
            ),
          const SizedBox(width: 52), // Space for FAB
          for (int i = 2; i < items.length; i++)
            _NavItem(
              icon: items[i].$1,
              label: items[i].$2,
              selected: _selectedIndex == i,
              onTap: () => _onItemTapped(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? kEmerald : const Color(0xFF8A9BAE), size: 24),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? kEmerald : const Color(0xFF8A9BAE),
              )),
        ],
      ),
    );
  }
}
