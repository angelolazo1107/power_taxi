import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:powertaxi/core/database_helper.dart';

class LoginScreen extends StatefulWidget {
  final bool asPage;
  const LoginScreen({super.key, this.asPage = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const Color accentOrange = Color(0xFFFF7121);
  static const Color bgColor = Color(0xFF141A22);

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      alignment: Alignment.center,
      children: [
        kIsWeb ? _buildWebAdminUI() : _buildMobileDriverUI(),
        
        // Close button at top right — only show in dialog mode or if not on web landing page
        if (!widget.asPage)
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
      ],
    );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: content),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: content,
    );
  }

  Widget _buildMobileDriverUI() {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentOrange.withAlpha(80), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calculate_outlined, color: accentOrange, size: 60),
            const SizedBox(height: 12),
            const Text(
              'DRIVER TERMINAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            Text(
              'SECURE METER SESSION',
              style: TextStyle(
                color: accentOrange.withAlpha(180),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            _buildFields(),
            const SizedBox(height: 40),
            _buildLoginButton('VERIFY & START'),
          ],
        ),
      ),
    );
  }

  Widget _buildWebAdminUI() {
    return Container(
      width: 650,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentOrange.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(180),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentOrange.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_outlined, color: accentOrange, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'SYSTEM ADMINISTRATOR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const Text(
              'MANAGEMENT & CONTROL PORTAL',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(10)),
              ),
              child: _buildFields(),
            ),
            const SizedBox(height: 40),
            _buildLoginButton('AUTHORIZE ACCESS'),
          ],
        ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        _loginTextField(
          controller: _emailController,
          hint: 'Authorized Email',
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 16),
        _loginTextField(
          controller: _passwordController,
          hint: 'Secure Password',
          icon: Icons.lock_outline,
          obscure: true,
        ),
      ],
    );
  }

  Widget _loginTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        prefixIcon: Icon(icon, color: accentOrange, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange),
        ),
      ),
    );
  }

  Widget _buildLoginButton(String label) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 12,
          shadowColor: accentOrange.withAlpha(100),
        ),
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
  // Handle Login and Save Preferences
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid credentials')),
          );
        }
        return;
      }

      final userData = querySnapshot.docs.first.data();
      final String role = userData['role'] ?? 'device';

      if (role != 'operator' && role != 'admin') {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: Only operators or admins can access this terminal.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Save both the Login State and the Theme Choice
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('driverId', querySnapshot.docs.first.id); // Example ID
      await prefs.setString('role', role);
      // Save driver name for profile chip display
      final String driverName = userData['name'] ?? userData['fullName'] ?? email.split('@').first.toUpperCase();
      await prefs.setString('driverName', driverName);

      // Log the login activity
      await LocalDatabaseHelper.instance.insertActivityLog(
        user: driverName,
        action: 'LOGIN',
      );

      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (role == 'operator') {
          if (widget.asPage) {
            // If on page mode (web landing), usually we'd refresh the state or navigate
            // In our case, TaxiMeterScreen will rebuild and see _isLoggedIn=true
            // We just need to trigger that rebuild. Since it's likely a parent,
            // we might want a callback, but for now we'll rely on pop(true) or navigation.
            // If we are showing it AS A BODY in TaxiMeterScreen, we need a way to tell it.
            // But if it's a separate page, we push /meter.
            Navigator.pushReplacementNamed(context, '/meter');
          } else {
            Navigator.pop(context, true); 
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging in: $e')),
        );
      }
    }
  }
}


