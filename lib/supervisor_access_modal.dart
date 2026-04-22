import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class SupervisorAccessModal extends StatefulWidget {
  const SupervisorAccessModal({super.key});

  @override
  State<SupervisorAccessModal> createState() => _SupervisorAccessModalState();
}

class _SupervisorAccessModalState extends State<SupervisorAccessModal> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _requestEmailController = TextEditingController();
  final _requestPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _requestMode = false;
  bool _showPassword = false;
  bool _showRequestPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _requestEmailController.dispose();
    _requestPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your supervisor email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payload = await BackendApi.postForm(
        'supervisor_login.php',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
        timeout: const Duration(seconds: 30),
        retries: 1,
      );

      final role = (payload['role'] ?? '').toString().trim().toLowerCase();
      final token = (payload['token'] ?? '').toString().trim();
      final userId = (payload['user_id'] ?? '').toString().trim();
      final username =
          (payload['username'] ?? payload['name'] ?? 'Supervisor')
              .toString()
              .trim();

      if (role != 'supervisor' || token.isEmpty || userId.isEmpty) {
        throw Exception(
          payload['message']?.toString() ?? 'Supervisor access was not granted.',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(<String, String>{
        'token': token,
        'user_id': userId,
        'username': username,
        'email': (payload['email'] ?? '').toString(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestAccess() async {
    if (_isLoading) return;

    final fullName = _nameController.text.trim();
    final email = _requestEmailController.text.trim();
    final password = _requestPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Complete the supervisor request form first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payload = await BackendApi.postForm(
        'request_account.php',
        body: {
          'role': 'supervisor',
          'username': fullName,
          'email': email,
          'password': password,
          'scholarship_type': 'Supervisor',
        },
        timeout: const Duration(seconds: 30),
        retries: 1,
      );

      if (!mounted) return;
      setState(() {
        _requestMode = false;
        _emailController.text = email;
        _passwordController.clear();
      });
      final message = payload['message']?.toString() ??
          'Supervisor access request submitted. Wait for admin approval.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF4A148C).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _requestMode
                        ? 'Request Supervisor Access'
                        : 'Supervisor Login Required',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _requestMode
                  ? 'Submit a supervisor access request. An admin must approve it before you can evaluate scholars.'
                  : 'Only approved supervisors can open the Scholar Evaluation Form.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (_requestMode) ...[
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _requestEmailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Supervisor Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _requestPasswordController,
                obscureText: !_showRequestPassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Create Password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _showRequestPassword = !_showRequestPassword);
                    },
                    icon: Icon(
                      _showRequestPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Supervisor Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFFCDD2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _requestMode = !_requestMode;
                              _error = null;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _requestMode ? 'Back To Login' : 'Request Access',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_requestMode ? _requestAccess : _login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A148C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_requestMode ? 'Submit Request' : 'Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
