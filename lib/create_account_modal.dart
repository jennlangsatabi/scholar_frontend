import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class CreateAccountModal extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialScholarshipType;
  final String initialRole;

  const CreateAccountModal({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialScholarshipType,
    this.initialRole = 'scholar',
  });

  @override
  State<CreateAccountModal> createState() => _CreateAccountModalState();
}

class _CreateAccountModalState extends State<CreateAccountModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _scholarshipTypes = const [
    'Student Assistant Scholar',
    'Varsity Scholar',
    'Academic Scholar',
    'Gift of Education Scholar',
  ];

  late String _selectedScholarshipType;
  late final String _role;

  bool get _isScholar => _role == 'scholar';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole.trim().toLowerCase() == 'admin'
        ? 'admin'
        : 'scholar';
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedScholarshipType =
        _scholarshipTypes.contains(widget.initialScholarshipType)
            ? widget.initialScholarshipType
            : _scholarshipTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final nameParts = _splitName(_nameController.text.trim());
      final backendScholarshipCategory = _toBackendScholarshipCategory(
        _selectedScholarshipType,
      );

      final Map<String, String> body;
      if (_isScholar) {
        body = {
          'user_id': '0',
          'username': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'first_name': nameParts.firstName,
          'middle_name': nameParts.middleName,
          'last_name': nameParts.lastName,
          'course': 'Not specified',
          'year_level': '1',
          'scholarship_category': backendScholarshipCategory,
          'scholarship_status': 'pending',
          'scholarship_type': _selectedScholarshipType,
        };
      } else {
        body = {
          'username': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': _role,
        };
      }

      final String endpoint =
          _isScholar ? 'add_scholar.php' : 'request_account.php';

      final response = await BackendApi.postForm(
        endpoint,
        body: body,
        timeout: const Duration(seconds: 45),
        retries: 2,
      );

      if (_isScholar) {
        final loginResult = await BackendApi.postForm(
          'auth_login.php',
          body: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'scholarship_category': backendScholarshipCategory,
            'scholarship_type': _selectedScholarshipType,
          },
          timeout: const Duration(seconds: 45),
          retries: 2,
        );

        final createdId = (loginResult['user_id'] ??
                loginResult['id'] ??
                loginResult['scholar_id'] ??
                '')
            .toString()
            .trim();
        if (createdId.isEmpty) {
          throw const FormatException(
            'The backend created the scholar but did not return a usable user id.',
          );
        }

        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_admin_stats.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');

        if (!mounted) return;
        Navigator.of(context).pop(<String, String>{
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _role,
          'user_id': createdId,
          'scholarship_category': backendScholarshipCategory,
          'scholarship_type': _selectedScholarshipType,
        });
      } else {
        final createdId = (response['request_id'] ?? response['user_id'] ?? '')
            .toString()
            .trim();
        if (createdId.isEmpty) {
          throw const FormatException(
            'The backend did not return a request id.',
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop(<String, String>{
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _role,
          'request_id': createdId,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('FormatException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  ({String firstName, String middleName, String lastName}) _splitName(
      String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return (firstName: 'Google', middleName: '', lastName: 'User');
    }

    final parts = cleaned.split(' ');
    if (parts.length == 1) {
      return (firstName: parts.first, middleName: '', lastName: 'User');
    }

    if (parts.length == 2) {
      return (firstName: parts[0], middleName: '', lastName: parts[1]);
    }

    return (
      firstName: parts.first,
      middleName: parts.sublist(1, parts.length - 1).join(' '),
      lastName: parts.last,
    );
  }

  String _toBackendScholarshipCategory(String displayType) {
    final normalized = displayType.trim().toLowerCase();
    if (normalized.contains('student') && normalized.contains('assistant')) {
      return 'student_assistant';
    }
    if (normalized.contains('varsity')) {
      return 'varsity';
    }
    if (normalized.contains('academic')) {
      return 'academic';
    }
    if (normalized.contains('gift')) {
      return 'gift_of_education';
    }
    return 'student_assistant';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isScholar
                        ? 'Create Scholar Account'
                        : 'Create Admin Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D0D44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isScholar
                        ? 'Create a scholar account using the Google details we received.'
                        : 'Submit an admin account request using the Google details we received.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _field(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_isScholar) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedScholarshipType,
                      decoration: _inputDecoration('Scholarship Type'),
                      items: _scholarshipTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedScholarshipType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Use at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_reset_outlined,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Scholar Access',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label).copyWith(
        prefixIcon: Icon(icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 1.6),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
