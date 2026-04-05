import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'profile_components.dart';
import 'services/backend_api.dart';
import 'services/api_config.dart';
import 'scholarship_types.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? selectedSemester;
  bool isFiltered = false;
  bool isLoading = true;
  String? errorMessage;

  String scholarName = '';
  String scholarCourse = '';
  String scholarRole = 'Student Assistant Scholar';
  String scholarCategory = '';
  String assignedArea = '';
  String giftType = '';
  String giftGrantCoverage = '';
  String giftRetentionGwa = '';
  String giftRenewalStatus = '';
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
      const Duration(seconds: 15),
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
      final results = await Future.wait([
        BackendApi.getJson(
          'get_scholar_profile.php',
          query: {'user_id': widget.userId},
        ),
        BackendApi.getJson(
          'get_sa_stats.php',
          query: {'user_id': widget.userId},
        ),
        BackendApi.getJson('get_monitoring_summary.php'),
      ]);
      final payload = results[0];
      final statsPayload = results[1];
      final monitoringPayload = results[2];
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
      final giftDetailRow = parsedRows.firstWhere(
        (row) =>
            row.containsKey('Grant Coverage') ||
            row.containsKey('Retention GWA') ||
            row.containsKey('Renewal Status') ||
            row.containsKey('Scholarship Type'),
        orElse: () => const <String, dynamic>{},
      );
      final monitoringRow = _findMonitoringRow(monitoringPayload);
      final monitoringDuty = _splitDutyHours(
        (monitoringRow['duty_hours'] ?? '').toString(),
      );

      final tableRows = parsedRows
          .map((row) => [
                (row['Assign Area'] ?? '').toString(),
                _firstNonEmpty([
                  monitoringDuty.$1,
                  statsPayload['rendered_hours'],
                  statsPayload['rendered'],
                  row['Duty Hours'],
                ]),
                _firstNonEmpty([
                  monitoringRow['supervisor'],
                  row['Supervisor'],
                  profile['supervisor'],
                ], fallback: 'Scholarship Office'),
                _firstNonEmpty([
                  monitoringDuty.$2,
                  monitoringRow['required_hours'],
                  row['Required Hours'],
                  statsPayload['required_hours'],
                  statsPayload['required'],
                ], fallback: '400'),
              ])
          .toList();

      if (!mounted) return;
      setState(() {
        scholarName =
            profile['name']?.toString() ?? 'Scholar #${widget.userId}';
        scholarCourse = profile['course']?.toString() ?? '';
        scholarRole = profile['role']?.toString() ?? scholarRole;
        scholarCategory = profile['scholarship_category']?.toString() ?? '';
        assignedArea = profile['assigned_area']?.toString() ?? '';
        giftType = profile['gift_type']?.toString() ?? '';
        giftGrantCoverage = _firstNonEmpty([
          profile['grant_coverage'],
          giftDetailRow['Grant Coverage'],
          monitoringRow['grant_coverage'],
        ], fallback: '100% Free');
        giftRetentionGwa = _firstNonEmpty([
          profile['retention_gwa'],
          profile['gpa'],
          giftDetailRow['Retention GWA'],
          giftDetailRow['GWA Req.'],
          monitoringRow['retention_gwa'],
          monitoringRow['gpa'],
        ], fallback: '80%');
        giftRenewalStatus = _prettyRenewalStatus(_firstNonEmpty([
          profile['scholarship_status'],
          profile['status'],
          giftDetailRow['Renewal Status'],
          giftDetailRow['Status'],
          monitoringRow['scholarship_status'],
          monitoringRow['status'],
        ], fallback: 'Active'));
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

  Map<String, dynamic> _findMonitoringRow(Map<String, dynamic> payload) {
    final scholars = (payload['scholars'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    for (final scholar in scholars) {
      if ((scholar['user_id'] ?? '').toString() == widget.userId) {
        return scholar;
      }
    }
    return const <String, dynamic>{};
  }

  (String, String) _splitDutyHours(String raw) {
    final parts = raw.split('/');
    final rendered = parts.isNotEmpty ? parts.first.trim() : '';
    final required = parts.length > 1 ? parts[1].trim() : '';
    return (rendered, required);
  }

  String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return fallback;
  }

  String _prettyRenewalStatus(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Active';
    final normalized = value.toLowerCase().replaceAll('_', ' ');
    final parts = normalized
        .split(RegExp(r'\\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'Active';
    return parts.map((word) {
      final lower = word.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
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
                              (val) => setState(() => selectedSemester = val),
                              width: null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () =>
                                  setState(() => isFiltered = true),
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
        color: const Color(0xFF2D0D44).withOpacity(0.84),
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
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!mounted) return;
        _showErrorSnackBar('Upload failed: $body');
        return;
      }

      if (!mounted) return;
      setState(() {
        // Try to parse response without strict decode helper.
        if (body.isNotEmpty && !body.startsWith('<')) {
          try {
            final map = jsonDecode(body) as Map<String, dynamic>;
            profileImageUrl = ApiConfig.normalizeAssetUrl(
              map['profile_image_url']?.toString(),
            );
          } catch (_) {}
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Unable to upload profile image: $e');
    }
  }

  Future<void> _showEditDialog() async {
    final firstController = TextEditingController(
        text: firstName.isEmpty ? scholarName.split(' ').first : firstName);
    final lastController = TextEditingController(
        text: lastName.isEmpty
            ? scholarName.split(' ').skip(1).join(' ')
            : lastName);
    final middleController = TextEditingController(text: middleName);
    final courseController = TextEditingController(text: scholarCourse);
    final yearController = TextEditingController(text: yearLevel);
    final areaController = TextEditingController(text: assignedArea);
    final grantCoverageController =
        TextEditingController(text: giftGrantCoverage);
    final retentionGwaController =
        TextEditingController(text: giftRetentionGwa);
    final renewalStatusController =
        TextEditingController(text: giftRenewalStatus);
    String selectedGift = ScholarshipTypes.giftTypeLabel(giftType);
    if (!ScholarshipTypes.giftTypeLabels.contains(selectedGift)) {
      selectedGift = ScholarshipTypes.giftTypeLabels.first;
    }

    final normalizedCategory = scholarCategory.toLowerCase();
    final isGift = normalizedCategory.contains('gift');
    final isStudentAssistant =
        normalizedCategory.isEmpty || normalizedCategory.contains('student');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                if (isStudentAssistant) ...[
                  const SizedBox(height: 10),
                  _modalField(areaController, 'Assigned Area'),
                ],
                if (isGift) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedGift,
                    items: ScholarshipTypes.giftTypeLabels
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      selectedGift = v;
                    },
                    decoration: _modalInputDecoration('Gift Type'),
                  ),
                  const SizedBox(height: 10),
                  _modalField(grantCoverageController, 'Grant Coverage'),
                  const SizedBox(height: 10),
                  _modalField(retentionGwaController, 'Retention GWA'),
                  const SizedBox(height: 10),
                  _modalField(renewalStatusController, 'Renewal Status'),
                ],
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
                    'assigned_area':
                        isStudentAssistant ? areaController.text.trim() : '',
                    'gift_type': isGift
                        ? ScholarshipTypes.giftTypePayload(selectedGift)
                        : '',
                    'grant_coverage':
                        isGift ? grantCoverageController.text.trim() : '',
                    'gpa': isGift ? retentionGwaController.text.trim() : '',
                    'scholarship_status':
                        isGift ? renewalStatusController.text.trim() : '',
                  },
                );
                if (!mounted) return;
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

  Widget _profileCard(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6DFF0)),
      ),
      child: child,
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return _profileCard(
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (errorMessage != null) {
      return _profileCard(buildEmptyState(errorMessage!));
    }

    // Check if the scholar is under the Gift of Education program
    bool isGiftOfEducation =
        scholarRole.toLowerCase().contains("gift of education") ||
            giftType.isNotEmpty;

    if (!isFiltered || (rows.isEmpty && !isGiftOfEducation)) {
      return _profileCard(
        buildEmptyState(
          "Select an academic term and click Filter to view your official records.",
        ),
      );
    }

    final giftScholarshipLabel = ScholarshipTypes.giftTypeLabel(giftType);

    return _profileCard(
      ProfileDataTable(
        headers: [
          "Scholarship Type",
          isGiftOfEducation ? "Grant Coverage" : "Duty Hours",
          isGiftOfEducation ? "Retention GWA" : "Supervisor",
          isGiftOfEducation ? "Renewal Status" : "Required Hours",
        ],
        rows: [
          [
            isGiftOfEducation
                ? (giftScholarshipLabel.isEmpty
                    ? "Gift of Education"
                    : giftScholarshipLabel)
                : scholarRole,
            isGiftOfEducation ? giftGrantCoverage : rows[0][1],
            isGiftOfEducation ? giftRetentionGwa : rows[0][2],
            isGiftOfEducation ? giftRenewalStatus : rows[0][3],
          ]
        ],
      ),
    );
  }

}
