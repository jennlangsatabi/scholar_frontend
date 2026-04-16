import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'profile_components.dart';
import 'services/backend_api.dart';
import 'services/api_config.dart';

class AcademicProfileScreen extends StatefulWidget {
  final String userId;
  const AcademicProfileScreen({super.key, required this.userId});

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  String? selectedSemester;
  bool isFiltered = false;
  bool isLoading = true;
  String? errorMessage;

  String scholarName = '';
  String scholarCourse = '';
  String scholarRole = 'Academic Scholar';
  String academicType = '';
  String academicBenefit = '';
  String gwaRequirement = '';
  String monthlyStipend = '';
  String firstName = '';
  String middleName = '';
  String lastName = '';
  String yearLevel = '';
  String? profileImageUrl;
  List<String> semesters = const [];
  List<List<String>> rows = const [];
  Timer? _poller;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _poller = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadProfile(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final payload = await BackendApi.getJson(
        'get_scholar_profile.php',
        query: {'user_id': widget.userId},
      );
      final profile = Map<String, dynamic>.from(
        payload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final semesterList = (payload['semesters'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();
      final detailRowsRaw = (payload['detail_rows'] as List? ?? const []);
      final parsedRows = detailRowsRaw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      var tableRows = parsedRows
          .map((row) => [
                _academicTypeDisplay(
                  (row['Scholarship Type'] ?? '').toString(),
                ),
                (row['Benefit'] ?? '').toString(),
                (row['GWA Req.'] ?? '').toString(),
                _formatMonthlyStipend(
                  (row['Monthly Stipend'] ?? '').toString(),
                ),
              ])
          .toList();

      if (!mounted) return;

      final profileAcademicType = profile['academic_type']?.toString() ?? '';
      final profileBenefit = profile['academic_benefit']?.toString() ?? '';
      final profileGwa = profile['academic_gwa_requirement']?.toString() ?? '';
      final profileStipend = profile['monthly_stipend']?.toString() ?? '';

      final profileFallbackRow = [
        _academicTypeDisplay(profileAcademicType),
        profileBenefit,
        profileGwa,
        _formatMonthlyStipend(profileStipend),
      ];

      final hasAnyProfileDetail = profileFallbackRow.any(
        (value) => value.trim().isNotEmpty,
      );
      final hasAnyTableDetail = tableRows.isNotEmpty &&
          tableRows.first.any((value) => value.trim().isNotEmpty);

      if (!hasAnyTableDetail && hasAnyProfileDetail) {
        tableRows = [profileFallbackRow];
      }

      setState(() {
        scholarName =
            profile['name']?.toString() ?? 'Scholar #${widget.userId}';
        scholarCourse = profile['course']?.toString() ?? '';
        scholarRole = profile['role']?.toString() ?? scholarRole;
        academicType = profileAcademicType;
        academicBenefit = profileBenefit;
        gwaRequirement = profileGwa;
        monthlyStipend = profileStipend;
        firstName = profile['first_name']?.toString() ?? '';
        middleName = profile['middle_name']?.toString() ?? '';
        lastName = profile['last_name']?.toString() ?? '';
        yearLevel = profile['year_level']?.toString() ?? '';
        profileImageUrl = ApiConfig.normalizeAssetUrl(
          profile['profile_image_url']?.toString(),
        );
        semesters = semesterList;
        selectedSemester = semesterList.isNotEmpty ? semesterList.first : null;
        rows = tableRows;
        _lastUpdated = DateTime.now();
        if (!silent) {
          isLoading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC5B4E3),
      body: RefreshIndicator(
        onRefresh: () => _loadProfile(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _heroProfileHeader(),
            Padding(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 16 : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      return Row(
                        children: [
                          Expanded(
                            child: buildProfileDropdown(
                              selectedSemester,
                              "Select Semester",
                              semesters,
                              (val) {
                                if (val == null) return;
                                setState(() {
                                  selectedSemester = val;
                                  isFiltered = false;
                                });
                              },
                              width: null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                if (selectedSemester != null) {
                                  setState(() => isFiltered = true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Please select a semester first",
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFAB47BC),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 18 : 40,
                                ),
                              ),
                              child: const Text(
                                "Filter",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _buildMainContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroProfileHeader() {
    final name = scholarName.isEmpty ? "Scholar #${widget.userId}" : scholarName;
    final course = scholarCourse.isEmpty
        ? "Scholarship profile pending sync"
        : scholarCourse;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/jmcbg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        color: const Color(0xFF2D0D44).withValues(alpha: 0.84),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person_rounded,
                          color: Colors.white, size: 30)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _uploadProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Color(0xFF2D0D44),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_lastUpdated != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Last updated ${_formatTime(_lastUpdated!)}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _showEditDialog,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  Future<void> _uploadProfileImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Profile Picture'),
          content: const Text('Do you want to save this profile picture?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        ApiConfig.uri('upload_profile_image.php'),
      );
      request.fields['user_id'] = widget.userId;
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: file.name),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!mounted) return;
        _showErrorSnackBar('Upload failed: $body');
        return;
      }
      if (!mounted) return;
      if (body.isNotEmpty && !body.startsWith('<')) {
        try {
          final map = jsonDecode(body) as Map<String, dynamic>;
          setState(() {
            profileImageUrl = ApiConfig.normalizeAssetUrl(
              map['profile_image_url']?.toString(),
            );
          });
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Unable to upload profile image: $e');
    }
  }

  Future<void> _showEditDialog() async {
    final firstController = TextEditingController(text: firstName);
    final middleController = TextEditingController(text: middleName);
    final lastController = TextEditingController(text: lastName);
    final courseController = TextEditingController(text: scholarCourse);
    final yearController = TextEditingController(text: yearLevel);
    final benefitController = TextEditingController(text: academicBenefit);
    final gwaController = TextEditingController(text: gwaRequirement);
    final stipendController = TextEditingController(text: monthlyStipend);
    String selectedAcademic = _academicLabel(academicType);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _modalField(firstController, 'First Name'),
                const SizedBox(height: 10),
                _modalField(middleController, 'Middle Name'),
                const SizedBox(height: 10),
                _modalField(lastController, 'Last Name'),
                const SizedBox(height: 10),
                _modalField(courseController, 'Course'),
                const SizedBox(height: 10),
                _modalField(yearController, 'Year Level'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedAcademic,
                  items: const ['Type A', 'Type B', 'Type C']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    selectedAcademic = v;
                  },
                  decoration: _modalInputDecoration('Academic Type'),
                ),
                const SizedBox(height: 10),
                _modalField(benefitController, 'Benefit'),
                const SizedBox(height: 10),
                _modalField(gwaController, 'GWA Req.'),
                const SizedBox(height: 10),
                _modalField(stipendController, 'Monthly Stipend'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await BackendApi.postJson(
                  'update_profile.php',
                  body: {
                    'user_id': widget.userId,
                    'first_name': firstController.text.trim(),
                    'middle_name': middleController.text.trim(),
                    'last_name': lastController.text.trim(),
                    'course': courseController.text.trim(),
                    'year_level': yearController.text.trim().isEmpty
                        ? '1'
                        : yearController.text.trim(),
                    'academic_type': _academicPayload(selectedAcademic),
                    'academic_benefit': benefitController.text.trim(),
                    'academic_gwa_requirement': gwaController.text.trim(),
                    'monthly_stipend': stipendController.text.trim(),
                  },
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                await _loadProfile();
              } catch (e) {
                if (!mounted) return;
                _showErrorSnackBar('Unable to save profile changes: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _academicLabel(String raw) {
    final value = raw.toUpperCase();
    if (value == 'B') return 'Type B';
    if (value == 'C') return 'Type C';
    return 'Type A';
  }

  String _academicTypeDisplay(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty || value == 'NULL') return '';
    if (value == 'A' || value == 'TYPE A') return 'Type A';
    if (value == 'B' || value == 'TYPE B') return 'Type B';
    if (value == 'C' || value == 'TYPE C') return 'Type C';
    return raw.trim();
  }

  String _formatMonthlyStipend(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    if (text.toUpperCase().contains('PHP')) return text;
    final cleaned = text.replaceAll(',', '');
    final value = double.tryParse(cleaned);
    if (value == null) return text;
    return 'PHP ${value.toStringAsFixed(2)}';
  }

  String _academicPayload(String label) {
    return label.replaceAll('Type ', '').trim().toUpperCase();
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

  Widget _modalField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: _modalInputDecoration(label),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return _profileCard(
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (errorMessage != null) {
      return _profileCard(child: buildEmptyState(errorMessage!));
    }

    if (!isFiltered || rows.isEmpty) {
      return _profileCard(
        child: buildEmptyState(
          "Click Filter to view your current academic scholarship details.",
        ),
      );
    }

    return _profileCard(
      borderColor: const Color(0xFFAB47BC),
      borderWidth: 2,
      child: ProfileDataTable(
        headers: const [
          "Scholarship Type",
          "Benefit",
          "GWA Req.",
          "Monthly Stipend"
        ],
        rows: rows,
      ),
    );
  }

  Widget _profileCard({
    required Widget child,
    Color borderColor = const Color(0xFFE6DFF0),
    double borderWidth = 1,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}


