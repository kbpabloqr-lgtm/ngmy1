import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/user_account_service.dart';
import '../services/firebase_auth_service.dart';
import 'home.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _appLogoPath;

  @override
  void initState() {
    super.initState();
    _loadAppLogo();
  }

  Future<void> _loadAppLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final logoPath = prefs.getString('app_logo_path');
    if (mounted) {
      setState(() => _appLogoPath = logoPath);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userService = UserAccountService.instance;
      bool success = false;

      if (_isLogin) {
        debugPrint('🔐 Attempting login...');

        final firebaseAuth = FirebaseAuthService();
        bool firebaseSucceeded = false;

        try {
          firebaseSucceeded = await firebaseAuth.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          success = firebaseSucceeded;

          if (firebaseSucceeded && mounted) {
            debugPrint('✅ Firebase login successful');
            // Also login to local service for offline compatibility
            final localSyncSuccess = await userService.login(
              _emailController.text.trim(),
              _passwordController.text,
            );

            if (!localSyncSuccess) {
              debugPrint('⚠️ Local login sync failed even though Firebase auth succeeded');
            }

            // Pull all user data from Firebase
            if (firebaseAuth.currentUserId != null) {
              debugPrint('📥 Pulling user data from Firebase...');
              try {
                await firebaseAuth.getAllUserData(firebaseAuth.currentUserId!);
              } catch (e) {
                debugPrint('⚠️ Could not pull data from Firebase: $e');
                // Continue anyway - local data exists
              }
            }
          }
        } catch (firebaseError) {
          debugPrint('⚠️ Firebase login threw an error: $firebaseError');
        }

        if (!success) {
          // Firebase failed or returned false; try local authentication
          debugPrint('🔄 Firebase auth unavailable or failed. Trying local auth fallback...');
          final localLoginSuccess = await userService.login(
            _emailController.text.trim(),
            _passwordController.text,
          );

          if (localLoginSuccess) {
            success = true;
            debugPrint('✅ Local login successful (Firebase unavailable or out of sync)');
          } else {
            debugPrint('❌ Local login also failed after Firebase attempt');
          }
        }
      } else {
        // Register - try Firebase first, fall back to local
        debugPrint('📝 Attempting registration...');
        
        try {
          final firebaseAuth = FirebaseAuthService();
          success = await firebaseAuth.register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          if (success && mounted) {
            debugPrint('✅ Firebase registration successful');
          }
        } catch (firebaseError) {
          debugPrint('⚠️ Firebase registration failed, trying local: $firebaseError');
          // Firebase failed, use local registration
          success = false;
        }

        // Always register locally
        if (mounted) {
          success = await userService.register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          if (success) {
            debugPrint('✅ Local registration successful');
          }
        }
      }

      if (success && mounted) {
        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else if (mounted) {
        if (_isLogin) {
          // Try to give more specific error for login
          final userService = UserAccountService.instance;
          final users = await userService.getAllUsers();
          final userExists = users.any((u) => u.email == _emailController.text.trim());
          
          String errorMsg = 'Login failed';
          if (!userExists) {
            errorMsg = 'No account found with this email';
          } else {
            errorMsg = 'Incorrect password - please check your password and try again';
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Registration failed - email may be in use or password too short'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Unexpected error during auth: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F3460),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button to onboarding
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white70,
                      size: 24,
                    ),
                    tooltip: 'Back',
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // App logo/title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withAlpha(51),
                            width: 1,
                          ),
                        ),
                        child: _appLogoPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(
                                  File(_appLogoPath!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.storefront_rounded,
                                      size: 40,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.storefront_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'NGMY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome back!' : 'Create your account',
                        style: TextStyle(
                          color: Colors.white.withAlpha(179),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name field (only for registration)
                      if (!_isLogin) ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Email field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white.withAlpha(179),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (!_isLogin && value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1A1A2E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Toggle between login/register
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withAlpha(179),
                              fontSize: 16,
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin 
                                    ? "Don't have an account? " 
                                    : "Already have an account? ",
                              ),
                              TextSpan(
                                text: _isLogin ? 'Sign Up' : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
        prefixIcon: Icon(icon, color: Colors.white.withAlpha(179)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(51)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(51)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}