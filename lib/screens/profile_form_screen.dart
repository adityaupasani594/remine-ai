import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_profile_repo.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _repo = UserProfileRepo();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Impact / wallet fields (so there’s no static UI data anywhere)
  final _co2Ctrl = TextEditingController();
  final _metalsCtrl = TextEditingController();
  final _energyCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _gcCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _co2Ctrl.dispose();
    _metalsCtrl.dispose();
    _energyCtrl.dispose();
    _waterCtrl.dispose();
    _gcCtrl.dispose();
    _cashCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _repo.getOnce();
      final data = snap.data() ?? {};

      _nameCtrl.text = (data['name'] ?? '').toString();
      _phoneCtrl.text = (data['phone'] ?? '').toString();

      _co2Ctrl.text = (data['co2_saved_kg'] ?? 0).toString();
      _metalsCtrl.text = (data['metals_recovered_g'] ?? 0).toString();

      _gcCtrl.text = (data['green_credits_balance'] ?? 0).toString();

      _itemsCtrl.text = (data['total_items_recycled'] ?? 0).toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _toDouble(String v) => double.tryParse(v.trim()) ?? 0;
  int _toInt(String v) => int.tryParse(v.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await _repo.upsert({
        // Your schema
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'co2_saved_kg': _toDouble(_co2Ctrl.text),
        'metals_recovered_g': _toDouble(_metalsCtrl.text),
        'green_credits_balance': _toInt(_gcCtrl.text),
        'total_items_recycled': _toInt(_itemsCtrl.text),
        // Don't touch created_at here
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF2ECC71)),
      filled: true,
      fillColor: const Color(0xFFF4F7F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Basic', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2C3E50))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _dec('Name', 'Optional', Icons.person_outline_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: _dec('Phone', 'Optional', Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 22),
                      Text('Impact', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2C3E50))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _co2Ctrl,
                        decoration: _dec('CO₂ Saved (kg)', 'e.g. 12.4', Icons.cloud_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _metalsCtrl,
                        decoration: _dec('Metals Recovered (g)', 'e.g. 340', Icons.hardware_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _itemsCtrl,
                        decoration: _dec('Items Recycled', 'e.g. 3', Icons.recycling_rounded),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 22),
                      Text('Wallet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2C3E50))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gcCtrl,
                        decoration: _dec('Green Credits', 'e.g. 245', Icons.eco_outlined),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text('Save', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
