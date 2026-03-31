import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'services/backend_api.dart';
import 'services/api_config.dart';

class AdminLoginScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onLoginSuccess;
  final VoidCallback onBack;

  const AdminLoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onBack,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // --- STATE VARIABLES ---
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- LOGIN LOGIC ---
  Future<void> _handleLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await BackendApi.postForm(
        'auth_login.php',
        body: {
          'email': _userController.text,
          'password': _passController.text,
        },
      );
      if (data['status'] == 'success') {
        String dbRole = data['role'].toString().toLowerCase();
        final String resolvedUserId =
            (data['id'] ?? data['user_id'] ?? data['admin_id'] ?? '')
                .toString();

        if (dbRole == 'admin') {
          if (resolvedUserId.isEmpty) {
            _showError("Login succeeded but no admin ID was returned by PHP.");
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome, ${data['username']}!")),
          );
          widget.onLoginSuccess({
            'id': resolvedUserId,
            'name': data['username']?.toString() ?? 'Administrator',
            'type': 'Admin',
            'role': dbRole,
          });
        } else {
          _showError("Unauthorized: You do not have Admin privileges.");
        }
      } else {
        _showError(data['message'] ?? "Invalid Email or Password");
      }
    } catch (e) {
      _showError(_buildConnectionErrorMessage(e));
      debugPrint("Admin login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _buildConnectionErrorMessage(Object error) {
    if (error is ClientException) {
      return 'Connection Error: Chrome blocked the request to ${ApiConfig.baseUrl}. '
          'For `flutter run -d chrome`, enable CORS on the PHP server or serve the built web app from Apache/XAMPP.';
    }
    return "Connection Error: can't reach ${ApiConfig.baseUrl}.";
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. BRANDING HEADER
        const Text(
          'Admin Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),

        // 2. INPUT FIELDS (Passing controllers!)
        _inputField('Email Address', Icons.email_outlined, _userController),
        const SizedBox(height: 15),
        _inputField('Password', Icons.lock_outline, _passController,
            isObscure: true),

        const SizedBox(height: 30),

        // 3. LOGIN BUTTON / LOADING SPINNER
        if (_isLoading)
          const CircularProgressIndicator(color: Colors.white)
        else
          _loginBtn('LOGIN', _handleLogin),

        // 4. BACK BUTTON
        const SizedBox(height: 10),
        TextButton(
          onPressed: widget.onBack,
          child: const Text(
            'Go Back',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // Updated to accept TextEditingController
  Widget _inputField(
      String hint, IconData icon, TextEditingController controller,
      {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _loginBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
