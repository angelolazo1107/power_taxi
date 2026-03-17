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

  Future<void> _handleLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDriverLogin(String name, String pin) async {
    if (name.isEmpty || pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter driver name and 4-digit PIN.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? deviceSerialNo = prefs.getString('userRole') == 'device' ? prefs.getString('driverName') : null;
      
      await _authService.driverLogin(name, pin, deviceSerialNo: deviceSerialNo);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/meter', arguments: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_taxi, size: 100, color: Colors.orange),
                const SizedBox(height: 20),
                const Text('POWERTAXI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 2)),
                const Text('System Authentication', style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1)),
                const SizedBox(height: 50),
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
