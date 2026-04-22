import 'package:flutter/material.dart';

import 'scholarship_types.dart';
import 'services/backend_api.dart';

class CreateAccountModal extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialScholarshipType;
  final String initialRole;
  final String initialGoogleId;
  final String initialUserId;

  const CreateAccountModal({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialScholarshipType,
    this.initialRole = 'scholar',
    this.initialGoogleId = '',
    this.initialUserId = '',
  });

  @override
  State<CreateAccountModal> createState() => _CreateAccountModalState();
}

class _CreateAccountModalState extends State<CreateAccountModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _courseController;
  late final TextEditingController _yearLevelController;
  late final TextEditingController _assignedAreaController;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool _isDuplicateAccountError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('already in use') ||
        normalized.contains('already exists') ||
        normalized.contains('email is already') ||
        normalized.contains('username or email already exists') ||
        normalized.contains('duplicate');
  }

  Future<void> _showDuplicateAccountModal(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Already Exists'),
        content: Text(
          message.isNotEmpty
              ? message
              : 'This email is already registered in the system. Please sign in with that account instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  final List<String> _scholarshipTypes = const [
    'Student Assistant',
    'Varsity Scholar',
    'Academic Scholar',
    'Gift of Education',
  ];

  late String _selectedScholarshipType;
  late String _selectedAcademicType;
  late String _selectedSportType;
  late String _selectedGiftType;
  late final String _role;

  bool get _isScholar => _role == 'scholar';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole.trim().toLowerCase() == 'admin'
        ? 'admin'
        : 'scholar';

    final nameParts = _splitName(widget.initialName);
    _firstNameController = TextEditingController(text: nameParts.firstName);
    _middleNameController = TextEditingController(text: nameParts.middleName);
    _lastNameController = TextEditingController(text: nameParts.lastName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _courseController = TextEditingController();
    _yearLevelController = TextEditingController();
    _assignedAreaController = TextEditingController();

    _selectedScholarshipType = _toDisplayScholarshipType(
      widget.initialScholarshipType,
    );
    _selectedAcademicType = 'Type A';
    _selectedSportType = 'Basketball';
    _selectedGiftType = ScholarshipTypes.giftTypeOptions.keys.first;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _courseController.dispose();
    _yearLevelController.dispose();
    _assignedAreaController.dispose();
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
      final backendScholarshipCategory = _toBackendScholarshipCategory(
        _selectedScholarshipType,
      );
      final fullName = _composeFullName();

      final Map<String, String> body;
      if (_isScholar) {
        body = {
          'user_id': widget.initialUserId.trim().isNotEmpty
              ? widget.initialUserId.trim()
              : '0',
          'username': fullName,
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'school': 'JMC',
          'course': _courseController.text.trim(),
          'year_level': _yearLevelController.text.trim(),
          'scholarship_category': backendScholarshipCategory,
          'scholarship_status': 'pending',
          'status': 'pending',
          'scholarship_type': _selectedScholarshipType,
        };
        final googleId = widget.initialGoogleId.trim();
        if (googleId.isNotEmpty) {
          body['google_id'] = googleId;
        }

        final assignedArea = _assignedAreaController.text.trim();
        if (_selectedScholarshipType == 'Student Assistant' &&
            assignedArea.isNotEmpty) {
          body['assigned_area'] = assignedArea;
        }
        if (_selectedScholarshipType == 'Academic Scholar') {
          body['academic_type'] = _academicTypePayload();
        }
        if (_selectedScholarshipType == 'Varsity Scholar') {
          body['sport_type'] = _selectedSportType.trim();
        }
        if (_selectedScholarshipType == 'Gift of Education') {
          body['gift_type'] = ScholarshipTypes.giftTypePayload(
            _selectedGiftType,
          );
        }
      } else {
        body = {
          'username': fullName,
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': _role,
        };
        final googleId = widget.initialGoogleId.trim();
        if (googleId.isNotEmpty) {
          body['google_id'] = googleId;
        }
      }

      final endpoint = _isScholar ? 'add_scholar.php' : 'request_account.php';

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

        final createdId = BackendApi.extractFirstString(
          loginResult,
          const ['user_id', 'id', 'scholar_id', 'account_id', 'member_id'],
        );
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
          'name': fullName,
          'email': _emailController.text.trim(),
          'role': _role,
          'user_id': createdId,
          'scholarship_category': backendScholarshipCategory,
          'scholarship_type': _selectedScholarshipType,
          if (widget.initialGoogleId.trim().isNotEmpty)
            'google_id': widget.initialGoogleId.trim(),
          if (widget.initialUserId.trim().isNotEmpty)
            'linked_user_id': widget.initialUserId.trim(),
        });
      } else {
        final createdId = (response['request_id'] ?? response['user_id'] ?? '')
            .toString()
            .trim();
        if (createdId.isEmpty) {
          throw const FormatException('The backend did not return a request id.');
        }

        if (!mounted) return;
        Navigator.of(context).pop(<String, String>{
          'name': fullName,
          'email': _emailController.text.trim(),
          'role': _role,
          'request_id': createdId,
          if (widget.initialGoogleId.trim().isNotEmpty)
            'google_id': widget.initialGoogleId.trim(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('FormatException: ', '');
      setState(() {
        _errorMessage = message;
      });
      if (_isDuplicateAccountError(message)) {
        await _showDuplicateAccountModal(message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _composeFullName() {
    return [
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  ({String firstName, String middleName, String lastName}) _splitName(
    String raw,
  ) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return (firstName: '', middleName: '', lastName: '');
    }

    final parts = cleaned.split(' ');
    if (parts.length == 1) {
      return (firstName: parts.first, middleName: '', lastName: '');
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

  String _toDisplayScholarshipType(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'student_assistant' ||
        (normalized.contains('student') && normalized.contains('assistant'))) {
      return 'Student Assistant';
    }
    if (normalized == 'varsity') {
      return 'Varsity Scholar';
    }
    if (normalized == 'academic') {
      return 'Academic Scholar';
    }
    if (normalized == 'gift_of_education' || normalized.contains('gift')) {
      return 'Gift of Education';
    }
    return _scholarshipTypes.first;
  }

  String _academicTypePayload() {
    return _selectedAcademicType.replaceAll('Type ', '').trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 560;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_isScholar) ...[
                    _buildNameFields(isCompact),
                    const SizedBox(height: 10),
                  ],
                  _buildField(
                    controller: _isScholar
                        ? _emailController
                        : _emailController,
                    label: 'Email*',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPasswordFields(isCompact),
                  if (_isScholar) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedScholarshipType,
                      decoration: _inputDecoration('Category'),
                      items: _scholarshipTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedScholarshipType = value;
                          if (value != 'Student Assistant') {
                            _assignedAreaController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_selectedScholarshipType == 'Academic Scholar') ...[
                      DropdownButtonFormField<String>(
                        value: _selectedAcademicType,
                        decoration: _inputDecoration('Academic Type'),
                        items: const ['Type A', 'Type B', 'Type C']
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedAcademicType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_selectedScholarshipType == 'Varsity Scholar') ...[
                      DropdownButtonFormField<String>(
                        value: _selectedSportType,
                        decoration: _inputDecoration('Sport Type'),
                        items: const ['Basketball', 'Volleyball']
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedSportType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_selectedScholarshipType == 'Gift of Education') ...[
                      DropdownButtonFormField<String>(
                        value: _selectedGiftType,
                        decoration: _inputDecoration('Gift Type'),
                        items: ScholarshipTypes.giftTypeOptions.keys
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedGiftType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildCourseYearFields(isCompact),
                    if (_selectedScholarshipType == 'Student Assistant') ...[
                      const SizedBox(height: 10),
                      _buildField(
                        controller: _assignedAreaController,
                        label: 'Assigned Area',
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2A6A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildNameFields(bool isCompact) {
    if (isCompact) {
      return Column(
        children: [
          _buildField(
            controller: _firstNameController,
            label: 'First Name*',
            validator: _requiredText('First name is required'),
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _middleNameController,
            label: 'Middle Name',
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _lastNameController,
            label: 'Last Name*',
            validator: _requiredText('Last name is required'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: _firstNameController,
                label: 'First Name*',
                validator: _requiredText('First name is required'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                controller: _middleNameController,
                label: 'Middle Name',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildField(
          controller: _lastNameController,
          label: 'Last Name*',
          validator: _requiredText('Last name is required'),
        ),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    final title = _isScholar ? 'Scholar Create Account' : 'Create Account';
    final subtitle = _isScholar
        ? 'Fill in the scholar details below to register a new account.'
        : 'Provide the account details below to continue.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A2A6A), Color(0xFF7A49A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A4A2A6A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'SCHOLAR PORTAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields(bool isCompact) {
    final passwordField = _buildField(
      controller: _passwordController,
      label: 'Password*',
      obscureText: true,
      validator: (value) {
        final text = value ?? '';
        if (text.isEmpty) return 'Password is required';
        if (text.length < 8) return 'Use at least 8 characters';
        return null;
      },
    );
    final confirmField = _buildField(
      controller: _confirmPasswordController,
      label: 'Confirm Password*',
      obscureText: true,
      validator: (value) {
        final text = value ?? '';
        if (text.isEmpty) return 'Please confirm your password';
        if (text != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );

    if (isCompact) {
      return Column(
        children: [
          passwordField,
          const SizedBox(height: 10),
          confirmField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: passwordField),
        const SizedBox(width: 10),
        Expanded(child: confirmField),
      ],
    );
  }

  Widget _buildCourseYearFields(bool isCompact) {
    final courseField = _buildField(
      controller: _courseController,
      label: 'Course*',
      validator: _requiredText('Course is required'),
    );
    final yearField = _buildField(
      controller: _yearLevelController,
      label: 'Year Level*',
      validator: _requiredText('Year level is required'),
    );

    if (isCompact) {
      return Column(
        children: [
          courseField,
          const SizedBox(height: 10),
          yearField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: courseField),
        const SizedBox(width: 10),
        Expanded(child: yearField),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label),
    );
  }

  String? Function(String?) _requiredText(String message) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE7DDF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6A3D8F)),
      ),
    );
  }
}
