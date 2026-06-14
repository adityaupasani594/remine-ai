import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  static const Color _emerald = Color(0xFF2ECC71);
  static const Color _forestGreen = Color(0xFF1A3C2B);
  static const Color _softGray = Color(0xFF8A9BAE);
  static const Color _inputBg = Color(0xFFF4F7F5);
  static const Color _dividerColor = Color(0xFFE5EBE8);

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'This email address is already registered.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. It must be at least 6 characters.';
        case 'account-exists-with-different-credential':
          return 'This email is already linked to another sign-in method.';
        case 'operation-not-allowed':
          return 'Sign-in method not enabled in Firebase Authentication.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }

    if (error is FirebaseException) {
      return error.message ?? 'Firebase error. Please try again.';
    }

    if (error is PlatformException) {
      return error.message ??
          'A device sign-in error occurred. Please try again.';
    }

    return 'Unexpected error. Please try again.';
  }

  Future<void> _submitEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    if (!_isLogin && name.isEmpty) {
      _showMessage('Please provide your name.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        // Login Flow
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Registration Flow
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(email: email, password: password);

        final User? user = userCredential.user;

        if (user != null) {
          await user.updateDisplayName(name);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': name,
                'email': email,
                'phone': '',
                'role': 'household',
                'green_credits_balance': 0,
                'total_items_recycled': 0,
                'co2_saved_kg': 0.0,
                'metals_recovered_g': 0.0,
                'created_at': FieldValue.serverTimestamp(),
                'is_verified': true,
              });
        }
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email Auth Error: $e');
      }
      _showMessage(_friendlyAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email address to reset the password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent. Please check your inbox.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Password Reset Error: $e');
      }
      _showMessage(_friendlyAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();
      if (googleUser == null) {
        // The user canceled the sign-in flow
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': user.displayName ?? 'Unknown User',
                'email': user.email ?? '',
                'phone': '',
                'role': 'household',
                'green_credits_balance': 0,
                'total_items_recycled': 0,
                'co2_saved_kg': 0.0,
                'metals_recovered_g': 0.0,
                'created_at': FieldValue.serverTimestamp(),
                'is_verified': true,
              });
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected sign-in error: $e');
      }
      _showMessage(_friendlyAuthMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 14, color: _forestGreen),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _softGray, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _softGray),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset:
          false, // Prevents overflow when keyboard appears if it's not scrollable
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: _forestGreen,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Leaf icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: _emerald, size: 26),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Welcome',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _forestGreen,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              RichText(
                text: TextSpan(
                  text: 'Login or Register to access your ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _softGray,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'Green Credits.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _emerald,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tabs (Login / Register)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _isLogin ? _emerald : _dividerColor,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Login',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: _isLogin
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _isLogin ? _emerald : _softGray,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: !_isLogin ? _emerald : _dividerColor,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Register',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: !_isLogin
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: !_isLogin ? _emerald : _softGray,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Input Fields
              if (!_isLogin) ...[
                _buildTextField(
                  controller: _nameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
              ],

              _buildTextField(
                controller: _emailController,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _emerald,
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEmailPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Login' : 'Create Account',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Divider
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: _dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _softGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: _dividerColor)),
                ],
              ),

              const SizedBox(height: 28),

              // Google sign-in button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _dividerColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "G",
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Continue with Google',
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
