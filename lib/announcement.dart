import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String selectedAudience = 'All Scholars';
  final List<String> _audiences = const [
    'All Scholars',
    'Student Assistant',
    'Academic Scholar',
    'Varsity Scholar',
    'Gift of Education',
    'Specific Scholar',
  ];
  List<Map<String, dynamic>> _scholars = [];
  String? _selectedScholarId;
  bool _loadingScholars = false;
  String? _scholarError;

  @override
  void initState() {
    super.initState();
    _loadScholars();
  }

  Future<void> saveAnnouncement() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title and content are required."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedAudience == 'Specific Scholar' &&
        (_selectedScholarId == null || _selectedScholarId!.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a specific scholar."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final decoded = await BackendApi.postForm(
        'save_announcement.php',
        body: {
          'user_id': '0',
          'title': title,
          'content': content,
          'target': selectedAudience,
          'notification_title': title,
          'message': content,
          'visibility': selectedAudience,
          if (selectedAudience == 'Specific Scholar')
            'target_user_id': _selectedScholarId ?? '',
        },
      );
      final success = decoded['success'] == true ||
          decoded['status']?.toString().toLowerCase() == 'success';
      if (!success) {
        throw Exception(
          decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              "Unknown server error",
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Announcement posted successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      _titleController.clear();
      _contentController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to post: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadScholars() async {
    setState(() {
      _loadingScholars = true;
      _scholarError = null;
    });

    try {
      final list = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_scholars.php',
          cacheTtl: const Duration(minutes: 2),
          retries: 1,
        ),
      );
      if (!mounted) return;
      setState(() {
        _scholars = list;
        _loadingScholars = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingScholars = false;
        _scholarError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC5B4E3),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final outerPadding = isCompact ? 16.0 : 40.0;
          final innerPadding = isCompact ? 18.0 : 32.0;

          return Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D0D44),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Announcement Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Create and target scholar announcements with clarity.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(innerPadding),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAnnouncementForm(fullWidthButton: true),
                                const SizedBox(height: 18),
                                _buildAudiencePanel(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildAnnouncementForm(
                                    fullWidthButton: false,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 1,
                                  child: _buildAudiencePanel(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementForm({required bool fullWidthButton}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Announcement Title',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF2D0D44))),
        const SizedBox(height: 8),
        _buildInputField(
          _titleController,
          'e.g., Scholarship Renewal Deadline for 2026',
        ),
        const SizedBox(height: 22),
        const Text('Announcement Content',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF2D0D44))),
        const SizedBox(height: 8),
        _buildInputField(
          _contentController,
          'Type the full details...',
          isLarge: true,
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: fullWidthButton ? double.infinity : null,
          child: FilledButton.icon(
            onPressed: saveAnnouncement,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.campaign_rounded),
            label: const Text(
              'Post Announcement',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudiencePanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5D9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audience Filter',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D0D44),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedAudience,
            isExpanded: true,
            items: _audiences
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                selectedAudience = v;
                if (v != 'Specific Scholar') {
                  _selectedScholarId = null;
                }
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (selectedAudience == 'Specific Scholar') ...[
            if (_loadingScholars)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_scholarError != null)
              Text(
                _scholarError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedScholarId,
                isExpanded: true,
                items: _scholars
                    .map((s) => DropdownMenuItem(
                          value: (s['user_id'] ?? '').toString(),
                          child: Text(
                            _scholarLabel(s),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedScholarId = v);
                },
                decoration: InputDecoration(
                  labelText: 'Select Scholar',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            'Selecting a group limits which scholars receive this announcement.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint,
      {bool isLarge = false}) {
    return TextField(
      controller: controller,
      maxLines: isLarge ? 6 : 1,
      decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    );
  }

  String _scholarLabel(Map<String, dynamic> s) {
    final first = (s['first_name'] ?? '').toString().trim();
    final last = (s['last_name'] ?? '').toString().trim();
    final name = '$first $last'.trim();
    final email = (s['email'] ?? '').toString().trim();
    if (email.isEmpty) return name.isEmpty ? 'Scholar' : name;
    return name.isEmpty ? email : '$name • $email';
  }
}

