import 'package:flutter/material.dart';

import 'services/backend_api.dart';
import 'services/api_config.dart';

class ScholarLoginScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onLoginSuccess;
  final VoidCallback onBack;

  const ScholarLoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onBack,
  });

  @override
  State<ScholarLoginScreen> createState() => _ScholarLoginScreenState();
}

class _ScholarLoginScreenState extends State<ScholarLoginScreen> {
  // --- STATE VARIABLES ---
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  String localScholarType = 'Student Assistant Scholar';
  final List<String> scholarTypes = [
    'Student Assistant Scholar',
    'Varsity Scholar',
    'Academic Scholar',
    'Gift of Education Scholar',
  ];

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

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
          'scholarship_category': localScholarType,
          'scholarship_type': localScholarType,
        },
      );
        if (data['status'] == 'success') {
          final String dbRole = data['role'].toString().toLowerCase();
          final String displayName =
              (data['username'] ?? data['name'] ?? data['email'] ?? 'Scholar')
                  .toString();
          final String resolvedUserId =
              (data['id'] ?? data['user_id'] ?? data['scholar_id'] ?? '')
                  .toString();

          if (resolvedUserId.isEmpty) {
            _showError("Login succeeded but no user ID was returned by PHP.");
            return;
          }

          if (dbRole != 'scholar') {
            _showError("Unauthorized: this portal is for scholars only.");
            return;
          }

          final backendCategory = (data['scholarship_category'] ??
                  data['scholarship_type'] ??
                  '')
              .toString()
              .trim();
          if (backendCategory.isEmpty) {
            _showError(
                "Your account has no scholar category assigned. Please contact admin.");
            return;
          }
          if (!_matchesSelectedRole(backendCategory, localScholarType)) {
            _showError(
                "This account is registered as $backendCategory. Select that role to continue.");
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome Scholar, $displayName!")),
          );
          widget.onLoginSuccess({
            'id': resolvedUserId,
            'name': displayName,
            'type': backendCategory,
            'role': dbRole,
            'email': data['email']?.toString() ?? '',
          });
        } else {
          _showError(data['message'] ?? "Login Failed");
        }
    } catch (e) {
      _showError("Connection Error: can't reach ${ApiConfig.baseUrl}.");
      debugPrint("Scholar login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _matchesSelectedRole(String backendCategory, String selected) {
    String canon(String raw) {
      final t = raw.toLowerCase();
      if (t.contains('student') && t.contains('assistant')) return 'student_assistant';
      if (t.contains('varsity')) return 'varsity';
      if (t.contains('academic')) return 'academic';
      if (t.contains('gift')) return 'gift';
      return '';
    }

    final b = canon(backendCategory);
    final s = canon(selected);
    if (b.isEmpty) return false;
    return b == s;
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
          'Scholar Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),

        // 2. SCHOLAR TYPE DROPDOWN
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: localScholarType,
              dropdownColor: const Color(0xFF3B125A),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: scholarTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => localScholarType = val!),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // 3. INPUT FIELDS (Now passing controllers!)
        _inputField('Email Address', Icons.email_outlined, _userController),
        const SizedBox(height: 15),
        _inputField('Password', Icons.lock_outline, _passController,
            isObscure: true),

        const SizedBox(height: 30),

        // 4. LOGIN BUTTON / LOADING SPINNER
        if (_isLoading)
          const CircularProgressIndicator(color: Colors.white)
        else
          _loginBtn('LOGIN', _handleLogin),

        // 5. BACK BUTTON
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
