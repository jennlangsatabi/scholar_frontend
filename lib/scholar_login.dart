import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'services/backend_api.dart';
import 'services/api_config.dart';
import 'services/google_oauth_launcher.dart';

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
  bool _isGoogleLoading = false;
  bool _showPassword = false;

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
    if (_isLoading) return;
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await BackendApi.warmUp();
      final backendScholarshipCategory =
          _toBackendScholarshipCategory(localScholarType);
      final data = await BackendApi.postForm(
        'auth_login.php',
        body: {
          'email': _userController.text,
          'password': _passController.text,
          'scholarship_category': backendScholarshipCategory,
          'scholarship_type': localScholarType,
        },
        timeout: const Duration(seconds: 45),
        retries: 3,
      );
      if (data['status'] == 'success') {
        if (!mounted) return;
        final String dbRole = data['role'].toString().toLowerCase();
        final String displayName =
            (data['username'] ?? data['name'] ?? data['email'] ?? 'Scholar')
                .toString();
        final String resolvedUserId = BackendApi.extractFirstString(
          data,
          const ['id', 'user_id', 'scholar_id', 'account_id', 'member_id'],
        );

        if (resolvedUserId.isEmpty) {
          _showError("Login succeeded but no user ID was returned by PHP.");
          return;
        }

        if (dbRole != 'scholar') {
          _showError("Unauthorized: this portal is for scholars only.");
          return;
        }

        final backendCategory =
            (data['scholarship_category'] ?? data['scholarship_type'] ?? '')
                .toString()
                .trim();
        final resolvedBackendCategory = backendCategory.isNotEmpty
            ? _toBackendScholarshipCategory(backendCategory)
            : backendScholarshipCategory;
        if (backendCategory.isNotEmpty &&
            !_matchesSelectedRole(backendCategory, localScholarType)) {
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
          'type': _toDisplayScholarshipType(resolvedBackendCategory),
          'scholarship_category': resolvedBackendCategory,
          'role': dbRole,
          'email': data['email']?.toString() ?? '',
        });
      } else {
        _showError(data['message'] ?? "Login Failed");
      }
    } catch (e) {
      if (e is TimeoutException ||
          e is ClientException ||
          e is FormatException) {
        try {
          await Future.delayed(const Duration(seconds: 2));
          await BackendApi.warmUp();
          final backendScholarshipCategory =
              _toBackendScholarshipCategory(localScholarType);
          final data = await BackendApi.postForm(
            'auth_login.php',
            body: {
              'email': _userController.text,
              'password': _passController.text,
              'scholarship_category': backendScholarshipCategory,
              'scholarship_type': localScholarType,
            },
            timeout: const Duration(seconds: 45),
            retries: 2,
          );
          if (data['status'] == 'success') {
            final String dbRole = data['role'].toString().toLowerCase();
            final String displayName =
                (data['username'] ?? data['name'] ?? data['email'] ?? 'Scholar')
                    .toString();
            final String resolvedUserId = BackendApi.extractFirstString(
              data,
              const [
                'id',
                'user_id',
                'scholar_id',
                'account_id',
                'member_id',
              ],
            );

            if (resolvedUserId.isNotEmpty && dbRole == 'scholar') {
              final backendCategory = (data['scholarship_category'] ??
                      data['scholarship_type'] ??
                      '')
                  .toString()
                  .trim();
              final resolvedBackendCategory = backendCategory.isNotEmpty
                  ? _toBackendScholarshipCategory(backendCategory)
                  : backendScholarshipCategory;
              if (backendCategory.isEmpty ||
                  _matchesSelectedRole(backendCategory, localScholarType)) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Welcome Scholar, $displayName!")),
                );
                widget.onLoginSuccess({
                  'id': resolvedUserId,
                  'name': displayName,
                  'type': _toDisplayScholarshipType(resolvedBackendCategory),
                  'scholarship_category': resolvedBackendCategory,
                  'role': dbRole,
                  'email': data['email']?.toString() ?? '',
                });
                return;
              }
            }
          }
        } catch (_) {
          // Fall through to default error path.
        }
      }
      _showError(_buildConnectionErrorMessage(e));
      debugPrint("Scholar login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading || _isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);
    try {
      final launched = await GoogleOAuthLauncher.launch(portalRole: 'scholar');
      if (!launched) {
        _showError(
          'Google login is not configured yet. Set GOOGLE_OAUTH_URL to your OAuth start endpoint.',
        );
      }
    } catch (e) {
      _showError('Unable to start Google login.');
      debugPrint("Scholar Google login error: $e");
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _buildConnectionErrorMessage(Object error) {
    if (error is ClientException) {
      return 'Connection Error: Chrome blocked the request to ${ApiConfig.baseUrl}. '
          'For `flutter run -d chrome`, enable CORS on the PHP server or serve the built web app from Apache/XAMPP.';
    }
    return "Connection Error: can't reach ${ApiConfig.baseUrl}.";
  }

  bool _matchesSelectedRole(String backendCategory, String selected) {
    final b = _toBackendScholarshipCategory(backendCategory);
    final s = _toBackendScholarshipCategory(selected);
    if (b.isEmpty) return false;
    return b == s;
  }

  String _toBackendScholarshipCategory(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'student_assistant' ||
        (normalized.contains('student') && normalized.contains('assistant'))) {
      return 'student_assistant';
    }
    if (normalized == 'varsity') return 'varsity';
    if (normalized == 'academic') return 'academic';
    if (normalized == 'gift_of_education' || normalized.contains('gift')) {
      return 'gift_of_education';
    }
    return '';
  }

  String _toDisplayScholarshipType(String raw) {
    switch (_toBackendScholarshipCategory(raw)) {
      case 'student_assistant':
        return 'Student Assistant Scholar';
      case 'varsity':
        return 'Varsity Scholar';
      case 'academic':
        return 'Academic Scholar';
      case 'gift_of_education':
        return 'Gift of Education Scholar';
      default:
        return localScholarType;
    }
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
            color: Colors.white.withValues(alpha: 0.1),
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

        const SizedBox(height: 14),
        if (_isGoogleLoading)
          const CircularProgressIndicator(color: Colors.white)
        else
          _googleLoginBtn('Continue with Google', _handleGoogleLogin),

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
    final isPasswordField = isObscure;
    return TextField(
      controller: controller,
      obscureText: isPasswordField ? !_showPassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPasswordField
            ? IconButton(
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
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

  Widget _googleLoginBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202124),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4285F4), width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

