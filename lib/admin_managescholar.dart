import 'package:flutter/material.dart';
import 'dart:async';

import 'create_account_modal.dart';
import 'services/backend_api.dart';
import 'scholarship_types.dart';

class ManageScholarScreen extends StatefulWidget {
  const ManageScholarScreen({super.key});

  @override
  State<ManageScholarScreen> createState() => _ManageScholarScreenState();
}

class _ManageScholarScreenState extends State<ManageScholarScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _yearLevelController = TextEditingController();
  final TextEditingController _assignedAreaController = TextEditingController();

  String _selectedAcademicType = 'Type A';
  String _selectedSportType = 'Basketball';
  String _selectedGiftType = ScholarshipTypes.giftTypeOptions.keys.first;

  final List<String> _categories = const [
    'All',
    'Student Assistant',
    'Academic Scholar',
    'Varsity Scholar',
    'Gift of Education',
  ];

  List<Map<String, dynamic>> _scholars = [];
  List<Map<String, dynamic>> _filteredScholars = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _showArchived = false;
  String _selectedFilterCategory = 'All';
  String _selectedFormCategory = 'Student Assistant';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    fetchScholars();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => fetchScholars(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
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

  Future<void> fetchScholars() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      BackendApi.invalidateCache(pathContains: 'get_scholars.php');
      _scholars = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_scholars.php',
          query: {'archived': _showArchived ? '1' : '0'},
          cacheTtl: const Duration(seconds: 1),
          retries: 1,
        ),
      );
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load scholars: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    final category = _normalizeCategory(_selectedFilterCategory);

    final filtered = _scholars.where((s) {
      final first = (s['first_name'] ?? '').toString().toLowerCase();
      final middle = (s['middle_name'] ?? '').toString().toLowerCase();
      final last = (s['last_name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final course = (s['course'] ?? '').toString().toLowerCase();
      final scholarCategory = (s['scholarship_category'] ?? '').toString();
      final normalizedCategory = _normalizeCategory(scholarCategory);
      final assigned = (s['assigned_area'] ?? '').toString().toLowerCase();

      final inCategory = category == 'all' || normalizedCategory == category;
      final inQuery = q.isEmpty ||
          first.contains(q) ||
          middle.contains(q) ||
          last.contains(q) ||
          email.contains(q) ||
          course.contains(q) ||
          normalizedCategory.contains(q) ||
          assigned.contains(q);

      return inCategory && inQuery;
    }).toList();

    setState(() => _filteredScholars = filtered);
  }

  Future<void> addScholar() async {
    if (_isProcessing) return;

    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _courseController.text.trim().isEmpty ||
        _yearLevelController.text.trim().isEmpty) {
      _toast('Please complete required fields.', Colors.orange);
      return;
    }

    final email = _emailController.text.trim();
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) {
      _toast('Please enter a valid email address.', Colors.orange);
      return;
    }

    if (_passwordController.text.length < 6) {
      _toast('Password must be at least 6 characters.', Colors.orange);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _toast('Passwords do not match.', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final payload = <String, dynamic>{
        "first_name": _firstNameController.text.trim(),
        "middle_name": _middleNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "email": email,
        "password": _passwordController.text,
        "username":
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}"
                .trim(),
        "school": "JMC",
        "course": _courseController.text.trim(),
        "year_level": _yearLevelController.text.trim(),
        "scholarship_category": _toServerCategory(_selectedFormCategory),
        "scholarship_status": _initialScholarshipStatusPayload(),
        "status": _initialScholarshipStatusPayload(),
      };

      final assignedArea = _assignedAreaController.text.trim();
      final academicType = _academicTypePayload();
      final sportType = _sportTypePayload();
      final giftType = _giftTypePayload();

      if (_selectedFormCategory == 'Student Assistant' &&
          assignedArea.isNotEmpty) {
        payload["assigned_area"] = assignedArea;
      }
      if (_selectedFormCategory == 'Academic Scholar' &&
          academicType.isNotEmpty) {
        payload["academic_type"] = academicType;
      }
      if (_selectedFormCategory == 'Varsity Scholar' && sportType.isNotEmpty) {
        payload["sport_type"] = sportType;
      }
      if (_selectedFormCategory == 'Gift of Education' &&
          giftType.isNotEmpty) {
        payload["gift_type"] = giftType;
      }

      final data = await _createScholarWithStatusFallback(payload);

      if (data['status'] == 'success') {
        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
        setState(() => _selectedFilterCategory = _selectedFormCategory);
        _toast('Scholar added successfully.', Colors.green);
        await fetchScholars();
      } else {
        _toast(data['message']?.toString() ?? 'Failed to add scholar.',
            Colors.red);
      }
    } catch (e) {
      _toast('Error adding scholar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _editScholar(String scholarId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final payload = <String, dynamic>{
        "scholar_id": scholarId,
        "course": _courseController.text.trim(),
        "year_level": _yearLevelController.text.trim(),
      };

      final assignedArea = _assignedAreaController.text.trim();
      final academicType = _academicTypePayload();
      final sportType = _sportTypePayload();
      final giftType = _giftTypePayload();

      if (_selectedFormCategory == 'Student Assistant' &&
          assignedArea.isNotEmpty) {
        payload["assigned_area"] = assignedArea;
      }
      if (_selectedFormCategory == 'Academic Scholar' &&
          academicType.isNotEmpty) {
        payload["academic_type"] = academicType;
      }
      if (_selectedFormCategory == 'Varsity Scholar' && sportType.isNotEmpty) {
        payload["sport_type"] = sportType;
      }
      if (_selectedFormCategory == 'Gift of Education' &&
          giftType.isNotEmpty) {
        payload["gift_type"] = giftType;
      }

      final data = await BackendApi.postForm(
        'edit_scholar.php',
        body: _stringifyPayload(payload),
      );

      if (data['status'] == 'success') {
        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
        _toast('Scholar updated.', Colors.blue);
        await fetchScholars();
      } else {
        _toast(data['message']?.toString() ?? 'Update failed.', Colors.red);
      }
    } catch (e) {
      _toast('Error editing scholar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteScholar(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final data = await BackendApi.postForm(
        'delete_scholar.php',
        body: {"user_id": userId},
      );

      if (data['status'] == 'success') {
        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
        BackendApi.invalidateCache(pathContains: 'get_pending_verifications.php');
        _toast('Scholar deleted.', Colors.red);
        await fetchScholars();
      } else {
        _toast(data['message']?.toString() ?? 'Delete failed.', Colors.red);
      }
    } catch (e) {
      _toast('Error deleting scholar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _archiveScholar(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final data = await BackendApi.postForm(
        'archive_scholar.php',
        body: {"user_id": userId},
      );

      if (data['status'] == 'success') {
        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
        _toast('Scholar archived.', const Color(0xFF8E4B10));
        await fetchScholars();
      } else {
        _toast(data['message']?.toString() ?? 'Archive failed.',
            Colors.redAccent);
      }
    } catch (e) {
      _toast('Error archiving scholar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreScholar(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final data = await BackendApi.postForm(
        'restore_scholar.php',
        body: {"user_id": userId},
      );

      if (data['status'] == 'success') {
        BackendApi.invalidateCache(pathContains: 'get_scholars.php');
        BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
        BackendApi.invalidateCache(pathContains: 'get_pending_verifications.php');
        _toast('Scholar restored.', Colors.green);
        await fetchScholars();
      } else {
        _toast(data['message']?.toString() ?? 'Restore failed.', Colors.red);
      }
    } catch (e) {
      _toast('Error restoring scholar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _fullName(Map<String, dynamic> s) {
    final first = (s['first_name'] ?? '').toString().trim();
    final middle = (s['middle_name'] ?? '').toString().trim();
    final last = (s['last_name'] ?? '').toString().trim();
    final middlePart = middle.isEmpty ? '' : ' ${middle[0]}.';
    return '$first$middlePart $last'.trim();
  }

  void _clearForm() {
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _courseController.clear();
    _yearLevelController.clear();
    _assignedAreaController.clear();
    _selectedAcademicType = 'Type A';
    _selectedSportType = 'Basketball';
    _selectedGiftType = ScholarshipTypes.giftTypeOptions.keys.first;
    _selectedFormCategory = _selectedFilterCategory == 'All'
        ? 'Student Assistant'
        : _selectedFilterCategory;
  }

  Future<void> _openCreateScholarAccountModal() async {
    final initialScholarshipType = _selectedFilterCategory == 'All'
        ? _selectedFormCategory
        : _selectedFilterCategory;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateAccountModal(
        initialName: '',
        initialEmail: '',
        initialScholarshipType: initialScholarshipType,
        initialRole: 'scholar',
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final createdCategory =
        (result['scholarship_type'] ?? initialScholarshipType).trim();
    setState(() {
      _selectedFilterCategory =
          createdCategory.isEmpty ? initialScholarshipType : createdCategory;
    });

    BackendApi.invalidateCache(pathContains: 'get_scholars.php');
    BackendApi.invalidateCache(pathContains: 'get_monitoring_summary.php');
    _toast('Scholar account created successfully.', Colors.green);
    await fetchScholars();
  }

  void _showDeleteConfirmation(String userId, String name) {
    final isPermanent = _showArchived;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPermanent ? "Delete Permanently" : "Delete Scholar",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isPermanent
              ? "Permanently delete $name? This cannot be undone."
              : "Are you sure you want to remove $name?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteScholar(userId);
            },
            child: Text(
              isPermanent ? "Delete Permanently" : "Delete",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmation(String userId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Restore Scholar",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: Text("Restore $name to active scholars?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _restoreScholar(userId);
            },
            child: const Text(
              "Restore",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({
    required String title,
    required VoidCallback onSave,
    bool isEdit = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                backgroundColor: const Color(0xFFFCFBFE),
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2D0D44),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 420;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE7DDF2)),
                              ),
                              child: Text(
                                isEdit
                                    ? 'Update course and year information.'
                                    : 'Enter scholar profile information.',
                                style: const TextStyle(
                                  color: Color(0xFF6A5A79),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (!isEdit) ...[
                              if (isCompact) ...[
                                _modalField(
                                  controller: _firstNameController,
                                  label: 'First Name*',
                                ),
                                const SizedBox(height: 10),
                                _modalField(
                                  controller: _middleNameController,
                                  label: 'Middle Name',
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _modalField(
                                        controller: _firstNameController,
                                        label: 'First Name*',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _modalField(
                                        controller: _middleNameController,
                                        label: 'Middle Name',
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              _modalField(
                                controller: _lastNameController,
                                label: 'Last Name*',
                              ),
                              const SizedBox(height: 10),
                              _modalField(
                                controller: _emailController,
                                label: 'Email*',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 10),
                              if (isCompact) ...[
                                _modalField(
                                  controller: _passwordController,
                                  label: 'Password*',
                                  obscureText: true,
                                ),
                                const SizedBox(height: 10),
                                _modalField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password*',
                                  obscureText: true,
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _modalField(
                                        controller: _passwordController,
                                        label: 'Password*',
                                        obscureText: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _modalField(
                                        controller: _confirmPasswordController,
                                        label: 'Confirm Password*',
                                        obscureText: true,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                            ],
                            DropdownButtonFormField<String>(
                              value: _selectedFormCategory == 'All'
                                  ? 'Student Assistant'
                                  : _selectedFormCategory,
                              items: _categories
                                  .where((c) => c != 'All')
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setDialogState(() {
                                  _selectedFormCategory = v;
                                  if (v != 'Student Assistant') {
                                    _assignedAreaController.clear();
                                  }
                                  if (v == 'Gift of Education' &&
                                      !ScholarshipTypes.giftTypeOptions
                                          .containsKey(_selectedGiftType)) {
                                    _selectedGiftType = ScholarshipTypes
                                        .giftTypeOptions.keys.first;
                                  }
                                });
                              },
                              decoration: _modalInputDecoration('Category'),
                            ),
                            const SizedBox(height: 10),
                            if (_selectedFormCategory == 'Academic Scholar') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedAcademicType,
                                items: const ['Type A', 'Type B', 'Type C']
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setDialogState(() => _selectedAcademicType = v);
                                },
                                decoration:
                                    _modalInputDecoration('Academic Type'),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (_selectedFormCategory == 'Varsity Scholar') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedSportType,
                                items: const ['Basketball', 'Volleyball']
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setDialogState(() => _selectedSportType = v);
                                },
                                decoration: _modalInputDecoration('Sport Type'),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (_selectedFormCategory == 'Gift of Education') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedGiftType,
                                items: ScholarshipTypes.giftTypeOptions.keys
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setDialogState(() => _selectedGiftType = v);
                                },
                                decoration: _modalInputDecoration('Gift Type'),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (isCompact) ...[
                              _modalField(
                                controller: _courseController,
                                label: 'Course*',
                              ),
                              const SizedBox(height: 10),
                              _modalField(
                                controller: _yearLevelController,
                                label: 'Year Level*',
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: _modalField(
                                      controller: _courseController,
                                      label: 'Course*',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _modalField(
                                      controller: _yearLevelController,
                                      label: 'Year Level*',
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            if (_selectedFormCategory == 'Student Assistant')
                              _modalField(
                                controller: _assignedAreaController,
                                label: 'Assigned Area',
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A2A6A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            Navigator.pop(context);
                            onSave();
                          },
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              )),
    );
  }

  InputDecoration _modalInputDecoration(String label) {
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

  Widget _modalField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      decoration: _modalInputDecoration(label),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }

  void _showArchiveConfirmation(String userId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Archive Scholar",
          style: TextStyle(
            color: Color(0xFF8E4B10),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Archive $name?\n\nArchived scholars can't log in, but their records remain in the system.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E4B10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _archiveScholar(userId);
            },
            child: const Text(
              "Archive",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F2F7),
      child: RefreshIndicator(
        onRefresh: fetchScholars,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildToolbar(),
            const SizedBox(height: 14),
            _buildStatsRow(),
            const SizedBox(height: 14),
            _buildScholarTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scholar Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D0D44),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage scholar records, assignments, and scholarship categories.',
            style: TextStyle(color: Color(0xFF6A5A79)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => _applyFilter(),
          decoration: InputDecoration(
            hintText: 'Search by name, email, course, category, or area...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        );
        final categoryFilter = DropdownButtonFormField<String>(
          value: _selectedFilterCategory,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedFilterCategory = v);
            _applyFilter();
          },
        );
        final addButton = FilledButton.icon(
          onPressed: _showArchived
              ? null
              : () {
                  _clearForm();
                  _openCreateScholarAccountModal();
                },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Scholar'),
        );
        final archiveToggleButton = OutlinedButton.icon(
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() {
                    _showArchived = !_showArchived;
                    _selectedFilterCategory = 'All';
                  });
                  BackendApi.invalidateCache(pathContains: 'get_scholars.php');
                  await fetchScholars();
                },
          icon: Icon(
            _showArchived ? Icons.groups_rounded : Icons.archive_outlined,
          ),
          label: Text(_showArchived ? 'View Active Scholars' : 'View Archive'),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              categoryFilter,
              const SizedBox(height: 10),
              archiveToggleButton,
              const SizedBox(height: 10),
              addButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: searchField),
            const SizedBox(width: 10),
            SizedBox(width: 230, child: categoryFilter),
            const SizedBox(width: 10),
            archiveToggleButton,
            const SizedBox(width: 10),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildStatsRow() {
    final total = _scholars.length;
    final visible = _filteredScholars.length;
    final selectedLabel = _selectedFilterCategory == 'All'
        ? (_showArchived ? 'Archived Scholars' : 'Student Assistants')
        : _selectedFilterCategory;
    final selectedKey = _normalizeCategory(_selectedFilterCategory);
    final selectedCount = _scholars.where((s) {
      final cat = _normalizeCategory(
        (s['scholarship_category'] ?? '').toString(),
      );
      return selectedKey == 'all'
          ? cat == 'student assistant'
          : cat == selectedKey;
    }).length;
    final selectedAccent = _categoryAccentForStats(selectedKey);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 10.0;
        final columns = width >= 1000
            ? 3
            : width >= 640
                ? 2
                : 1;
        final cardWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _statCard(
                'Total Scholars',
                total.toString(),
                const Color(0xFF5E35B1),
                Icons.people_alt_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _statCard(
                'Filtered Results',
                visible.toString(),
                const Color.fromARGB(255, 215, 171, 196),
                Icons.filter_alt_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _statCard(
                selectedLabel,
                selectedCount.toString(),
                selectedAccent,
                _categoryIconForStats(selectedKey),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _categoryAccentForStats(String key) {
    switch (key) {
      case 'student assistant':
        return const Color(0xFF2E7D32);
      case 'academic scholar':
        return const Color(0xFF6A1B9A);
      case 'varsity scholar':
        return const Color(0xFF5E35B1);
      case 'gift of education':
        return const Color(0xFFD84315);
      case 'all':
      default:
        return const Color.fromARGB(255, 184, 141, 178);
    }
  }

  IconData _categoryIconForStats(String key) {
    switch (key) {
      case 'student assistant':
        return Icons.badge_outlined;
      case 'academic scholar':
        return Icons.school_outlined;
      case 'varsity scholar':
        return Icons.sports_basketball_outlined;
      case 'gift of education':
        return Icons.volunteer_activism_outlined;
      case 'all':
      default:
        return Icons.groups_rounded;
    }
  }

  Color _shiftLightness(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftLightness(color, 0.30).withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -14,
            child: Opacity(
              opacity: 0.10,
              child: Icon(icon, size: 96, color: color),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.18)),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6A5A79),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920) {
          return const Row(
            children: [
              Expanded(flex: 3, child: Text('Scholar')),
              Expanded(flex: 3, child: Text('Academic Info')),
              Expanded(flex: 2, child: Text('Category')),
              Expanded(flex: 2, child: Text('Assigned / Type')),
              Expanded(flex: 2, child: Text('Actions')),
            ],
          );
        }

        return const Text(
          'Scholar Records',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D0D44),
          ),
        );
      },
    );
  }

  Widget _mobileInfoGroup(String label, Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6A5A79),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _responsiveScholarRow({
    required Widget scholar,
    required Widget academicInfo,
    required Widget category,
    required Widget assignedType,
    required Widget actions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920) {
          return Row(
            children: [
              Expanded(flex: 3, child: scholar),
              Expanded(flex: 3, child: academicInfo),
              Expanded(flex: 2, child: category),
              Expanded(flex: 2, child: assignedType),
              Expanded(flex: 2, child: actions),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            scholar,
            const SizedBox(height: 8),
            academicInfo,
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _mobileInfoGroup('Category', category),
                _mobileInfoGroup('Assigned / Type', assignedType),
              ],
            ),
            const SizedBox(height: 8),
            actions,
          ],
        );
      },
    );
  }

  Widget _actionButtons(
    Map<String, dynamic> scholar,
    String course,
    String year,
    String rawAssigned,
    String rawCategory,
    String name,
  ) {
    if (_showArchived) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showRestoreConfirmation(
                (scholar['user_id'] ?? '').toString(),
                name,
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Restore'),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _showDeleteConfirmation(
                (scholar['user_id'] ?? '').toString(),
                name,
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Permanently'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              _courseController.text = course;
              _yearLevelController.text = year;
              _assignedAreaController.text = rawAssigned == '-' ? '' : rawAssigned;
              _selectedFormCategory = _displayCategory(rawCategory);
              _selectedAcademicType = _academicTypeLabel(scholar['academic_type']);
              _selectedSportType = _sportTypeLabel(scholar['sport_type']);
              _selectedGiftType = _giftTypeLabel(scholar['gift_type']).isEmpty
                  ? ScholarshipTypes.giftTypeOptions.keys.first
                  : _giftTypeLabel(scholar['gift_type']);
              _showFormDialog(
                title: 'Edit Scholar',
                isEdit: true,
                onSave: () =>
                    _editScholar((scholar['scholar_id'] ?? '').toString()),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _showArchiveConfirmation(
              (scholar['user_id'] ?? '').toString(),
              name,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8E4B10),
            ),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Archive'),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _showDeleteConfirmation(
              (scholar['user_id'] ?? '').toString(),
              name,
            ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildScholarTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          : _filteredScholars.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(_showArchived
                      ? 'No archived scholars found for your current filters.'
                      : 'No scholars found for your current filters.'),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F1FB),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: _buildTableHeader(),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredScholars.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final s = _filteredScholars[index];
                        final name = _fullName(s);
                        final email = (s['email'] ?? '').toString();
                        final course = (s['course'] ?? '-').toString();
                        final year = (s['year_level'] ?? '-').toString();
                        final rawCategory =
                            (s['scholarship_category'] ?? '').toString().trim();
                        final category = _displayCategory(rawCategory);
                        final rawAssigned =
                            (s['assigned_area'] ?? '-').toString();
                        final assignedDisplay = _assignedTypeLabel(s);

                        return Container(
                          color: index.isEven
                              ? Colors.white
                              : const Color(0xFFFCFBFE),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: _responsiveScholarRow(
                            scholar: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                      color: Color(0xFF6A5A79), fontSize: 12),
                                ),
                              ],
                            ),
                            academicInfo: Text("$course (Year $year)"),
                            category: Text(category),
                            assignedType: Text(assignedDisplay),
                            actions: _actionButtons(
                              s,
                              course,
                              year,
                              rawAssigned,
                              rawCategory,
                              name,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  String _normalizeCategory(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty ||
        value == 'student assistant' ||
        value == 'student_assistant') {
      return 'student assistant';
    }
    if (value == 'academic' || value.contains('academic')) {
      return 'academic scholar';
    }
    if (value == 'varsity' || value.contains('varsity')) {
      return 'varsity scholar';
    }
    if (value == 'gift_of_education' || value.contains('gift')) {
      return 'gift of education';
    }
    return value;
  }

  String _displayCategory(String raw) {
    final normalized = _normalizeCategory(raw);
    switch (normalized) {
      case 'student assistant':
        return 'Student Assistant';
      case 'academic scholar':
        return 'Academic Scholar';
      case 'varsity scholar':
        return 'Varsity Scholar';
      case 'gift of education':
        return 'Gift of Education';
      default:
        return raw.isEmpty ? 'Student Assistant' : raw;
    }
  }

  String _assignedTypeLabel(Map<String, dynamic> s) {
    final normalized = _normalizeCategory(
      (s['scholarship_category'] ?? '').toString(),
    );
    if (normalized == 'student assistant') {
      final assigned = (s['assigned_area'] ?? '').toString().trim();
      return assigned.isEmpty ? '-' : assigned;
    }
    if (normalized == 'academic scholar') {
      return _academicTypeLabel(s['academic_type']);
    }
    if (normalized == 'varsity scholar') {
      return _sportTypeLabel(s['sport_type']);
    }
    if (normalized == 'gift of education') {
      final label = _giftTypeLabel(s['gift_type']);
      return label.isEmpty ? '-' : label;
    }
    return '-';
  }

  String _toServerCategory(String label) {
    switch (label) {
      case 'Academic Scholar':
        return 'academic';
      case 'Varsity Scholar':
        return 'varsity';
      case 'Gift of Education':
        return 'gift_of_education';
      case 'Student Assistant':
      default:
        return 'student_assistant';
    }
  }

  String _initialScholarshipStatusPayload() {
    // Deployed PHP validates this value against allowed scholarship states.
    return 'Active';
  }

  Future<Map<String, dynamic>> _createScholarWithStatusFallback(
    Map<String, dynamic> payload,
  ) async {
    final candidates = <String>[
      _initialScholarshipStatusPayload(),
      'Approved',
      'Under Verification',
      'under_verification',
      'approved',
      'Pending',
      'pending',
      'Terminated',
      'terminated',
      'Active',
      'active',
    ];

    Map<String, dynamic> lastResponse = const {};

    for (final status in candidates) {
      final body = Map<String, dynamic>.from(payload)
        ..['scholarship_status'] = status
        ..['status'] = status;

      final response = await BackendApi.postForm(
        'add_scholar.php',
        body: _stringifyPayload(body),
      );
      lastResponse = response;

      if ((response['status'] ?? '').toString().toLowerCase() == 'success') {
        return response;
      }

      final message = (response['message'] ?? response['error'] ?? '')
          .toString()
          .toLowerCase();
      if (!message.contains('invalid scholarship status')) {
        return response;
      }
    }

    return lastResponse;
  }

  Map<String, String> _stringifyPayload(Map<String, dynamic> payload) {
    return payload.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  String _academicTypePayload() {
    if (_selectedFormCategory != 'Academic Scholar') return '';
    return _selectedAcademicType.replaceAll('Type ', '').trim().toUpperCase();
  }

  String _sportTypePayload() {
    if (_selectedFormCategory != 'Varsity Scholar') return '';
    return _selectedSportType.trim();
  }

  String _giftTypePayload() {
    if (_selectedFormCategory != 'Gift of Education') return '';
    return ScholarshipTypes.giftTypeOptions[_selectedGiftType] ??
        ScholarshipTypes.giftTypeOptions.values.first;
  }

  String _academicTypeLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toUpperCase();
    if (value == 'A') return 'Type A';
    if (value == 'B') return 'Type B';
    if (value == 'C') return 'Type C';
    return 'Type A';
  }

  String _sportTypeLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? 'Basketball' : value;
  }

  String _giftTypeLabel(dynamic raw) {
    return ScholarshipTypes.giftTypeLabel(raw);
  }
}

