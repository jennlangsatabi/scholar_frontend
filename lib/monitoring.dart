import 'dart:async';

import 'package:flutter/material.dart';

import 'evaluation_form.dart';
import 'services/backend_api.dart';
import 'scholarship_types.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 8);
  static const int _maxRowEnrichmentPerRefresh = 20;
  String currentView = 'main';
  String selectedAreaTitle = '';
  String parentView = 'main';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _scholars = [];
  List<Map<String, dynamic>> _evaluations = [];
  bool _evaluationsLoading = false;
  String? _evaluationsError;
  String _evaluationProgram = 'student_assistant';
  String _submissionFilter = 'all'; // all | missing | pending | complete
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _poller;
  bool _scholarsRequestInFlight = false;
  String _gradeDueDate = '';
  String _renewalDueDate = '';

  Widget _editableCell({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D0D44),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2ECF8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE1D6EB)),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 14,
              color: Color(0xFF6A1B9A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String label) {
    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              letterSpacing: 0.2,
              color: Color(0xFF2D0D44),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableBodyCell(Widget child) {
    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackendApi.warmUp();
    _loadScholars();
    _poller = Timer.periodic(_pollInterval, (_) => _loadScholars(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadScholars(silent: true);
    }
  }

  Future<void> _loadScholars({bool silent = false}) async {
    if (_scholarsRequestInFlight) return;
    _scholarsRequestInFlight = true;
    try {
      if (!silent && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final payload = await BackendApi.getJson(
        'get_monitoring_summary.php',
        cacheTtl: const Duration(seconds: 1),
        retries: 1,
      );
      final baseData = (payload['scholars'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final shouldEnrich = parentView != 'main';
      final data = shouldEnrich
          ? await _hydrateLiveScholarData(
              baseData,
              maxEnrich: _maxRowEnrichmentPerRefresh,
            )
          : baseData;
      if (!mounted) return;
      setState(() {
        _scholars = data;
        _gradeDueDate = (payload['grade_due_date'] ?? '').toString();
        _renewalDueDate = (payload['renewal_due_date'] ?? '').toString();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    } finally {
      _scholarsRequestInFlight = false;
    }
  }

  Future<List<Map<String, dynamic>>> _hydrateLiveScholarData(
    List<Map<String, dynamic>> scholars,
    {int maxEnrich = _maxRowEnrichmentPerRefresh}
  ) async {
    final hydrated = scholars
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    final futures = <Future<void>>[];
    for (var i = 0; i < hydrated.length; i++) {
      if (futures.length >= maxEnrich) break;
      final scholar = hydrated[i];
      final userId = _userId(scholar);
      if (userId <= 0) continue;
      final category = _normalizedCategory(scholar);
      if (!_rowNeedsEnrichment(scholar, category)) continue;
      if (category == 'student_assistant') {
        futures.add(_enrichStudentAssistantRow(hydrated, i, userId));
      } else if (category == 'academic_scholar') {
        futures.add(_enrichAcademicRow(hydrated, i, userId));
      } else if (category == 'varsity') {
        futures.add(_enrichVarsityRow(hydrated, i, userId));
      } else if (category == 'gift_of_education') {
        futures.add(_enrichGiftRow(hydrated, i, userId));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    return hydrated;
  }

  bool _rowNeedsEnrichment(Map<String, dynamic> scholar, String category) {
    bool isMissing(dynamic value) {
      final s = (value ?? '').toString().trim();
      return s.isEmpty || s == '—' || s.toLowerCase() == 'unknown';
    }

    if (category == 'varsity') {
      return isMissing(scholar['sport_type']) ||
          isMissing(scholar['head_coach']) ||
          isMissing(scholar['training_schedule']) ||
          isMissing(scholar['game_schedule']);
    }
    if (category == 'student_assistant') {
      return isMissing(scholar['assigned_area']) ||
          isMissing(scholar['duty_hours']) ||
          isMissing(scholar['supervisor']);
    }
    if (category == 'academic_scholar') {
      return isMissing(scholar['academic_type']);
    }
    if (category == 'gift_of_education') {
      return isMissing(scholar['gift_type']);
    }

    return false;
  }

  Future<void> _enrichVarsityRow(
    List<Map<String, dynamic>> scholars,
    int index,
    int userId,
  ) async {
    try {
      final payload = await BackendApi.getJson(
        'get_scholar_profile.php',
        query: {'user_id': userId.toString()},
        cacheTtl: const Duration(minutes: 5),
        retries: 1,
      );
      final profile = Map<String, dynamic>.from(
        payload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final detailRows = (payload['detail_rows'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final detailRow =
          detailRows.isNotEmpty ? detailRows.first : <String, dynamic>{};

      scholars[index] = {
        ...scholars[index],
        if (_firstNonEmpty([profile['name']]).isNotEmpty)
          'name': profile['name'],
        if (_firstNonEmpty([profile['course']]).isNotEmpty)
          'course': profile['course'],
        if (_firstNonEmpty([profile['year_level']]).isNotEmpty)
          'year_level': profile['year_level'],
        if (_firstNonEmpty([profile['sport_type'], detailRow['Sport']])
            .isNotEmpty)
          'sport_type':
              _firstNonEmpty([profile['sport_type'], detailRow['Sport']]),
        if (_firstNonEmpty([profile['head_coach'], detailRow['Head Coach']])
            .isNotEmpty)
          'head_coach':
              _firstNonEmpty([profile['head_coach'], detailRow['Head Coach']]),
        if (_firstNonEmpty(
                [profile['training_schedule'], detailRow['Training Schedule']])
            .isNotEmpty)
          'training_schedule': _firstNonEmpty(
              [profile['training_schedule'], detailRow['Training Schedule']]),
        if (_firstNonEmpty(
            [profile['game_schedule'], detailRow['Game Schedule']]).isNotEmpty)
          'game_schedule': _firstNonEmpty(
              [profile['game_schedule'], detailRow['Game Schedule']]),
      };
    } catch (_) {
      // Keep summary row data if live enrichment fails for one scholar.
    }
  }

  Future<void> _enrichStudentAssistantRow(
    List<Map<String, dynamic>> scholars,
    int index,
    int userId,
  ) async {
    try {
      final existingDutyHours =
          (scholars[index]['duty_hours'] ?? '').toString();
      final existingParts = existingDutyHours.split('/');
      final existingRendered = existingParts.isNotEmpty ? existingParts[0] : '';
      final existingRequired = existingParts.length > 1 ? existingParts[1] : '';

      final results = await Future.wait([
        BackendApi.getJson(
          'get_scholar_profile.php',
          query: {'user_id': userId.toString()},
          cacheTtl: const Duration(minutes: 5),
          retries: 1,
        ),
        BackendApi.getJson(
          'get_sa_stats.php',
          query: {'user_id': userId.toString()},
          cacheTtl: const Duration(seconds: 30),
          retries: 1,
        ),
      ]);

      final profilePayload = results[0];
      final statsPayload = results[1];
      final profile = Map<String, dynamic>.from(
        profilePayload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final detailRows = (profilePayload['detail_rows'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final detailRow =
          detailRows.isNotEmpty ? detailRows.first : <String, dynamic>{};

      final renderedHours = _firstNonEmpty([
        statsPayload['rendered_hours'],
        statsPayload['rendered'],
        detailRow['Duty Hours'],
        existingRendered,
      ]);
      final requiredHours = _firstNonEmpty([
        scholars[index]['required_hours'],
        statsPayload['required_hours'],
        statsPayload['required'],
        detailRow['Required Hours'],
        existingRequired,
      ]);
      final supervisor = _firstNonEmpty([
        scholars[index]['supervisor'],
        profile['supervisor'],
        detailRow['Supervisor'],
      ]);
      final assignedArea = _firstNonEmpty([
        profile['assigned_area'],
        detailRow['Assign Area'],
        scholars[index]['assigned_area'],
      ]);

      scholars[index] = {
        ...scholars[index],
        if (_firstNonEmpty([profile['name']]).isNotEmpty)
          'name': profile['name'],
        if (_firstNonEmpty([profile['course']]).isNotEmpty)
          'course': profile['course'],
        if (_firstNonEmpty([profile['year_level']]).isNotEmpty)
          'year_level': profile['year_level'],
        if (assignedArea.isNotEmpty) 'assigned_area': assignedArea,
        if (supervisor.isNotEmpty) 'supervisor': supervisor,
        if (renderedHours.isNotEmpty || requiredHours.isNotEmpty)
          'duty_hours':
              '${_normalizeHoursNumber(renderedHours, fallback: '0')}/${_normalizeHoursNumber(requiredHours, fallback: '100')}',
      };
    } catch (_) {
      // Keep summary row data if live enrichment fails for one scholar.
    }
  }

  Future<void> _enrichGiftRow(
    List<Map<String, dynamic>> scholars,
    int index,
    int userId,
  ) async {
    try {
      final payload = await BackendApi.getJson(
        'get_scholar_profile.php',
        query: {'user_id': userId.toString()},
        cacheTtl: const Duration(minutes: 5),
        retries: 1,
      );
      final profile = Map<String, dynamic>.from(
        payload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final detailRows = (payload['detail_rows'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final detailRow =
          detailRows.isNotEmpty ? detailRows.first : <String, dynamic>{};

      scholars[index] = {
        ...scholars[index],
        if (_firstNonEmpty([profile['name']]).isNotEmpty)
          'name': profile['name'],
        if (_firstNonEmpty([profile['course']]).isNotEmpty)
          'course': profile['course'],
        if (_firstNonEmpty([profile['year_level']]).isNotEmpty)
          'year_level': profile['year_level'],
        if (_firstNonEmpty([
          profile['gift_type'],
          detailRow['Scholarship Type'],
        ]).isNotEmpty)
          'gift_type': _firstNonEmpty([
            profile['gift_type'],
            detailRow['Scholarship Type'],
          ]),
        if (_firstNonEmpty([
          profile['grant_coverage'],
          detailRow['Grant Coverage'],
        ]).isNotEmpty)
          'grant_coverage': _firstNonEmpty([
            profile['grant_coverage'],
            detailRow['Grant Coverage'],
          ]),
        if (_firstNonEmpty([
          profile['gpa'],
          detailRow['Retention GWA'],
          detailRow['GWA Req.'],
        ]).isNotEmpty)
          'gpa': _firstNonEmpty([
            profile['gpa'],
            detailRow['Retention GWA'],
            detailRow['GWA Req.'],
          ]),
        if (_firstNonEmpty([
          profile['status'],
          profile['scholarship_status'],
          detailRow['Renewal Status'],
          detailRow['Status'],
        ]).isNotEmpty)
          'scholarship_status': _firstNonEmpty([
            profile['status'],
            profile['scholarship_status'],
            detailRow['Renewal Status'],
            detailRow['Status'],
          ]),
      };
    } catch (_) {
      // Keep summary row data if live enrichment fails for one scholar.
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  String _normalizeHoursNumber(String raw, {required String fallback}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    final value = _parseHoursValue(trimmed);
    if (value == null) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC5B4E3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(),
          Expanded(child: _buildActiveContent()),
        ],
      ),
    );
  }

  void _showDutyHoursDialog({
    required int userId,
    required String name,
    required String
        renderedHours, // This will be the "300/400" string from your row
    required String remainingHours, // We will repurpose or ignore this
  }) {
    // 1. SPLIT LOGIC: If the string is "300/400", it splits into '300' and '400'
    List<String> parts = renderedHours.split('/');
    String currentRendered = parts.isNotEmpty ? parts[0] : '0';
    String currentRequired = parts.length > 1 ? parts[1] : '400';

    final TextEditingController renderedController =
        TextEditingController(text: currentRendered);
    final TextEditingController requiredController =
        TextEditingController(text: currentRequired);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Duty Hours: $name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: renderedController,
              decoration: const InputDecoration(
                labelText: "Hours Rendered (e.g., 300)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: requiredController,
              decoration: const InputDecoration(
                labelText: "Total Required Hours (e.g., 400)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A)),
            onPressed: () {
              // 2. SUBMIT: Send both rendered and required to the backend
              _submitDutyHoursUpdate(
                userId: userId,
                name: name,
                renderedRaw: renderedController.text,
                requiredRaw: requiredController.text, // Updated parameter name
              );
              Navigator.pop(context);
            },
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- EDIT DIALOG FOR SUPERVISOR ---
  void _showSupervisorDialog({
    required int userId,
    required String name,
    required String currentSupervisor,
  }) {
    final TextEditingController supervisorController =
        TextEditingController(text: currentSupervisor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Supervisor: $name"),
        content: TextField(
          controller: supervisorController,
          decoration: const InputDecoration(
            labelText: "Supervisor Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A)),
            onPressed: () async {
              try {
                await BackendApi.postForm('update_scholar_supervisor.php',
                    body: {
                      'user_id': userId.toString(),
                      'supervisor': supervisorController.text.trim(),
                    });
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar('Supervisor updated for $name.');
                _loadScholars(); // Refresh the table [cite: 27]
              } catch (e) {
                _showSnackBar('Update failed: $e');
              }
            },
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  int? _parseHoursValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('/');
    final first = parts.first.trim();
    return int.tryParse(first);
  }

  Future<void> _submitDutyHoursUpdate({
    required int userId,
    required String name,
    required String renderedRaw,
    required String requiredRaw,
  }) async {
    final rendered = _parseHoursValue(renderedRaw);
    final required = _parseHoursValue(requiredRaw);

    if (rendered == null || required == null) {
      _showSnackBar('Enter valid numbers.');
      return;
    }

    try {
      await BackendApi.postForm(
        'update_duty_hours.php',
        body: {
          'user_id': userId.toString(),
          'rendered_hours': rendered.toString(),
          'required_hours': required.toString(),
        },
      );

      if (!mounted) return;

      // REMOVE THIS LINE (Line 249 in your text)
      // Navigator.pop(context);

      _showSnackBar('Duty hours updated for $name to $rendered/$required.');
      _loadScholars(); // This is the correct refresh function name [cite: 252]
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Update failed: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildActiveContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    final hasQuery = searchQuery.trim().isNotEmpty;
    if (hasQuery && currentView != 'area_detail') {
      return _buildExpandedScholarTable(
        ignoreCategory: true,
        showDutyHoursColumn: false,
        titleOverride: 'Search Results',
        backTarget: 'main',
      );
    }

    switch (currentView) {
      case 'student_assistant':
        return _buildSubCategoryGrid('Assigned Area (SA)',
            _buildAreaItems('student_assistant'), 'student_assistant');
      case 'academic_scholar':
        return _buildSubCategoryGrid(
            'Academic (Type)', _buildTypeItems('academic'), 'academic_scholar');
      case 'varsity':
        return _buildSubCategoryGrid(
            'Varsity (Type)', _buildTypeItems('varsity'), 'varsity');
      case 'gift_of_education':
        return _buildSubCategoryGrid('Gift of Education (Type)',
            _buildTypeItems('gift_of_education'), 'gift_of_education');
      case 'evaluations':
        return _buildEvaluationsView();
      case 'area_detail':
        return _buildExpandedScholarTable();
      default:
        return _buildMainCategorySelection();
    }
  }

  // --- 1. MAIN CATEGORY SELECTION ---
  Widget _buildMainCategorySelection() {
    int countFor(String key) =>
        _scholars.where((s) => _normalizedCategory(s) == key).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100
              ? 3
              : width >= 700
                  ? 2
                  : 1;
          final childAspectRatio = crossAxisCount == 1
              ? 1.25
              : crossAxisCount == 2
                  ? 1.35
                  : 1.6;

          return GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 25,
            mainAxisSpacing: 25,
            childAspectRatio: childAspectRatio,
            children: [
              _buildBox('Student Assistant', const Color(0xFF43A047),
                  () => setState(() => currentView = 'student_assistant'),
                  count: countFor('student_assistant')),
              _buildBox('Academic Scholar', const Color(0xFFE6BE5A),
                  () => setState(() => currentView = 'academic_scholar'),
                  count: countFor('academic_scholar')),
              _buildBox('Varsity', const Color(0xFFB39DDB),
                  () => setState(() => currentView = 'varsity'),
                  count: countFor('varsity')),
              _buildBox('Gift of Education', const Color(0xFFD87474),
                  () => setState(() => currentView = 'gift_of_education'),
                  count: countFor('gift_of_education')),
              _buildBox(
                'Student Evaluations',
                const Color(0xFF6A1B9A),
                () {
                  setState(() => currentView = 'evaluations');
                  _loadEvaluations(program: _evaluationProgram);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadEvaluations({required String program}) async {
    setState(() {
      _evaluationProgram = program;
      _evaluationsLoading = true;
      _evaluationsError = null;
    });

    try {
      final payload = await BackendApi.getJson(
        'get_evaluations.php',
        query: {'program_type': program},
      );
      final raw = payload['data'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _evaluations = items;
        _evaluationsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _evaluationsError = e.toString();
        _evaluationsLoading = false;
      });
    }
  }

  Widget _buildEvaluationsView() {
    final hasData = _evaluations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton('main'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pageHorizontalPadding = width < 600 ? 16.0 : 40.0;
            final isNarrowHeader = width < 560;
            final titleFontSize = (width * 0.065).clamp(18.0, 28.0);

            final title = Text(
              'Student Evaluations',
              maxLines: isNarrowHeader ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D0D44),
              ),
            );

            final programChips = [
              ChoiceChip(
                label: const Text('Student Assistant'),
                selected: _evaluationProgram == 'student_assistant',
                onSelected: (selected) {
                  if (!selected) return;
                  _loadEvaluations(program: 'student_assistant');
                },
              ),
              ChoiceChip(
                label: const Text('Varsity'),
                selected: _evaluationProgram == 'varsity',
                onSelected: (selected) {
                  if (!selected) return;
                  _loadEvaluations(program: 'varsity');
                },
              ),
            ];

            final refreshButton = IconButton(
              tooltip: 'Refresh',
              onPressed: () => _loadEvaluations(program: _evaluationProgram),
              icon: const Icon(Icons.refresh),
            );

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: pageHorizontalPadding,
                vertical: 10,
              ),
              child: isNarrowHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 8),
                            refreshButton,
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              programChips[0],
                              const SizedBox(width: 8),
                              programChips[1],
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        Wrap(spacing: 8, children: programChips),
                        const SizedBox(width: 12),
                        refreshButton,
                      ],
                    ),
            );
          },
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pageHorizontalPadding = width < 600 ? 16.0 : 40.0;

              return Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: pageHorizontalPadding),
                child: _evaluationsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _evaluationsError != null
                        ? Center(child: Text(_evaluationsError!))
                        : !hasData
                            ? const Center(child: Text('No evaluations yet.'))
                            : Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth,
                                          ),
                                          child: DataTable(
                                            headingRowColor:
                                                WidgetStateProperty.all(
                                              const Color(0xFFF8F5FB),
                                            ),
                                            columnSpacing: 24,
                                            headingRowHeight: 64,
                                            dataRowHeight: 62,
                                            columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Student',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Course/Year',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Month',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            numeric: true,
                                            label: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'Average',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Recommendation',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Submitted',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Action',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: _evaluations.map((e) {
                                          final evaluationId = int.tryParse(
                                                (e['evaluation_id'] ?? '')
                                                    .toString(),
                                              ) ??
                                              0;
                                          final name = (e['scholar_name'] ??
                                                  e['name'] ??
                                                  '')
                                              .toString()
                                              .trim();
                                          final courseYear =
                                              (e['course_year'] ?? '')
                                                  .toString()
                                                  .trim();
                                          final month = (e['month_label'] ?? '')
                                              .toString()
                                              .trim();
                                          final avg = (e['average_score'] ?? '')
                                              .toString()
                                              .trim();
                                          final rec = (e['recommendation'] ?? '')
                                              .toString()
                                              .trim();
                                          final created =
                                              (e['created_at'] ?? '')
                                                  .toString()
                                                  .trim();

                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                  name.isEmpty ? '—' : name)),
                                              DataCell(Text(courseYear.isEmpty
                                                  ? '—'
                                                  : courseYear)),
                                              DataCell(Text(
                                                  month.isEmpty ? '—' : month)),
                                              DataCell(
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    avg.isEmpty ? '—' : avg,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(
                                                    maxWidth: 320,
                                                  ),
                                                  child: Text(
                                                    rec.isEmpty ? '—' : rec,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(created.isEmpty
                                                  ? '—'
                                                  : created)),
                                              DataCell(
                                                IconButton(
                                                  tooltip: 'View evaluation',
                                                  icon: const Icon(
                                                    Icons.visibility_rounded,
                                                    color: Color(0xFF6A1B9A),
                                                  ),
                                                  onPressed: evaluationId <= 0
                                                      ? null
                                                      : () =>
                                                          _showEvaluationDetailsDialog(
                                                            evaluationId:
                                                                evaluationId,
                                                          ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEvaluationDetailsDialog({
    required int evaluationId,
  }) async {
    try {
      final payload = await BackendApi.getJson(
        'get_evaluation.php',
        query: {'evaluation_id': evaluationId.toString()},
      );
      final evaluation = Map<String, dynamic>.from(
        payload['evaluation'] as Map? ?? const <String, dynamic>{},
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: EvaluationRecordScreen(
              evaluation: evaluation,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unable to load evaluation details: $e');
    }
  }

  // --- 2. REUSABLE SUB-CATEGORY GRID ---
  Widget _buildSubCategoryGrid(
      String title, List<Map<String, dynamic>> items, String from) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton('main'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D0D44))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1100
                    ? 3
                    : width >= 700
                        ? 2
                        : 1;
                final childAspectRatio = crossAxisCount == 1
                    ? 1.15
                    : crossAxisCount == 2
                        ? 1.25
                        : 1.6;

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 25,
                    mainAxisSpacing: 25,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildBox(
                      items[index]['title'],
                      items[index]['color'],
                      () => _openArea(items[index]['title'], from),
                      count: items[index]['count'] is int
                          ? items[index]['count'] as int
                          : null,
                      previewLines: items[index]['previewLines'] is List<String>
                          ? items[index]['previewLines'] as List<String>
                          : null),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. FORMAL TABLE VIEW ---
  Widget _buildExpandedScholarTable({
    bool ignoreCategory = false,
    bool showDutyHoursColumn = false,
    String? titleOverride,
    String? backTarget,
  }) {
    final filtered = _filterScholars(ignoreCategory: ignoreCategory);
    // Determine if we should show the Duty Hours column
    final showDutyHours = showDutyHoursColumn ||
        (!ignoreCategory && parentView == 'student_assistant') ||
        (ignoreCategory &&
            filtered.isNotEmpty &&
            filtered
                .every((s) => _normalizedCategory(s) == 'student_assistant'));
    final showVarsityDetails = (!ignoreCategory && parentView == 'varsity') ||
        (ignoreCategory &&
            filtered.isNotEmpty &&
            filtered.every((s) => _normalizedCategory(s) == 'varsity'));
    final showAcademicDetails = (!ignoreCategory &&
            parentView == 'academic_scholar') ||
        (ignoreCategory &&
            filtered.isNotEmpty &&
            filtered
                .every((s) => _normalizedCategory(s) == 'academic_scholar'));
    final showGiftDetails = (!ignoreCategory &&
            parentView == 'gift_of_education') ||
        (ignoreCategory &&
            filtered.isNotEmpty &&
            filtered
                .every((s) => _normalizedCategory(s) == 'gift_of_education'));
    final scholarRows = filtered
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final s = entry.value;
          return _scholarRow(
            index,
            _fullName(s),
            _courseYear(s),
            _latestSubmission(s),
            _gradeStatus(s),
            _renewalStatus(s),
            _remarksStatus(s),
            showDutyHours,
            _normalizedCategory(s) == 'student_assistant',
            false,
            _userId(s),
            _renderedHours(s),
            _remainingHours(s),
            (s['supervisor'] ?? '—').toString(),
            (s['sport_type'] ?? '—').toString(),
            (s['head_coach'] ?? '—').toString(),
            (s['training_schedule'] ?? '—').toString(),
            (s['game_schedule'] ?? '—').toString(),
          );
        })
        .toList();

    final categorySummary = ignoreCategory ? _categorySummary(filtered) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 40.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildBackButton(backTarget ?? parentView),
          ),
          const SizedBox(height: 6),
          if (titleOverride != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  titleOverride,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D0D44)),
                ),
              ),
            ),
          if (categorySummary != null && categorySummary.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  categorySummary,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A148C)),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Show:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D0D44),
                    ),
                  ),
                  _statusChip('All', 'all'),
                  _statusChip('Missing', 'missing'),
                  _statusChip('Pending', 'pending'),
                  _statusChip('Complete', 'complete'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(
                        builder: (context, tableConstraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: tableConstraints.maxWidth,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF7F3FC),
                                ),
                                dividerThickness: 0.8,
                                horizontalMargin: 20,
                                headingRowHeight: 66,
                                dataRowMinHeight: 64,
                                dataRowMaxHeight: 70,
                                columnSpacing: 30,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF2D0D44),
                                ),
                                dataTextStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D0D44),
                                ),
                                columns: [
                                  const DataColumn(
                                    label: Text(
                                      'Scholar Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Course/Year',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Due Date',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        IconButton(
                                          tooltip: 'Edit Due Dates',
                                          icon: const Icon(
                                            Icons.edit_calendar,
                                            size: 18,
                                            color: Color(0xFF6A1B9A),
                                          ),
                                          onPressed: _showDueDateDialog,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (showDutyHours) ...[
                                    const DataColumn(
                                      label: Text(
                                        'Supervisor',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const DataColumn(
                                      label: Text(
                                        'Duty Hours',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const DataColumn(
                                    label: Text(
                                      'Grades',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Renewal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Remarks',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: scholarRows,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ),
                if (showVarsityDetails) ...[
                  const SizedBox(height: 18),
                  _buildVarsityDetailsTable(filtered),
                ],
                if (showAcademicDetails) ...[
                  const SizedBox(height: 18),
                  _buildAcademicDetailsTable(filtered),
                ],
                if (showGiftDetails) ...[
                  const SizedBox(height: 18),
                  _buildGiftDetailsTable(filtered),
                ],
              ],
            ),
          ),
        ],
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = _submissionFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 13.5),
      ),
      selected: selected,
      onSelected: (_) {
        if (!mounted) return;
        setState(() => _submissionFilter = value);
      },
      selectedColor: const Color(0xFF6A1B9A).withOpacity(0.16),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? const Color(0xFF4A148C) : const Color(0xFF2D0D44),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(
        color: selected ? const Color(0xFFBFA6D9) : const Color(0xFFE1D6EB),
      ),
    );
  }

  Future<void> _showDueDateDialog() async {
    String gradeDate = _gradeDueDate;
    String renewalDate = _renewalDueDate;
    final gradeController = TextEditingController(text: gradeDate);
    final renewalController = TextEditingController(text: renewalDate);

    Future<void> pickDate(TextEditingController controller) async {
      final initial =
          DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      controller.text = '$y-$m-$d';
    }

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Requirement Due Dates'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: gradeController,
                readOnly: true,
                onTap: () => pickDate(gradeController),
                decoration: const InputDecoration(
                  labelText: 'Report of Grades Due Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: renewalController,
                readOnly: true,
                onTap: () => pickDate(renewalController),
                decoration: const InputDecoration(
                  labelText: 'Renewal Letter Due Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
            ],
          ),
        ),
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

    if (saved != true || !mounted) return;

    gradeDate = gradeController.text.trim();
    renewalDate = renewalController.text.trim();
    if (gradeDate.isEmpty || renewalDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both due dates.')),
      );
      return;
    }

    try {
      await BackendApi.postJson(
        'update_requirements_due_dates.php',
        body: {
          'grade_due_date': gradeDate,
          'renewal_due_date': renewalDate,
        },
      );
      await _loadScholars();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due dates updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update due dates: $e')),
      );
    }
  }

  Future<void> _enrichAcademicRow(
    List<Map<String, dynamic>> scholars,
    int index,
    int userId,
  ) async {
    try {
      final payload = await BackendApi.getJson(
        'get_scholar_profile.php',
        query: {'user_id': userId.toString()},
        cacheTtl: const Duration(minutes: 5),
        retries: 1,
      );
      final profile = Map<String, dynamic>.from(
        payload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final detailRows = (payload['detail_rows'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final detailRow =
          detailRows.isNotEmpty ? detailRows.first : <String, dynamic>{};

      scholars[index] = {
        ...scholars[index],
        if (_firstNonEmpty([profile['name']]).isNotEmpty)
          'name': profile['name'],
        if (_firstNonEmpty([profile['course']]).isNotEmpty)
          'course': profile['course'],
        if (_firstNonEmpty([profile['year_level']]).isNotEmpty)
          'year_level': profile['year_level'],
        if (_firstNonEmpty(
                [profile['academic_type'], detailRow['Scholarship Type']])
            .isNotEmpty)
          'academic_type': _firstNonEmpty(
              [profile['academic_type'], detailRow['Scholarship Type']]),
        if (_firstNonEmpty([profile['academic_benefit'], detailRow['Benefit']])
            .isNotEmpty)
          'academic_benefit': _firstNonEmpty(
              [profile['academic_benefit'], detailRow['Benefit']]),
        if (_firstNonEmpty(
                [profile['academic_gwa_requirement'], detailRow['GWA Req.']])
            .isNotEmpty)
          'academic_gwa_requirement': _firstNonEmpty(
              [profile['academic_gwa_requirement'], detailRow['GWA Req.']]),
        if (_firstNonEmpty(
                [profile['monthly_stipend'], detailRow['Monthly Stipend']])
            .isNotEmpty)
          'monthly_stipend': _firstNonEmpty(
              [profile['monthly_stipend'], detailRow['Monthly Stipend']]),
      };
    } catch (_) {
      // Keep summary row data if live enrichment fails for one scholar.
    }
  }

  void _showVarsityDetailsDialog({
    required int userId,
    required String name,
    required String sport,
    required String currentHeadCoach,
    required String currentTrainingSchedule,
    required String currentGameSchedule,
  }) {
    final headCoachController = TextEditingController(
      text: currentHeadCoach == '—' ? '' : currentHeadCoach,
    );
    final trainingScheduleController = TextEditingController(
      text: currentTrainingSchedule == '—' ? '' : currentTrainingSchedule,
    );
    final gameScheduleController = TextEditingController(
      text: currentGameSchedule == '—' ? '' : currentGameSchedule,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Varsity Details: $name'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sport: ${sport.isEmpty ? '—' : sport}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headCoachController,
                decoration: const InputDecoration(
                  labelText: 'Head Coach',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trainingScheduleController,
                decoration: const InputDecoration(
                  labelText: 'Training Schedule',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gameScheduleController,
                decoration: const InputDecoration(
                  labelText: 'Game Schedule',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            onPressed: () async {
              try {
                await BackendApi.postForm(
                  'update_varsity_details.php',
                  body: {
                    'user_id': userId.toString(),
                    'head_coach': headCoachController.text.trim(),
                    'training_schedule': trainingScheduleController.text.trim(),
                    'game_schedule': gameScheduleController.text.trim(),
                  },
                );
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar('Varsity details updated for $name.');
                _loadScholars();
              } catch (e) {
                if (!mounted) return;
                _showSnackBar('Update failed: $e');
              }
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVarsityDetailsTable(List<Map<String, dynamic>> scholars) {
    final rows = scholars.map((s) {
      final userId = _userId(s);
      final name = _fullName(s);
      final headCoach = (s['head_coach'] ?? '—').toString();
      final trainingSchedule = (s['training_schedule'] ?? '—').toString();
      final gameSchedule = (s['game_schedule'] ?? '—').toString();
      final sportType = (s['sport_type'] ?? '—').toString();

      return TableRow(
        children: [
          _tableBodyCell(
            Text(
              sportType,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            _editableCell(
              text: headCoach,
              onPressed: userId <= 0
                  ? null
                  : () => _showVarsityDetailsDialog(
                        userId: userId,
                        name: name,
                        sport: (s['sport_type'] ?? '').toString(),
                        currentHeadCoach: headCoach,
                        currentTrainingSchedule: trainingSchedule,
                        currentGameSchedule: gameSchedule,
                      ),
            ),
          ),
          _tableBodyCell(
            Text(
              trainingSchedule,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            Text(
              gameSchedule,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.0),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(2.2),
                    3: FlexColumnWidth(2.4),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: Color(0xFFE6DFF0),
                      width: 1,
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: Color(0xFFF8F5FB)),
                      children: [
                        _tableHeaderCell('Sport'),
                        _tableHeaderCell('Head Coach'),
                        _tableHeaderCell('Training Schedule'),
                        _tableHeaderCell('Game Schedule'),
                      ],
                    ),
                    ...rows,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAcademicDetailsDialog({
    required int userId,
    required String name,
    required String scholarshipType,
    required String currentBenefit,
    required String currentGwaRequirement,
    required String currentMonthlyStipend,
  }) {
    final academicTypeOptions = const ['—', 'Type A', 'Type B', 'Type C'];
    final currentTypePayload = _academicTypePayload(scholarshipType);
    final currentTypeLabel = currentTypePayload.isEmpty
        ? '—'
        : _academicTypeLabel(currentTypePayload);
    String selectedAcademicType = academicTypeOptions.contains(currentTypeLabel)
        ? currentTypeLabel
        : academicTypeOptions.first;

    final benefitController = TextEditingController(
      text: currentBenefit == '—' ? '' : currentBenefit,
    );
    final gwaController = TextEditingController(
      text: currentGwaRequirement == '—' ? '' : currentGwaRequirement,
    );
    final stipendController = TextEditingController(
      text: _stripCurrency(currentMonthlyStipend),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Academic Details: $name'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedAcademicType,
                items: academicTypeOptions
                    .map(
                      (label) =>
                          DropdownMenuItem(value: label, child: Text(label)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  selectedAcademicType = value;
                },
                decoration: const InputDecoration(
                  labelText: 'Scholarship Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: benefitController,
                decoration: const InputDecoration(
                  labelText: 'Benefit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gwaController,
                decoration: const InputDecoration(
                  labelText: 'GWA Req.',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stipendController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Stipend',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            onPressed: () async {
              try {
                await BackendApi.postForm(
                  'update_academic_details.php',
                  body: {
                    'user_id': userId.toString(),
                    'academic_type': _academicTypePayload(selectedAcademicType),
                    'academic_benefit': benefitController.text.trim(),
                    'academic_gwa_requirement': gwaController.text.trim(),
                    'monthly_stipend': stipendController.text.trim(),
                  },
                );
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar('Academic details updated for $name.');
                _loadScholars();
              } catch (e) {
                if (!mounted) return;
                _showSnackBar('Update failed: $e');
              }
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicDetailsTable(List<Map<String, dynamic>> scholars) {
    final rows = scholars.map((s) {
      final userId = _userId(s);
      final name = _fullName(s);
      final scholarshipType = _academicTypeLabel(s['academic_type']);
      final benefit = (s['academic_benefit'] ?? '—').toString();
      final gwaRequirement =
          (s['academic_gwa_requirement'] ?? 'N/A').toString();
      final monthlyStipend = _formatMonthlyStipend(s['monthly_stipend']);

      return TableRow(
        children: [
          _tableBodyCell(
            Text(
              scholarshipType.isEmpty ? '—' : scholarshipType,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            _editableCell(
              text: benefit,
              onPressed: userId <= 0
                  ? null
                  : () => _showAcademicDetailsDialog(
                        userId: userId,
                        name: name,
                        scholarshipType: scholarshipType,
                        currentBenefit: benefit,
                        currentGwaRequirement: gwaRequirement,
                        currentMonthlyStipend: monthlyStipend,
                      ),
            ),
          ),
          _tableBodyCell(
            Text(
              gwaRequirement,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            Text(
              monthlyStipend,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth < 720 ? 720 : constraints.maxWidth,
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(2.2),
                    2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(1.2),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: Color(0xFFE6DFF0),
                      width: 1,
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: Color(0xFFF8F5FB)),
                      children: [
                        _tableHeaderCell('Scholarship Type'),
                        _tableHeaderCell('Benefit'),
                        _tableHeaderCell('GWA Req.'),
                        _tableHeaderCell('Monthly Stipend'),
                      ],
                    ),
                    ...rows,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showGiftDetailsDialog({
    required int userId,
    required String name,
    required String currentGiftType,
    required String currentGrantCoverage,
    required String currentRetentionGwa,
    required String currentRenewalStatus,
  }) {
    final coverageController = TextEditingController(
      text: currentGrantCoverage == '—' ? '' : currentGrantCoverage,
    );
    final gwaController = TextEditingController(
      text: currentRetentionGwa == '—' ? '' : currentRetentionGwa,
    );
    String selectedGiftType =
        ScholarshipTypes.giftTypeLabels.contains(currentGiftType)
            ? currentGiftType
            : ScholarshipTypes.giftTypeLabels.first;

    final renewalOptions = const ['Approved', 'Under Verification', 'Pending', 'Terminated'];
    final currentRenewalLabel = _giftRenewalLabel(currentRenewalStatus);
    String selectedRenewalStatus = renewalOptions.contains(currentRenewalLabel)
        ? currentRenewalLabel
        : renewalOptions.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Gift of Education Details: $name'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedGiftType,
                  items: ScholarshipTypes.giftTypeLabels
                      .map(
                        (label) =>
                            DropdownMenuItem(value: label, child: Text(label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    selectedGiftType = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Scholarship Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coverageController,
                  decoration: const InputDecoration(
                    labelText: 'Grant Coverage',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gwaController,
                  decoration: const InputDecoration(
                    labelText: 'Retention GWA',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRenewalStatus,
                  items: renewalOptions
                      .map(
                        (label) =>
                            DropdownMenuItem(value: label, child: Text(label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    selectedRenewalStatus = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Renewal Status',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            onPressed: () async {
              try {
                final giftPayload =
                    ScholarshipTypes.giftTypePayload(selectedGiftType);
                final coverage = coverageController.text.trim();
                final gwa = gwaController.text.trim();
                final renewal = _giftRenewalPayload(selectedRenewalStatus);
                final response = await BackendApi.postForm(
                  'update_giftofeducation_details.php',
                  body: {
                    'user_id': userId.toString(),
                    'gift_type': giftPayload,
                    'grant_coverage': coverage,
                    'retention_gwa': gwa,
                    'scholarship_status': renewal,
                  },
                );
                if ((response['status'] ?? '').toString().toLowerCase() !=
                    'success') {
                  throw Exception((response['message'] ?? 'Update failed')
                      .toString()
                      .trim());
                }
                if (!mounted) return;
                setState(() {
                  _scholars = _scholars.map((scholar) {
                    if (_userId(scholar) != userId) return scholar;
                    return {
                      ...scholar,
                      'gift_type': giftPayload,
                      'grant_coverage': coverage,
                      'retention_gwa': gwa,
                      'scholarship_status': renewal,
                      'status': renewal,
                    };
                  }).toList();
                });
                Navigator.pop(context);
                _showSnackBar('Gift of Education details updated for $name.');
                _loadScholars();
              } catch (e) {
                if (!mounted) return;
                _showSnackBar('Update failed: $e');
              }
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftDetailsTable(List<Map<String, dynamic>> scholars) {
    final rows = scholars.map((s) {
      final userId = _userId(s);
      final name = _fullName(s);
      final scholarshipType = _giftTypeLabel(s['gift_type']);
      final grantCoverage = _giftGrantCoverage(s);
      final retentionGwa = _giftRetentionGwa(s);
      final renewalStatus = _giftRenewalStatus(s);

      return TableRow(
        children: [
          _tableBodyCell(
            Text(
              scholarshipType.isEmpty ? '—' : scholarshipType,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            _editableCell(
              text: grantCoverage,
              onPressed: userId <= 0
                  ? null
                  : () => _showGiftDetailsDialog(
                        userId: userId,
                        name: name,
                        currentGiftType:
                            scholarshipType.isEmpty ? '—' : scholarshipType,
                        currentGrantCoverage: grantCoverage,
                        currentRetentionGwa: retentionGwa,
                        currentRenewalStatus: renewalStatus,
                      ),
            ),
          ),
          _tableBodyCell(
            Text(
              retentionGwa,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _tableBodyCell(
            Text(
              renewalStatus,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth < 720 ? 720 : constraints.maxWidth,
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.3),
                    1: FlexColumnWidth(2.1),
                    2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(1.2),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: Color(0xFFE6DFF0),
                      width: 1,
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: Color(0xFFF8F5FB)),
                      children: [
                        _tableHeaderCell('Scholarship Type'),
                        _tableHeaderCell('Grant Coverage'),
                        _tableHeaderCell('Retention GWA'),
                        _tableHeaderCell('Renewal Status'),
                      ],
                    ),
                    ...rows,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _categorySummary(List<Map<String, dynamic>> scholars) {
    final categories = <String>{};
    for (final s in scholars) {
      categories.add(_categoryLabel(_normalizedCategory(s)));
    }
    if (categories.isEmpty) return '';
    final list = categories.toList()..sort();
    return 'Categories: ${list.join(', ')}';
  }

  String _categoryLabel(String normalized) {
    switch (normalized) {
      case 'student_assistant':
        return 'Student Assistant';
      case 'academic_scholar':
        return 'Academic Scholar';
      case 'varsity':
        return 'Varsity';
      case 'gift_of_education':
        return 'Gift of Education';
      default:
        return 'Student Assistant';
    }
  }

  // --- STYLING HELPERS ---

  IconData _boxIconForTitle(String title) {
    final key = title.toLowerCase();
    if (key.contains('student assistant')) return Icons.badge_outlined;
    if (key.contains('academic')) return Icons.school_outlined;
    if (key.contains('varsity')) return Icons.sports_basketball_outlined;
    if (key.contains('gift of education')) return Icons.volunteer_activism;
    if (key.contains('evaluation')) return Icons.assignment_turned_in_outlined;
    if (key.contains('area')) return Icons.apartment_outlined;
    if (key.contains('type')) return Icons.grid_view_outlined;
    return Icons.category_outlined;
  }

  Color _shiftLightness(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0))
        .toColor();
  }

  void _openArea(String title, String fromView) {
    setState(() {
      selectedAreaTitle = title;
      parentView = fromView;
      currentView = 'area_detail';
    });
  }

  Widget _buildBox(
    String title,
    Color color,
    VoidCallback onTap, {
    int? count,
    List<String>? previewLines,
  }) {
    final icon = _boxIconForTitle(title);
    final isLightBg =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final foregroundColor = isLightBg ? const Color(0xFF2D0D44) : Colors.white;
    final surfaceOverlay =
        isLightBg ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.16);
    final surfaceBorder =
        isLightBg ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.18);

    final gradientStart = _shiftLightness(color, isLightBg ? -0.02 : 0.08);
    final gradientEnd = _shiftLightness(color, isLightBg ? -0.14 : -0.08);

    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -18,
                child: Opacity(
                  opacity: 0.14,
                  child: Icon(icon, size: 140, color: foregroundColor),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 180;
                  final showChevron = constraints.maxWidth >= 96;
                  final horizontalPadding = isCompact ? 14.0 : 22.0;
                  final verticalPadding = isCompact ? 14.0 : 20.0;
                  final iconPadding = isCompact ? 7.0 : 10.0;
                  final iconSize = isCompact ? 18.0 : 22.0;
                  final titleSize = isCompact ? 16.0 : 20.0;
                  final previewCount = constraints.maxWidth < 260 ? 1 : 2;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(iconPadding),
                              decoration: BoxDecoration(
                                color: surfaceOverlay,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: surfaceBorder,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: foregroundColor,
                                size: iconSize,
                              ),
                            ),
                            if (showChevron) ...[
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: foregroundColor.withOpacity(0.85),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: surfaceOverlay,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: surfaceBorder,
                              ),
                            ),
                            child: Text(
                              '$count scholar${count == 1 ? '' : 's'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (previewLines != null && previewLines.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...previewLines.take(previewCount).map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: foregroundColor.withOpacity(0.78),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    String title = "MONITORING";
    if (currentView == 'area_detail') title = selectedAreaTitle.toUpperCase();

    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D0D44),
        letterSpacing: 1.2,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _searchBar(),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              _searchBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackButton(String target) {
    return Padding(
      padding: const EdgeInsets.only(left: 0),
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            currentView = target;
            if (target == 'main') {
              searchQuery = '';
              _searchController.clear();
            }
          });
        },
        icon: const Icon(Icons.arrow_back, color: Color(0xFF4A148C)),
        label: const Text('Back',
            style: TextStyle(
                color: Color(0xFF4A148C), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _searchBar() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _setSearchQuery,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Search scholar',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => _setSearchQuery(''),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  DataRow _scholarRow(
      int rowIndex,
      String name,
      String cy,
      String date,
      String grade,
      String renewal,
      String remarks,
      bool showDutyHours,
      bool isRowSA,
      bool isRowVarsity,
      int userId,
      String rendered,
      String remaining,
      String supervisor,
      String sport,
      String headCoach,
      String trainingSchedule,
      String gameSchedule) {
    final remarksKey = remarks.toLowerCase();
    bool isUrgent = remarksKey.contains('not complete') ||
        remarksKey.contains('missing') ||
        remarksKey.contains('pending') ||
        remarksKey.contains('notify');

    final zebra = rowIndex.isEven ? Colors.white : const Color(0xFFFCFAFF);
    return DataRow(
      color: WidgetStateProperty.all(zebra),
      cells: [
      DataCell(
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D0D44),
          ),
        ),
      ),
      DataCell(
        Text(
          cy,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      DataCell(
        Text(
          date,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Supervisor and Duty Hours logic
      if (showDutyHours) ...[
        // Supervisor Cell with Edit Icon
        DataCell(
          isRowSA
              ? Row(
                  children: [
                    Text(
                      supervisor,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                      onPressed: userId <= 0
                          ? null
                          : () => _showSupervisorDialog(
                                userId: userId,
                                name: name,
                                currentSupervisor: supervisor,
                              ),
                    )
                  ],
                )
              : const Text('-'),
        ),
        // Duty Hours Cell (Existing) [cite: 126-132]
        DataCell(
          isRowSA
              ? Row(
                  children: [
                    Text(
                      // Just use the string directly. If null, show '0/400'
                      rendered.toString().isEmpty
                          ? '0/400'
                          : rendered.toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A148C)),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                      onPressed: userId <= 0
                          ? null
                          : () => _showDutyHoursDialog(
                                userId: userId,
                                name: name,
                                // Pass the string as is
                                renderedHours: rendered.toString(),
                                remainingHours: "", // Keep as empty string
                              ),
                    ),
                  ],
                )
              : const Text('—'),
        ),
      ],
      if (isRowVarsity) ...[
        DataCell(Text(sport, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(headCoach, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(trainingSchedule, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(gameSchedule, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
      DataCell(_statusPill(grade, kind: 'grade')),
      DataCell(_statusPill(renewal, kind: 'renewal')),
      DataCell(
        _statusPill(remarks, kind: isUrgent ? 'bad' : 'good'),
      ),
    ]);
  }

  Widget _statusPill(String value, {required String kind}) {
    final text = value.trim().isEmpty ? '—' : value.trim();
    Color fg = const Color(0xFF2D0D44);
    Color bg = const Color(0xFFF2ECF8);
    Color border = const Color(0xFFE1D6EB);

    final lower = text.toLowerCase();
    if (kind == 'bad' || lower.contains('missing') || lower.contains('reject')) {
      fg = const Color(0xFFB71C1C);
      bg = const Color(0xFFFFEBEE);
      border = const Color(0xFFFFCDD2);
    } else if (kind == 'good' || lower.contains('complete') || lower.contains('approved') || lower.contains('passed')) {
      fg = const Color(0xFF1B5E20);
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFFC8E6C9);
    } else if (lower.contains('pending') || lower.contains('verify')) {
      fg = const Color(0xFFEF6C00);
      bg = const Color(0xFFFFF3E0);
      border = const Color(0xFFFFCC80);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterScholars({bool ignoreCategory = false}) {
    final cat = parentView;
    final area = selectedAreaTitle;
    final query = searchQuery.trim().toLowerCase();
    final hasCategoryFilter = !ignoreCategory &&
        (cat == 'student_assistant' ||
            cat == 'academic_scholar' ||
            cat == 'varsity' ||
            cat == 'gift_of_education');

    return _scholars.where((s) {
      if (query.isNotEmpty) {
        final name = _fullName(s).toLowerCase();
        final username = (s['username'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        final course = (s['course'] ?? '').toString().toLowerCase();
        final categoryRaw = (s['scholarship_category'] ?? s['category'] ?? '')
            .toString()
            .toLowerCase();
        final categoryNorm = _normalizedCategory(s).toLowerCase();
        final assigned = (s['assigned_area'] ?? '').toString().toLowerCase();
        final academicType =
            _academicTypeLabel(s['academic_type']).toLowerCase();
        final academicBenefit =
            (s['academic_benefit'] ?? '').toString().toLowerCase();
        final gwaRequirement =
            (s['academic_gwa_requirement'] ?? '').toString().toLowerCase();
        final monthlyStipend =
            _formatMonthlyStipend(s['monthly_stipend']).toLowerCase();
        final sportType = (s['sport_type'] ?? '').toString().toLowerCase();
        final headCoach = (s['head_coach'] ?? '').toString().toLowerCase();
        final trainingSchedule =
            (s['training_schedule'] ?? '').toString().toLowerCase();
        final gameSchedule =
            (s['game_schedule'] ?? '').toString().toLowerCase();
        final giftType = _giftTypeLabel(s['gift_type']).toLowerCase();
        final categoryAliases = [
          categoryRaw,
          categoryNorm,
          if (categoryNorm == 'student_assistant') 'sa',
          if (categoryNorm == 'academic_scholar') 'academic',
          if (categoryNorm == 'varsity') 'varsity',
          if (categoryNorm == 'gift_of_education') 'gift',
          if (categoryNorm == 'gift_of_education') 'gift of education',
          if (categoryNorm == 'student_assistant') 'student assistant',
          if (categoryNorm == 'academic_scholar') 'academic scholar',
        ];

        if (!name.contains(query) &&
            !username.contains(query) &&
            !email.contains(query) &&
            !course.contains(query) &&
            !assigned.contains(query) &&
            !academicType.contains(query) &&
            !academicBenefit.contains(query) &&
            !gwaRequirement.contains(query) &&
            !monthlyStipend.contains(query) &&
            !sportType.contains(query) &&
            !headCoach.contains(query) &&
            !trainingSchedule.contains(query) &&
            !gameSchedule.contains(query) &&
            !giftType.contains(query) &&
            !categoryAliases.any((c) => c.contains(query))) {
          return false;
        }
      }

      if (hasCategoryFilter) {
        final category = _normalizedCategory(s);
        final inCategory = category == cat;
        if (!inCategory) return false;
      }

      if (hasCategoryFilter && cat == 'student_assistant') {
        final assigned = (s['assigned_area'] ?? '').toString().trim();
        if (area.isEmpty) return true;
        return assigned.toLowerCase() == area.toLowerCase();
      }

      if (hasCategoryFilter && cat == 'academic_scholar') {
        final type = _academicTypeLabel(s['academic_type']);
        if (area.isEmpty) return true;
        return type.toLowerCase() == area.toLowerCase();
      }

      if (hasCategoryFilter && cat == 'varsity') {
        final type = (s['sport_type'] ?? '').toString().trim();
        if (area.isEmpty) return true;
        return type.toLowerCase() == area.toLowerCase();
      }

      if (hasCategoryFilter && cat == 'gift_of_education') {
        final type = _normalizedGiftType(s['gift_type']);
        if (area.isEmpty) return true;
        return type == _normalizedGiftType(area);
      }

      if (_submissionFilter != 'all' &&
          (currentView == 'area_detail' || ignoreCategory)) {
        return _submissionBucket(s) == _submissionFilter;
      }

      return true;
    }).toList();
  }

  void _setSearchQuery(String value) {
    if (!mounted) return;
    setState(() {
      searchQuery = value;
    });
    if (_searchController.text != value) {
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  String _stripCurrency(String raw) {
    return raw.replaceAll('PHP', '').replaceAll(',', '').trim();
  }

  String _formatMonthlyStipend(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return 'PHP 3,000.00';
    final cleaned = _stripCurrency(text);
    final value = double.tryParse(cleaned);
    if (value == null) return text;
    return 'PHP ${value.toStringAsFixed(2)}';
  }

  String _giftGrantCoverage(Map<String, dynamic> scholar) {
    final coverage = (scholar['grant_coverage'] ?? '').toString().trim();
    if (coverage.isNotEmpty && coverage.toLowerCase() != 'null') {
      return coverage;
    }
    return '100% Free';
  }

  String _giftRetentionGwa(Map<String, dynamic> scholar) {
    final raw =
        (scholar['retention_gwa'] ?? scholar['gpa'] ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '80%';
    final value = double.tryParse(raw);
    if (value == null) return raw;
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _giftRenewalStatus(Map<String, dynamic> scholar) {
    final status = (scholar['scholarship_status'] ?? scholar['status'] ?? '')
        .toString()
        .trim();
    if (status.isEmpty || status.toLowerCase() == 'null') return 'Pending';
    final normalized = status.toLowerCase().replaceAll('_', ' ');
    return _titleCase(normalized);
  }

  String _titleCase(String text) {
    final parts = text
        .split(RegExp(r'\\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    return parts.map((word) {
      final lower = word.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }

  String _giftRenewalLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value.isEmpty || value == 'null') return 'Pending';
    if (value.contains('approve') || value == 'approved') return 'Approved';
    if (value.contains('verify') || value.contains('verification')) {
      return 'Under Verification';
    }
    if (value.contains('pend') || value == 'pending') return 'Pending';
    if (value.contains('term')) return 'Terminated';
    return 'Pending';
  }

  String _giftRenewalPayload(String label) {
    final value = label.trim().toLowerCase();
    if (value.contains('term')) return 'terminated';
    if (value.contains('approve')) return 'approved';
    if (value.contains('verify')) return 'under_verification';
    if (value.contains('pend')) return 'pending';
    return 'pending';
  }

  String _normalizedCategory(Map<String, dynamic> s) {
    final raw = (s['scholarship_category'] ?? s['category'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw.isEmpty ||
        raw == 'student assistant' ||
        raw == 'student_assistant') {
      return 'student_assistant';
    }
    if (raw.contains('academic')) return 'academic_scholar';
    if (raw.contains('varsity')) return 'varsity';
    if (raw.contains('gift')) return 'gift_of_education';
    return 'student_assistant';
  }

  List<Map<String, dynamic>> _buildAreaItems(String categoryKey) {
    final items = <String>{};
    for (final s in _scholars) {
      if (_normalizedCategory(s) != categoryKey) continue;
      final area = (s['assigned_area'] ?? '').toString().trim();
      if (area.isNotEmpty) items.add(area);
    }

    final list = items.isEmpty
        ? ['Library', 'Registrar', 'POD', 'Canteen', 'CITE', 'BSBA Office']
        : items.toList();
    return list.map((title) {
      return {'title': title, 'color': _chipColor(title)};
    }).toList();
  }

  List<Map<String, dynamic>> _buildTypeItems(String categoryKey) {
    final counts = <String, int>{};
    for (final s in _scholars) {
      if (_normalizedCategory(s) != '${categoryKey}_scholar' &&
          !(categoryKey == 'varsity' && _normalizedCategory(s) == 'varsity') &&
          !(categoryKey == 'gift_of_education' &&
              _normalizedCategory(s) == 'gift_of_education')) {
        continue;
      }

      final type = categoryKey == 'academic'
          ? _academicTypeLabel(s['academic_type'])
          : categoryKey == 'varsity'
              ? (s['sport_type'] ?? '').toString().trim()
              : _giftTypeLabel(s['gift_type']);

      if (type.isNotEmpty) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }

    final list = counts.isEmpty
        ? categoryKey == 'academic'
            ? ['Academic A', 'Academic B', 'Academic C']
            : categoryKey == 'varsity'
                ? ['Basketball', 'Volleyball']
                : ScholarshipTypes.giftTypeLabels
        : counts.keys.toList();

    return list.map((title) {
      return {
        'title': title,
        'color': _chipColor(title),
        'count': counts[title] ?? 0,
      };
    }).toList();
  }

  Color _chipColor(String title) {
    final key = title.toLowerCase();
    if (key.contains('library')) return const Color(0xFF43A047);
    if (key.contains('registrar')) return const Color(0xFFE6BE5A);
    if (key.contains('pod')) return const Color(0xFFB39DDB);
    if (key.contains('canteen')) return const Color(0xFFD87474);
    if (key.contains('cite')) return const Color(0xFFB71C1C);
    if (key.contains('bsba')) return const Color(0xFFCE93D8);
    if (key.contains('basketball')) return const Color(0xFFE67E22);
    if (key.contains('volleyball')) return const Color(0xFF3498DB);
    if (key.contains('gift')) return const Color(0xFFE91E63);
    if (key.contains('academic')) return const Color(0xFF43A047);
    return const Color(0xFF6A1B9A);
  }

  String _fullName(Map<String, dynamic> s) {
    final full = (s['name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    final first = (s['first_name'] ?? '').toString().trim();
    final middle = (s['middle_name'] ?? '').toString().trim();
    final last = (s['last_name'] ?? '').toString().trim();
    final middlePart = middle.isEmpty ? '' : ' ${middle[0]}.';
    return '$first$middlePart $last'.trim();
  }

  String _courseYear(Map<String, dynamic> s) {
    final courseYear = (s['course_year'] ?? '').toString().trim();
    if (courseYear.isNotEmpty) return courseYear;
    final course = (s['course'] ?? '-').toString();
    final year = (s['year_level'] ?? '-').toString();
    return '$course - $year';
  }

  String _academicTypeLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toUpperCase();
    if (value == 'A') return 'Type A';
    if (value == 'B') return 'Type B';
    if (value == 'C') return 'Type C';
    if (value.isEmpty) return '';
    return value;
  }

  String _academicTypePayload(dynamic raw) {
    final value = (raw ?? '').toString().trim().toUpperCase();
    if (value == 'A' || value == 'TYPE A') return 'A';
    if (value == 'B' || value == 'TYPE B') return 'B';
    if (value == 'C' || value == 'TYPE C') return 'C';
    return '';
  }

  String _giftTypeLabel(dynamic raw) {
    return ScholarshipTypes.giftTypeLabel(raw);
  }

  String _normalizedGiftType(dynamic raw) {
    return ScholarshipTypes.normalizedGiftType(raw);
  }

  String _latestSubmission(Map<String, dynamic> s) {
    final due = (s['due_date'] ?? '').toString().trim();
    if (due.isNotEmpty) return due;
    return (s['latest_submission'] ?? '—').toString();
  }

  String _gradeStatus(Map<String, dynamic> s) {
    return (s['grade_status'] ?? '—').toString();
  }

  String _renewalStatus(Map<String, dynamic> s) {
    return (s['renewal_status'] ?? '—').toString();
  }

  String _remarksStatus(Map<String, dynamic> s) {
    final bucket = _submissionBucket(s);
    if (bucket == 'missing') return 'Missing';
    if (bucket == 'complete') return 'Complete';
    if (bucket == 'pending') return 'Pending';
    return (s['remarks'] ?? '—').toString();
  }

  String _submissionBucket(Map<String, dynamic> s) {
    final grade = _gradeStatus(s).trim().toLowerCase();
    final renewal = _renewalStatus(s).trim().toLowerCase();

    bool isEmptyOrDash(String v) =>
        v.isEmpty || v == '—' || v == '-' || v == 'null';

    final gradeMissing = isEmptyOrDash(grade) || grade.contains('missing');
    final renewalMissing =
        isEmptyOrDash(renewal) || renewal.contains('missing');
    if (gradeMissing || renewalMissing) return 'missing';

    final gradeComplete = grade.contains('passed') || grade.contains('approved');
    final renewalComplete =
        renewal.contains('passed') || renewal.contains('approved');
    if (gradeComplete && renewalComplete) return 'complete';

    return 'pending';
  }

  int _userId(Map<String, dynamic> s) {
    return int.tryParse((s['user_id'] ?? '').toString()) ?? 0;
  }

  // UPDATED: This now pulls the "30/70" string from the PHP
  String _renderedHours(Map<String, dynamic> s) {
    return (s['duty_hours'] ?? '0/100').toString();
  }

  // UPDATED: Since _renderedHours now shows the full "30/100",
  // you can return empty here or just hide this column in your table.
  String _remainingHours(Map<String, dynamic> s) {
    return '';
  }
}
