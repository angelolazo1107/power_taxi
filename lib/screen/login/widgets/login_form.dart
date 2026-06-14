import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/auth_service.dart';

class LoginForm extends StatefulWidget {
  final Function(String email, String password) onLogin;
  final Function(String pin, String? selectedDevice)? onDriverLogin;
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _deviceId = 'Detecting...';
  String _enteredPin = '';

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
  void didUpdateWidget(covariant LoginForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear entered PIN if loading finishes (failed attempt)
    if (oldWidget.isLoading && !widget.isLoading) {
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (widget.isLoading) return;
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
      });
      if (_enteredPin.length == 6) {
        _handleSubmit();
      }
    }
  }

  void _onBackspacePressed() {
    if (widget.isLoading) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClearPressed() {
    if (widget.isLoading) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = '';
      });
    }
  }

  void _handleSubmit() {
    if (widget.isLoading) return;
    if (kIsWeb) {
      widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      if (_enteredPin.length == 6) {
        widget.onDriverLogin?.call(
          _enteredPin,
          null,
        );
      }
    }
  }

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
              message.toLowerCase().contains('serial') ? 'Serial Error' : 'Authentication Error',
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualSerialDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Change Device ID',
            style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Serial Number as registered in the Admin Dashboard.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  labelStyle: const TextStyle(color: Color(0xFFD97706)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
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
                style: TextStyle(color: Color(0xFF6B7280)),
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
                          _showErrorDialog(e.toString());
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String text, VoidCallback onPressed, {Widget? icon}) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.orange.withOpacity(0.3),
          highlightColor: Colors.orange.withOpacity(0.1),
          child: Container(
            height: 70, // Increased button height from 50 to 70
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
                width: 1.5,
              ),
              color: Colors.orange.withOpacity(0.06), // Subtle light tint for readability
            ),
            alignment: Alignment.center,
            child: icon ?? Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F2937), // Dark text color for light theme contrast
                fontSize: 28, // Enlarged font size from 24 to 28
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
              style: const TextStyle(color: Color(0xFF1F2937)),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Color(0xFF4B5563)),
                prefixIcon: const Icon(Icons.email, color: Color(0xFFD97706)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Color(0xFF1F2937)),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Color(0xFF4B5563)),
                prefixIcon: const Icon(Icons.lock, color: Color(0xFFD97706)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ADMIN LOGIN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                ),
            ),
            const SizedBox(height: 20),
            // DEBUG BUTTON: Show available admins (WEB ONLY)
            TextButton.icon(
              onPressed: _showDebugAdmins,
              icon: const Icon(Icons.bug_report, color: Colors.grey),
              label: const Text(
                'DEBUG: Show Available Admins',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ] else ...[
            const Text(
              'ENTER SECURE PIN',
              style: TextStyle(
                color: Color(0xFF374151), // High contrast text color
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: isFilled ? 18 : 14,
                  height: isFilled ? 18 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFFD97706) : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: const Color(0xFFD97706).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            if (widget.isLoading)
              Container(
                height: 320, // Match enlarged numpad height
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: CircularProgressIndicator(
                        color: Color(0xFFD97706),
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Authorizing Driver...',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: 420, // Widened from 340 to 420
                child: Table(
                  children: [
                    TableRow(
                      children: [
                        _buildNumpadButton('1', () => _onDigitPressed('1')),
                        _buildNumpadButton('2', () => _onDigitPressed('2')),
                        _buildNumpadButton('3', () => _onDigitPressed('3')),
                      ],
                    ),
                    TableRow(
                      children: [
                        _buildNumpadButton('4', () => _onDigitPressed('4')),
                        _buildNumpadButton('5', () => _onDigitPressed('5')),
                        _buildNumpadButton('6', () => _onDigitPressed('6')),
                      ],
                    ),
                    TableRow(
                      children: [
                        _buildNumpadButton('7', () => _onDigitPressed('7')),
                        _buildNumpadButton('8', () => _onDigitPressed('8')),
                        _buildNumpadButton('9', () => _onDigitPressed('9')),
                      ],
                    ),
                    TableRow(
                      children: [
                        _buildNumpadButton(
                          'C',
                          _onClearPressed,
                          icon: const Icon(Icons.clear_all, color: Color(0xFF4B5563), size: 28),
                        ),
                        _buildNumpadButton('0', () => _onDigitPressed('0')),
                        _buildNumpadButton(
                          '⌫',
                          _onBackspacePressed,
                          icon: const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563), size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Device ID: $_deviceId',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showManualSerialDialog(context),
                    child: const Text(
                      'CHANGE',
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // DEBUG BUTTON: Show available drivers
            TextButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report, color: Colors.grey),
              label: const Text(
                'DEBUG: Show Available Drivers',
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Available Drivers (Debug)',
            style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
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
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${driver['name']}',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PIN Hash: ${driver['has_pin'] ? driver['pin'] : 'MISSING'}',
                        style: TextStyle(
                          color: driver['has_pin'] ? const Color(0xFF2E7D32) : Colors.red,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Email: ${driver['email']}',
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
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
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog(e.toString());
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Available Admins/Operators (Debug)',
            style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
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
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email: ${admin['email']}',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${admin['role']}',
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Password: ${admin['password']}',
                        style: TextStyle(
                          color: admin['has_password']
                              ? const Color(0xFF2E7D32)
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
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }
}
