import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/auth_service.dart';

class LoginForm extends StatefulWidget {
  final Function(String email, String password) onLogin;
  final Function(String name, String pin, String? selectedDevice)?
  onDriverLogin;
  final bool isLoading;

  const LoginForm({
    super.key,
    required this.onLogin,
    this.onDriverLogin,
    required this.isLoading,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _deviceId = 'Detecting...';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadDeviceId();
    }
  }

  Future<void> _loadDeviceId() async {
    final authService = AuthService();
    final deviceId = await authService.getDeviceId();
    setState(() {
      _deviceId = deviceId;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (widget.isLoading) return;
    if (kIsWeb) {
      widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      widget.onDriverLogin?.call(
        _nameController.text.trim(),
        _pinController.text.trim(),
        null,
      );
    }
  }

  Future<void> _showManualSerialDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF111418),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Change Device ID',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Serial Number as registered in the Admin Dashboard.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  labelStyle: const TextStyle(color: Colors.orange),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      try {
                        final authService = AuthService();
                        await authService.validateAndSetSerialNumber(
                          controller.text,
                        );
                        await _loadDeviceId(); // Refresh the displayed ID
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SAVE', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (kIsWeb) ...[
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.email, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: 'Driver Name',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.person_pin, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Enter PIN Code',
                labelStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
                prefixIcon: const Icon(Icons.lock_open, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white10,
                counterText: "",
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Device ID: $_deviceId',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showManualSerialDialog(context),
                    child: const Text(
                      'CHANGE',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      kIsWeb ? 'ADMIN LOGIN' : 'UNLOCK METER',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          // DEBUG BUTTON: Show available drivers
          if (!kIsWeb) ...[
            TextButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report, color: Colors.grey),
              label: const Text(
                'DEBUG: Show Available Drivers',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
          // DEBUG BUTTON: Show available admins (WEB ONLY)
          if (kIsWeb) ...[
            TextButton.icon(
              onPressed: _showDebugAdmins,
              icon: const Icon(Icons.bug_report, color: Colors.grey),
              label: const Text(
                'DEBUG: Show Available Admins',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDebugInfo() async {
    final authService = AuthService();
    try {
      final drivers = await authService.getAvailableDriversForDebug();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111418),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Available Drivers (Debug)',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${driver['name']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PIN Hash: ${driver['has_pin'] ? driver['pin'] : 'MISSING'}',
                        style: TextStyle(
                          color: driver['has_pin'] ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Email: ${driver['email']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showDebugAdmins() async {
    final authService = AuthService();
    try {
      final admins = await authService.getAvailableAdminsForDebug();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111418),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Available Admins/Operators (Debug)',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: admins.length,
              itemBuilder: (context, index) {
                final admin = admins[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email: ${admin['email']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Role: ${admin['role']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Password: ${admin['password']}',
                        style: TextStyle(
                          color: admin['has_password']
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
