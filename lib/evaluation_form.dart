import 'dart:convert';

import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class EvaluationFormScreen extends StatefulWidget {
  final VoidCallback onClose;

  const EvaluationFormScreen({super.key, required this.onClose});

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  String _selectedProgram = 'Student Assistant';
  List<Map<String, dynamic>> _scholars = [];
  bool _loading = true;
  String? _error;

  String? _selectedScholarId;

  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _assignedAreaController = TextEditingController();
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _recommendationController =
      TextEditingController();

  final Map<String, int> _ratings = {};

  @override
  void initState() {
    super.initState();
    _loadScholars();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _assignedAreaController.dispose();
    _supervisorController.dispose();
    _monthController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  Future<void> _loadScholars() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await BackendApi.getJson(
        'get_scholars.php',
        cacheTtl: const Duration(minutes: 2),
        retries: 1,
      );
      final list = _unwrapList(payload);
      if (!mounted) return;
      setState(() {
        _scholars = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _unwrapList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (payload is Map) {
      final data = payload['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _filteredScholars() {
    final key = _selectedProgram == 'Student Assistant'
        ? 'student_assistant'
        : 'varsity';
    return _scholars.where((scholar) {
      final raw = (scholar['scholarship_category'] ?? scholar['category'] ?? '')
          .toString()
          .toLowerCase();
      final normalized = raw.replaceAll(' ', '').replaceAll('_', '');
      if (key == 'student_assistant') {
        return normalized.contains('studentassistant');
      }
      return normalized.contains('varsity');
    }).toList();
  }

  List<_RatingItem> _ratingItems() {
    if (_selectedProgram == 'Student Assistant') {
      return const [
        _RatingItem('Attendance',
            'Avoid absences and tardiness; provides notice of absence.'),
        _RatingItem('Quantity of Work',
            'Functions effectively within time or work schedule.'),
        _RatingItem('Quality of Work',
            'Work is resourceful, thorough, neat, accurate, and complete.'),
        _RatingItem('Communication Skills',
            'Follows instructions and seeks clarification when needed.'),
        _RatingItem('Attitude',
            'Accepts suggestions, responsibilities, and improves techniques.'),
        _RatingItem('Personality',
            'Shows effective interpersonal skills and proper grooming.'),
        _RatingItem(
            'Other', 'Performs other tasks requested by the supervisor.'),
      ];
    }

    return const [
      _RatingItem(
          'Attendance & Commitment', 'Reports consistently to training.'),
      _RatingItem('Athletic Performance', 'Shows measurable skill progress.'),
      _RatingItem(
          'Teamwork', 'Cooperates with teammates and respects team roles.'),
      _RatingItem(
          'Coachability', 'Applies feedback and is open to correction.'),
      _RatingItem('Discipline', 'Follows team policies and routines.'),
      _RatingItem('Sportsmanship', 'Displays respect on and off the court.'),
      _RatingItem('Academic Balance',
          'Manages academic responsibilities alongside training.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/jmcbg.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFF3B125A).withValues(alpha: 0.68)),
          ),
          SafeArea(
            child: Center(
              child: Container(
                width: 980,
                constraints: const BoxConstraints(maxWidth: 1100),
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1F8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE1D6EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context),
                    const SizedBox(height: 16),
                    _programSelector(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _error != null
                              ? _errorCard(_error!)
                              : SingleChildScrollView(
                                  child: _formBody(),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.assignment_turned_in_rounded,
              color: Color(0xFF4A148C)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scholar Evaluation Form',
                style: TextStyle(
                  color: Color(0xFF2D0D44),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Select a scholar type, choose a student, then rate performance.',
                style: TextStyle(color: Color(0xFF6F5E7D)),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF4A148C)),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Close'),
        ),
      ],
    );
  }

  Widget _programSelector() {
    return Row(
      children: [
        _glassChoiceChip('Student Assistant'),
        const SizedBox(width: 10),
        _glassChoiceChip('Varsity'),
      ],
    );
  }

  Widget _glassChoiceChip(String label) {
    final selected = _selectedProgram == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedProgram = label;
          _selectedScholarId = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6A1B9A) : const Color(0xFFE9E0F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF6A1B9A) : const Color(0xFFD3C1E5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A148C),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _formBody() {
    final filtered = _filteredScholars();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;
        final detailsPanel = _glassPanel(
          title: 'Scholar Details',
          child: Column(
            children: [
              _dropdownField(
                label: 'Select Scholar',
                value: _selectedScholarId,
                items: filtered,
                onChanged: (value) {
                  setState(() {
                    _selectedScholarId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _textField('Course & Year Level', _courseController),
              const SizedBox(height: 12),
              if (_selectedProgram == 'Student Assistant')
                _textField('Assigned Area', _assignedAreaController),
              if (_selectedProgram == 'Student Assistant')
                const SizedBox(height: 12),
              _textField('Name of Supervisor', _supervisorController),
              const SizedBox(height: 12),
              _textField('For the Month', _monthController),
            ],
          ),
        );

        final ratingsPanel = _glassPanel(
          title: 'Performance Ratings',
          child: Column(
            children: [
              _ratingHeader(),
              const SizedBox(height: 8),
              ..._ratingItems().map(_ratingRow),
              const SizedBox(height: 10),
              _glassPanel(
                title: 'Recommendation / Area of Improvement',
                child: TextField(
                  controller: _recommendationController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: _inputDecoration('Write notes...'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _scoreSummary()),
                  const SizedBox(width: 12),
                  _submitButton(),
                ],
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              detailsPanel,
              const SizedBox(height: 16),
              ratingsPanel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: detailsPanel),
            const SizedBox(width: 18),
            Expanded(flex: 3, child: ratingsPanel),
          ],
        );
      },
    );
  }

  Widget _ratingHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text('Area',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 5,
            child: Text('Description',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 3,
            child: Text('Rating (5 to 1)',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(_RatingItem item) {
    final selected = _ratings[item.title];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.title,
                style: const TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 5,
            child: Text(item.description,
                style: const TextStyle(color: Color(0xFF6F5E7D))),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              children: List.generate(5, (index) {
                final rating = 5 - index;
                final isSelected = selected == rating;
                return InkWell(
                  onTap: () {
                    setState(() => _ratings[item.title] = rating);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 34,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6A1B9A)
                          : const Color(0xFFF2ECF7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6A1B9A)
                              : const Color(0xFFE1D6EB)),
                    ),
                    child: Text(
                      rating.toString(),
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF4A148C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreSummary() {
    final ratings = _ratings.values.toList();
    final total = ratings.isEmpty ? 0 : ratings.reduce((a, b) => a + b);
    final avg = ratings.isEmpty ? 0 : total / ratings.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Score: $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Average: ${avg.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return ElevatedButton.icon(
      onPressed: _submitEvaluation,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4A148C),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.send_rounded),
      label: const Text('Submit'),
    );
  }

  Future<void> _submitEvaluation() async {
    if (_selectedScholarId == null || _selectedScholarId!.isEmpty) {
      _showToast('Please select a scholar.');
      return;
    }

    final items = _ratingItems();
    final missing = items.where((item) => !_ratings.containsKey(item.title));
    if (missing.isNotEmpty) {
      _showToast('Please complete all ratings.');
      return;
    }

    final totalScore =
        _ratings.values.fold<int>(0, (sum, value) => sum + value);
    final average = items.isEmpty ? 0 : totalScore / items.length;

    try {
      final payload = await BackendApi.postForm(
        'save_evaluation.php',
        body: {
          'scholar_id': _selectedScholarId!,
          'program_type': _selectedProgram == 'Student Assistant'
              ? 'student_assistant'
              : 'varsity',
          'course_year': _courseController.text.trim(),
          'assigned_area': _assignedAreaController.text.trim(),
          'supervisor_name': _supervisorController.text.trim(),
          'month_label': _monthController.text.trim(),
          'ratings_json': jsonEncode(_ratings),
          'total_score': totalScore.toString(),
          'average_score': average.toStringAsFixed(2),
          'recommendation': _recommendationController.text.trim(),
        },
      );

      final status = payload['status']?.toString().toLowerCase();
      if (status != null && status != 'success') {
        throw Exception(payload['message']?.toString() ?? 'Save failed.');
      }

      if (!mounted) return;
      _showToast('Evaluation submitted successfully.');
      _resetForm();
    } catch (e) {
      _showToast('Failed to submit: $e');
    }
  }

  void _resetForm() {
    setState(() {
      _ratings.clear();
      _selectedScholarId = null;
      _courseController.clear();
      _assignedAreaController.clear();
      _supervisorController.clear();
      _monthController.clear();
      _recommendationController.clear();
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _glassPanel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1D6EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2D0D44),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF2D0D44)),
      decoration: _inputDecoration(label),
      items: items.map((item) {
        final name = item['full_name']?.toString() ??
            item['name']?.toString() ??
            item['email']?.toString() ??
            [item['first_name']?.toString(), item['last_name']?.toString()]
                .where((part) => part != null && part.isNotEmpty)
                .join(' ');
        final id = item['user_id']?.toString() ??
            item['id']?.toString() ??
            item['scholar_id']?.toString() ??
            '';
        return DropdownMenuItem(
          value: id,
          child: Text(name, style: const TextStyle(color: Color(0xFF2D0D44))),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(label),
      style: const TextStyle(color: Color(0xFF2D0D44)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF6F5E7D)),
      hintStyle: const TextStyle(color: Color(0xFF6F5E7D)),
      filled: true,
      fillColor: const Color(0xFFF5F1F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF2D0D44)),
      ),
    );
  }
}

class EvaluationRecordScreen extends StatelessWidget {
  final Map<String, dynamic> evaluation;
  final VoidCallback onClose;

  const EvaluationRecordScreen({
    super.key,
    required this.evaluation,
    required this.onClose,
  });

  String get _programKey =>
      (evaluation['program_type'] ?? '').toString().trim().toLowerCase();

  String get _programLabel {
    if (_programKey == 'varsity') return 'Varsity';
    return 'Student Assistant';
  }

  List<_RatingItem> _ratingItems() {
    if (_programKey == 'varsity') {
      return const [
        _RatingItem(
            'Attendance & Commitment', 'Reports consistently to training.'),
        _RatingItem('Athletic Performance', 'Shows measurable skill progress.'),
        _RatingItem(
            'Teamwork', 'Cooperates with teammates and respects team roles.'),
        _RatingItem('Coachability', 'Accepts guidance and is open to correction.'),
        _RatingItem('Discipline', 'Follows team policies and routines.'),
        _RatingItem('Sportsmanship', 'Displays respect on and off the court.'),
        _RatingItem('Academic Balance',
            'Manages academic responsibilities alongside training.'),
      ];
    }

    return const [
      _RatingItem('Attendance',
          'Avoid absences and tardiness; provides notice of absence.'),
      _RatingItem(
          'Quantity of Work', 'Functions effectively within time or work schedule.'),
      _RatingItem('Quality of Work',
          'Work is resourceful, thorough, neat, accurate, and complete.'),
      _RatingItem('Communication Skills',
          'Follows instructions and seeks clarification when needed.'),
      _RatingItem('Attitude',
          'Accepts suggestions, responsibilities, and improves techniques.'),
      _RatingItem('Personality',
          'Shows effective interpersonal skills and proper grooming.'),
      _RatingItem('Other', 'Performs other tasks requested by the supervisor.'),
    ];
  }

  Map<String, int> _parseRatings() {
    final raw = evaluation['ratings_json'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(
            key.toString(),
            int.tryParse(value.toString()) ?? 0,
          ));
    }

    final text = (raw ?? '').toString().trim();
    if (text.isEmpty || text.startsWith('<')) return const {};

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(
              key.toString(),
              int.tryParse(value.toString()) ?? 0,
            ));
      }
    } catch (_) {
      // ignore
    }

    return const {};
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF6F5E7D)),
      hintStyle: const TextStyle(color: Color(0xFF6F5E7D)),
      filled: true,
      fillColor: const Color(0xFFF5F1F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _glassPanel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1D6EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2D0D44),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: _inputDecoration(label),
      style: const TextStyle(color: Color(0xFF2D0D44)),
    );
  }

  Widget _programChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF6A1B9A) : const Color(0xFFE9E0F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF6A1B9A) : const Color(0xFFD3C1E5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF4A148C),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _ratingHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text('Area',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 5,
            child: Text('Description',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 3,
            child: Text('Rating (5 to 1)',
                style: TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(_RatingItem item, int selected) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.title,
                style: const TextStyle(
                    color: Color(0xFF2D0D44), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 5,
            child: Text(item.description,
                style: const TextStyle(color: Color(0xFF6F5E7D))),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              children: List.generate(5, (index) {
                final rating = 5 - index;
                final isSelected = selected == rating;
                return Container(
                  width: 34,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6A1B9A)
                        : const Color(0xFFF2ECF7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6A1B9A)
                            : const Color(0xFFE1D6EB)),
                  ),
                  child: Text(
                    rating.toString(),
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF4A148C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreSummary(int total, double average) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Score: $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Average: ${average.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scholarName = (evaluation['scholar_name'] ?? '').toString().trim();
    final courseYear = (evaluation['course_year'] ?? '').toString().trim();
    final assignedArea = (evaluation['assigned_area'] ?? '').toString().trim();
    final supervisor = (evaluation['supervisor_name'] ?? '').toString().trim();
    final month = (evaluation['month_label'] ?? '').toString().trim();
    final recommendation = (evaluation['recommendation'] ?? '').toString().trim();
    final created = (evaluation['created_at'] ?? '').toString().trim();

    final ratings = _parseRatings();
    final items = _ratingItems();
    final computedTotal = items.fold<int>(0, (sum, item) {
      final v = ratings[item.title] ?? 0;
      return sum + (v > 0 ? v : 0);
    });
    final total = int.tryParse((evaluation['total_score'] ?? '').toString()) ??
        computedTotal;
    final average = double.tryParse((evaluation['average_score'] ?? '').toString()) ??
        (items.isEmpty ? 0 : total / items.length);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/jmcbg.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFF3B125A).withValues(alpha: 0.68)),
          ),
          SafeArea(
            child: Center(
              child: Container(
                width: 980,
                constraints: const BoxConstraints(maxWidth: 1100),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1F8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE1D6EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.visibility_rounded,
                              color: Color(0xFF4A148C)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scholar Evaluation (View)',
                                style: const TextStyle(
                                  color: Color(0xFF2D0D44),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                created.isEmpty
                                    ? 'Review your supervisor/coach ratings.'
                                    : 'Submitted: $created',
                                style: const TextStyle(color: Color(0xFF6F5E7D)),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onClose,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4A148C),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Close'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _programChip('Student Assistant', _programLabel == 'Student Assistant'),
                        const SizedBox(width: 10),
                        _programChip('Varsity', _programLabel == 'Varsity'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 980;

                            final detailsPanel = _glassPanel(
                              title: 'Scholar Details',
                              child: Column(
                                children: [
                                  _readOnlyField(
                                      'Scholar Name', scholarName.isEmpty ? '—' : scholarName),
                                  const SizedBox(height: 12),
                                  _readOnlyField('Course & Year Level',
                                      courseYear.isEmpty ? '—' : courseYear),
                                  const SizedBox(height: 12),
                                  if (_programLabel == 'Student Assistant')
                                    _readOnlyField('Assigned Area',
                                        assignedArea.isEmpty ? '—' : assignedArea),
                                  if (_programLabel == 'Student Assistant')
                                    const SizedBox(height: 12),
                                  _readOnlyField('Name of Supervisor',
                                      supervisor.isEmpty ? '—' : supervisor),
                                  const SizedBox(height: 12),
                                  _readOnlyField(
                                      'For the Month', month.isEmpty ? '—' : month),
                                ],
                              ),
                            );

                            final ratingsPanel = _glassPanel(
                              title: 'Performance Ratings',
                              child: Column(
                                children: [
                                  _ratingHeader(),
                                  const SizedBox(height: 8),
                                  ...items.map((item) => _ratingRow(
                                      item, ratings[item.title] ?? 0)),
                                  const SizedBox(height: 10),
                                  _glassPanel(
                                    title: 'Recommendation / Area of Improvement',
                                    child: TextFormField(
                                      initialValue:
                                          recommendation.isEmpty ? '—' : recommendation,
                                      readOnly: true,
                                      minLines: 4,
                                      maxLines: 6,
                                      decoration: _inputDecoration('Write notes...'),
                                      style: const TextStyle(color: Color(0xFF2D0D44)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _scoreSummary(total, average)),
                                    ],
                                  ),
                                ],
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  detailsPanel,
                                  const SizedBox(height: 16),
                                  ratingsPanel,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: detailsPanel),
                                const SizedBox(width: 16),
                                Expanded(flex: 7, child: ratingsPanel),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingItem {
  final String title;
  final String description;

  const _RatingItem(this.title, this.description);
}

