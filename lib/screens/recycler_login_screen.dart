import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RecyclerLoginScreen extends StatefulWidget {
  const RecyclerLoginScreen({super.key});

  @override
  State<RecyclerLoginScreen> createState() => _RecyclerLoginScreenState();
}

class _RecyclerLoginScreenState extends State<RecyclerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRegisterMode = false;
  String? _errorMessage;

  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _softGray = Color(0xFF8A9BAE);
  static const Color _inputBg = Color(0xFFF4F7F5);
  static const Color _dividerColor = Color(0xFFE5EBE8);
  static const Color _amber = Color(0xFFF59E0B);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _friendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No Firebase Authentication user exists for this recycler email yet. Create the auth user with this same email, or sign in with Google using the same recycler email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect for the Firebase Authentication account tied to this recycler.';
      case 'user-disabled':
        return 'This Firebase auth account has been disabled.';
      case 'network-request-failed':
        return 'Network error while contacting Firebase. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Authentication.';
      default:
        return error.message ?? 'Login failed. Please try again.';
    }
  }

  String _friendlyGoogleMessage(Object error) {
    if (error is FirebaseAuthException) {
      return _friendlyAuthMessage(error);
    }

    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was cancelled.';
      }
      if (error.description?.toLowerCase().contains('no credential') == true) {
        return 'Google sign-in could not get a credential from this device. Check your Android SHA keys, package name, and google-services.json configuration.';
      }
      return error.description ?? 'Google sign-in failed. Please try again.';
    }

    if (error is PlatformException) {
      if ((error.message ?? '').toLowerCase().contains('no credential')) {
        return 'No Google credential was available on this device. Check Google Play Services and your Firebase Android configuration.';
      }
      return error.message ?? 'A device sign-in error occurred. Please try again.';
    }

    return 'Google sign-in failed. Please try again.';
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

    final allEmailMatches = await FirebaseFirestore.instance.collection('recyclers').get();
    for (final doc in allEmailMatches.docs) {
      final docEmail = (doc.data()['email'] ?? '').toString().trim().toLowerCase();
      if (docEmail == normalizedEmail) {
        return doc;
      }
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _linkRecyclerDocument({
    required DocumentSnapshot<Map<String, dynamic>> recyclerDoc,
    required User user,
  }) async {
    final recyclerRef = FirebaseFirestore.instance
        .collection('recyclers')
        .doc(recyclerDoc.id);

    await recyclerRef.set(
      {
        'uid': user.uid,
        'email': (user.email ?? '').trim().toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return recyclerRef.get();
  }

  bool _isRecyclerProfileComplete(Map<String, dynamic> data) {
    bool has(String key) => (data[key] ?? '').toString().trim().isNotEmpty;
    return has('business_name') &&
        has('owner_name') &&
        has('phone') &&
        has('address') &&
        has('city') &&
        has('gst_number');
  }

  Future<void> _completeRecyclerSignIn(User user) async {
    final email = (user.email ?? '').trim().toLowerCase();
    var recyclerDoc = await _findRecyclerDocument(uid: user.uid, email: email);

    if (recyclerDoc != null && recyclerDoc.exists) {
      final data = recyclerDoc.data() ?? <String, dynamic>{};
      final linkedUid = (data['uid'] ?? '').toString();
      final storedEmail = (data['email'] ?? '').toString().trim().toLowerCase();
      final needsLinking = linkedUid != user.uid || storedEmail != email;

      if (needsLinking) {
        recyclerDoc = await _linkRecyclerDocument(
          recyclerDoc: recyclerDoc,
          user: user,
        );
      }
    }

    if (recyclerDoc == null || !recyclerDoc.exists) {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'This signed-in account does not match any recycler profile in Firestore. Make sure the recycler document email matches the Google/Firebase email exactly.';
      });
      return;
    }

    final recyclerData = recyclerDoc.data() ?? <String, dynamic>{};
    final args = {
      ...recyclerData,
      'document_id': recyclerDoc.id,
      'uid': recyclerData['uid'] ?? user.uid,
    };

    if (!mounted) return;

    if (_isRegisterMode || !_isRecyclerProfileComplete(recyclerData)) {
      Navigator.pushReplacementNamed(
        context,
        '/recycler-profile-form',
        arguments: args,
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/recycler-dashboard',
      arguments: args,
    );
  }

  Future<void> _upsertRecyclerProfile({
    required User user,
    String? businessName,
    String? ownerName,
    String? phone,
    String? city,
    String? address,
    String? gstNumber,
  }) async {
    final existingDoc = await _findRecyclerDocument(
      uid: user.uid,
      email: (user.email ?? '').trim().toLowerCase(),
    );

    final recyclerRef = FirebaseFirestore.instance
        .collection('recyclers')
        .doc(existingDoc?.id ?? user.uid);

    await recyclerRef.set(
      {
        'uid': user.uid,
        'business_name': (businessName ?? '').trim(),
        'owner_name': (ownerName ?? '').trim(),
        'phone': (phone ?? '').trim(),
        'email': (user.email ?? '').trim().toLowerCase(),
        'gst_number': (gstNumber ?? '').trim(),
        'is_verified': false,
        'is_msme': false,
        'address': (address ?? '').trim(),
        'city': (city ?? '').trim(),
        'rating': 0.0,
        'total_reviews': 0,
        'distance_km': 0.0,
        'accepted_categories': const <String>[],
        'operating_hours': '',
        'updated_at': FieldValue.serverTimestamp(),
        if (existingDoc == null || !existingDoc.exists) ...{
          'created_at': FieldValue.serverTimestamp(),
          'wallet_balance_inr': 0.0,
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Registration failed.');

      await user.updateDisplayName(_businessNameController.text.trim());
      await _upsertRecyclerProfile(
        user: user,
        businessName: _businessNameController.text,
        ownerName: _ownerNameController.text,
        phone: _phoneController.text,
        city: _cityController.text,
        address: _addressController.text,
        gstNumber: _gstController.text,
      );

      await _completeRecyclerSignIn(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'A recycler account with this email already exists. Switch to sign in instead.';
            break;
          case 'weak-password':
            _errorMessage = 'Password is too weak. Please use at least 6 characters.';
            break;
          default:
            _errorMessage = _friendlyAuthMessage(e);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred while creating your recycler account.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSignIn.initialize();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Google sign-in did not return a valid user.',
        );
      }

      if (_isRegisterMode) {
        await _upsertRecyclerProfile(user: user, businessName: user.displayName ?? '');
      }

      await _completeRecyclerSignIn(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyGoogleMessage(e);
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyGoogleMessage(e);
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyGoogleMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyGoogleMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Authentication failed.');

      await _completeRecyclerSignIn(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthMessage(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _inputBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: _forestGreen),
                  ),
                ),

                const SizedBox(height: 32),

                // Icon badge
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.recycling_rounded,
                      color: _amber, size: 28),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  _isRegisterMode ? 'Register Recycler' : 'Recycler Portal',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _forestGreen,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                RichText(
                  text: TextSpan(
                    text: _isRegisterMode
                        ? 'Create your '
                        : 'Sign in to manage your ',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _softGray,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: _isRegisterMode
                            ? 'recycling partner account.'
                            : 'recycling business.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _amber,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Sign in / Register toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => setState(() {
                                    _isRegisterMode = false;
                                    _errorMessage = null;
                                  }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegisterMode ? _amber : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Sign In',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_isRegisterMode ? Colors.white : _forestGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => setState(() {
                                    _isRegisterMode = true;
                                    _errorMessage = null;
                                  }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegisterMode ? _amber : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Register',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isRegisterMode ? Colors.white : _forestGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                if (_isRegisterMode) ...[
                  _buildFieldLabel('Business Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _businessNameController,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Green Earth Recyclers',
                      prefixIcon: Icons.business_rounded,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your business name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildFieldLabel('Owner Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ownerNameController,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Ramesh Kumar',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the owner name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                _buildFieldLabel('Business Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _forestGreen,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Enter your business email',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                if (_isRegisterMode) ...[
                  _buildFieldLabel('Phone'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: '+91-9111222333',
                      prefixIcon: Icons.phone_outlined,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildFieldLabel('City'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Mumbai',
                      prefixIcon: Icons.location_city_outlined,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your city';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildFieldLabel('Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Dharavi, Mumbai, Maharashtra',
                      prefixIcon: Icons.home_work_outlined,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildFieldLabel('GST Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _gstController,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: '27AABCU9603R1ZX',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your GST number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                _buildFieldLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction:
                      _isRegisterMode ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: (_) => _isRegisterMode ? _register() : _login(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _forestGreen,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _softGray,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                if (_isRegisterMode) ...[
                  const SizedBox(height: 18),
                  _buildFieldLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Re-enter your password',
                      prefixIcon: Icons.lock_person_outlined,
                    ),
                    validator: (v) {
                      if (!_isRegisterMode) return null;
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],

                if (!_isRegisterMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_isRegisterMode ? _register : _login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _amber.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isRegisterMode
                                    ? Icons.app_registration_rounded
                                    : Icons.lock_open_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isRegisterMode
                                    ? 'Create Recycler Account'
                                    : 'Sign In to Partner Portal',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(
                        child: Divider(color: _dividerColor, thickness: 1.2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        _isRegisterMode ? 'Or register with' : 'Or continue with',
                        style: GoogleFonts.inter(fontSize: 13, color: _softGray),
                      ),
                    ),
                    const Expanded(
                        child: Divider(color: _dividerColor, thickness: 1.2)),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _dividerColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRegisterMode
                              ? 'Register with Google'
                              : 'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _errorMessage = null;
                            }),
                    child: RichText(
                      text: TextSpan(
                        text: _isRegisterMode
                            ? 'Already have a recycler account? '
                            : 'Need a new recycler account? ',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _softGray,
                        ),
                        children: [
                          TextSpan(
                            text: _isRegisterMode ? 'Sign In' : 'Register',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _amber,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Contact support
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isRegisterMode
                                ? 'Fill the form and create your recycler account directly from the app.'
                                : 'Please contact support@remine.ai if you need help with your recycler account.',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          backgroundColor: _forestGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: _dividerColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded,
                            color: _softGray, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Contact Support to Register',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Info note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _softGray, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This portal is exclusively for verified recycling businesses. '
                          'Your account is created by Re-Mine AI administrators after GST & MSME verification.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _softGray,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _forestGreen,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: _softGray),
      filled: true,
      fillColor: _inputBg,
      prefixIcon: Icon(prefixIcon, color: _softGray, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _amber, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
        text: _emailController.text.trim());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, color: _forestGreen),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your business email and we\'ll send a password reset link.',
              style: GoogleFonts.inter(fontSize: 13, color: _softGray),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 14, color: _forestGreen),
              decoration: _inputDecoration(
                hint: 'Business email',
                prefixIcon: Icons.email_outlined,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: _softGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Password reset email sent to $email',
                          style: GoogleFonts.inter(fontSize: 13)),
                      backgroundColor: _emerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          e.message ?? 'Failed to send reset email.',
                          style: GoogleFonts.inter(fontSize: 13)),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send Reset Link',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
