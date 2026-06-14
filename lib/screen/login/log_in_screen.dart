import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'widgets/login_form.dart';

class LoginScreen extends StatefulWidget {
  final bool asPage;
  const LoginScreen({super.key, this.asPage = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              message.toLowerCase().contains('pin') ? 'Invalid PIN' : 'Authentication Error',
              style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _authService.login(email, password);
      final String role = userData?['role'] ?? 'device';

      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/meter');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _handleDriverLogin(String pin, String? selectedDeviceSerial) async {
    if (pin.length < 6) {
      _showErrorDialog('Please enter a 6-digit PIN.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? deviceSerialNo = selectedDeviceSerial ?? prefs.getString('deviceSerialNo');
      
      await _authService.driverLogin(pin, deviceSerialNo: deviceSerialNo);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/meter', arguments: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Premium daylight-readable off-white
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_taxi, size: 60, color: Color(0xFFD97706)),
                const SizedBox(height: 12),
                const Text(
                  'POWERTAXI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'System Authentication',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563), // High contrast slate gray
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                LoginForm(
                  onLogin: _handleLogin,
                  onDriverLogin: _handleDriverLogin,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
