import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'profile_components.dart';
import 'services/backend_api.dart';
import 'services/api_config.dart';

class VarsityProfileScreen extends StatefulWidget {
  final String userId;
  const VarsityProfileScreen({super.key, required this.userId});

  @override
  State<VarsityProfileScreen> createState() => _VarsityProfileScreenState();
}

class _VarsityProfileScreenState extends State<VarsityProfileScreen> {
  String? selectedSemester;
  bool isFiltered = false;
  bool isLoading = true;
  String? errorMessage;

  String scholarName = '';
  String scholarCourse = '';
  String scholarRole = 'Varsity Scholar';
  String sportType = '';
  String headCoach = '';
  String trainingSchedule = '';
  String gameSchedule = '';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfile(silent: true);
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

      final tableRows = parsedRows
          .map((row) => [
                (row['Sport'] ?? '').toString(),
                (row['Head Coach'] ?? '').toString(),
                (row['Training Schedule'] ?? '').toString(),
                (row['Game Schedule'] ?? '').toString(),
              ])
          .toList();

      if (!mounted) return;
      setState(() {
        scholarName = profile['name']?.toString() ?? 'Scholar #${widget.userId}';
        scholarCourse = profile['course']?.toString() ?? '';
        scholarRole = profile['role']?.toString() ?? scholarRole;
        sportType = profile['sport_type']?.toString() ?? '';
        headCoach = profile['head_coach']?.toString() ?? '';
        trainingSchedule = profile['training_schedule']?.toString() ?? '';
        gameSchedule = profile['game_schedule']?.toString() ?? '';
        firstName = profile['first_name']?.toString() ?? '';
        middleName = profile['middle_name']?.toString() ?? '';
        lastName = profile['last_name']?.toString() ?? '';
        yearLevel = profile['year_level']?.toString() ?? '';
        profileImageUrl = profile['profile_image_url']?.toString() ?? '';
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
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      buildProfileDropdown(
                        selectedSemester,
                        "Select Semester",
                        semesters,
                        (val) => setState(() {
                          selectedSemester = val;
                          isFiltered = false;
                        }),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => isFiltered = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAB47BC),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 22,
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
                    ],
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $body')));
      return;
    }
    if (!mounted) return;
    if (body.isNotEmpty && !body.startsWith('<')) {
      try {
        final map = jsonDecode(body) as Map<String, dynamic>;
        setState(() {
          profileImageUrl =
              map['profile_image_url']?.toString() ?? profileImageUrl;
        });
      } catch (_) {}
    }
  }

  Future<void> _showEditDialog() async {
    final firstController = TextEditingController(text: firstName);
    final middleController = TextEditingController(text: middleName);
    final lastController = TextEditingController(text: lastName);
    final courseController = TextEditingController(text: scholarCourse);
    final yearController = TextEditingController(text: yearLevel);
    final sportController = TextEditingController(text: sportType);
    final headCoachController = TextEditingController(text: headCoach);
    final trainingScheduleController =
        TextEditingController(text: trainingSchedule);
    final gameScheduleController = TextEditingController(text: gameSchedule);

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
                _modalField(sportController, 'Sport Type'),
                const SizedBox(height: 10),
                _modalField(headCoachController, 'Head Coach'),
                const SizedBox(height: 10),
                _modalField(trainingScheduleController, 'Training Schedule'),
                const SizedBox(height: 10),
                _modalField(gameScheduleController, 'Game Schedule'),
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
                  'sport_type': sportController.text.trim(),
                  'head_coach': headCoachController.text.trim(),
                  'training_schedule': trainingScheduleController.text.trim(),
                  'game_schedule': gameScheduleController.text.trim(),
                },
              );
              if (!mounted) return;
              Navigator.pop(context);
              await _loadProfile();
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
          "Click Filter to view your varsity assignment details.",
        ),
      );
    }

    return _profileCard(
      borderColor: const Color(0xFFAB47BC),
      borderWidth: 2,
      child: ProfileDataTable(
        headers: const [
          "Sport",
          "Head Coach",
          "Training Schedule",
          "Game Schedule"
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
            color: Colors.black.withOpacity(0.05),
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
