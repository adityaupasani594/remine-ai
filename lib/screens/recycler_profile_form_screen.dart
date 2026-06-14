import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecyclerProfileFormScreen extends StatefulWidget {
  const RecyclerProfileFormScreen({super.key});

  @override
  State<RecyclerProfileFormScreen> createState() =>
      _RecyclerProfileFormScreenState();
}

class _RecyclerProfileFormScreenState extends State<RecyclerProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _distanceController = TextEditingController();
  final _hoursController = TextEditingController();
  final _categoriesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVerified = false;
  bool _isMsme = false;

  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _softGray = Color(0xFF8A9BAE);
  static const Color _inputBg = Color(0xFFF4F7F5);
  static const Color _dividerColor = Color(0xFFE5EBE8);

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No signed in recycler user.');
    return uid;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findRecyclerDocument({
    required String uid,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final directDoc = await FirebaseFirestore.instance
        .collection('recyclers')
        .doc(uid)
        .get();
    if (directDoc.exists) return directDoc;

    final byUid = await FirebaseFirestore.instance
        .collection('recyclers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) return byUid.docs.first;

    final byEmail = await FirebaseFirestore.instance
        .collection('recyclers')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byEmail.docs.isNotEmpty) return byEmail.docs.first;

    final allDocs = await FirebaseFirestore.instance.collection('recyclers').get();
    for (final d in allDocs.docs) {
      final docEmail = (d.data()['email'] ?? '').toString().trim().toLowerCase();
      if (docEmail == normalizedEmail) return d;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _distanceController.dispose();
    _hoursController.dispose();
    _categoriesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = (user?.email ?? '').trim().toLowerCase();
      final doc = await _findRecyclerDocument(uid: _uid, email: email);
      final data = doc?.data() ?? <String, dynamic>{};

      _businessNameController.text = (data['business_name'] ?? '').toString();
      _ownerNameController.text = (data['owner_name'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _emailController.text = email;
      _gstController.text = (data['gst_number'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
      _cityController.text = (data['city'] ?? '').toString();
      _distanceController.text = (data['distance_km'] ?? 0).toString();
      _hoursController.text = (data['operating_hours'] ?? '').toString();
      _isVerified = (data['is_verified'] ?? false) == true;
      _isMsme = (data['is_msme'] ?? false) == true;
      
      if (data['location'] is GeoPoint) {
        final gp = data['location'] as GeoPoint;
        _latController.text = gp.latitude.toString();
        _lngController.text = gp.longitude.toString();
      }

      final cats = List<String>.from(data['accepted_categories'] ?? const <String>[]);
      _categoriesController.text = cats.join(', ');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isProfileComplete(Map<String, dynamic> data) {
    bool has(String k) => (data[k] ?? '').toString().trim().isNotEmpty;
    return has('business_name') &&
        has('owner_name') &&
        has('phone') &&
        has('address') &&
        has('city') &&
        has('gst_number');
  }

  List<String> _parseCategories(String input) {
    return input
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = (user?.email ?? _emailController.text).trim().toLowerCase();
      final existing = await _findRecyclerDocument(uid: _uid, email: email);
      final ref = FirebaseFirestore.instance
          .collection('recyclers')
          .doc(existing?.id ?? _uid);

      final payload = <String, dynamic>{
        'uid': _uid,
        'business_name': _businessNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': email,
        'gst_number': _gstController.text.trim(),
        'is_verified': _isVerified,
        'is_msme': _isMsme,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'distance_km': double.tryParse(_distanceController.text.trim()) ?? 0.0,
        'accepted_categories': _parseCategories(_categoriesController.text),
        'operating_hours': _hoursController.text.trim(),
        'rating': existing?.data()?['rating'] ?? 0.0,
        'total_reviews': existing?.data()?['total_reviews'] ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final lat = double.tryParse(_latController.text.trim()) ?? 19.0760;
      final lng = double.tryParse(_lngController.text.trim()) ?? 72.8777;
      payload['location'] = GeoPoint(lat, lng);

      if (existing == null || !existing.exists) {
        payload['created_at'] = FieldValue.serverTimestamp();
      }

      await ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/recycler-dashboard', (r) => false, arguments: payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save recycler profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _dec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: _softGray),
      filled: true,
      fillColor: _inputBg,
      prefixIcon: Icon(icon, color: _softGray, size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _emerald, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field(String label, TextEditingController c,
      {required String hint,
      required IconData icon,
      TextInputType? type,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _forestGreen)),
        const SizedBox(height: 8),
        TextFormField(
          controller: c,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14, color: _forestGreen),
          decoration: _dec(hint, icon),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Recycler Profile',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: _forestGreen)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your recycler profile',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill all details so households can discover and trust your service.',
                  style: GoogleFonts.inter(fontSize: 13, color: _softGray),
                ),
                const SizedBox(height: 18),

                _field(
                  'Business Name',
                  _businessNameController,
                  hint: 'Green Earth Recyclers',
                  icon: Icons.business_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'Owner Name',
                  _ownerNameController,
                  hint: 'Ramesh Kumar',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'Phone',
                  _phoneController,
                  hint: '+91-9111222333',
                  icon: Icons.phone_outlined,
                  type: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'Email',
                  _emailController,
                  hint: 'greenearth@recycler.com',
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'GST Number',
                  _gstController,
                  hint: '27AABCU9603R1ZX',
                  icon: Icons.badge_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'Address',
                  _addressController,
                  hint: 'Dharavi, Mumbai, Maharashtra',
                  icon: Icons.home_work_outlined,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'City',
                  _cityController,
                  hint: 'Mumbai',
                  icon: Icons.location_city_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  'Distance (km)',
                  _distanceController,
                  hint: '1.2',
                  icon: Icons.near_me_outlined,
                  type: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _field(
                  'Operating Hours',
                  _hoursController,
                  hint: '9AM - 6PM',
                  icon: Icons.access_time_rounded,
                ),
                const SizedBox(height: 14),
                _field(
                  'Accepted Categories',
                  _categoriesController,
                  hint: 'laptop, mobile, cpu, battery',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        'Latitude',
                        _latController,
                        hint: '19.0760',
                        icon: Icons.explore_outlined,
                        type: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _field(
                        'Longitude',
                        _lngController,
                        hint: '72.8777',
                        icon: Icons.explore_outlined,
                        type: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        value: _isVerified,
                        onChanged: (v) => setState(() => _isVerified = v),
                        title: Text('Verified', style: GoogleFonts.inter(fontSize: 13, color: _forestGreen)),
                        activeColor: _emerald,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        value: _isMsme,
                        onChanged: (v) => setState(() => _isMsme = v),
                        title: Text('MSME', style: GoogleFonts.inter(fontSize: 13, color: _forestGreen)),
                        activeColor: _emerald,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emerald,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Save Profile',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
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
