import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);

  String selectedScholarType = 'Student Assistant';
  Map<String, String> currentStats = {
    'total': '0',
    'pending': '0',
    'active': '0',
  };

  List<Map<String, dynamic>> recentSubmissions = [];
  Map<int, String> _scholarNameByUserId = {};
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;
  DateTime? lastUpdatedAt;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAdminStats();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchAdminStats(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAdminStats(silent: true);
    }
  }

  Future<void> _fetchAdminStats({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (!silent) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
      errorMessage = null;
    });

    try {
      await _fetchScholarDirectory();

      final uri = ApiConfig.uri('get_admin_stats.php', {
        'scholar_type': selectedScholarType,
      });
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Server status code: ${response.statusCode}");
      }

      final body = response.body.trim();
      if (body.isEmpty || body.startsWith('<')) {
        throw const FormatException("Server returned non-JSON data.");
      }

      final dynamic decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Invalid JSON payload shape.");
      }

      final submissionsRaw = decoded['recent_submissions'];
      List<Map<String, dynamic>> submissions = submissionsRaw is List
          ? submissionsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (_needsSubmissionFallback(submissions)) {
        final fallback = await _fetchPendingVerificationRows();
        if (fallback.isNotEmpty) {
          submissions = fallback;
        }
      }

      setState(() {
        currentStats = {
          'total': (decoded['total_scholars'] ?? 0).toString(),
          'pending': (decoded['pending_renewals'] ?? 0).toString(),
          'active': (decoded['active_scholars'] ?? 0).toString(),
        };
        recentSubmissions = submissions;
        isLoading = false;
        isRefreshing = false;
        lastUpdatedAt = DateTime.now();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isRefreshing = false;
        errorMessage = "Unable to sync dashboard: $e";
      });
    }
  }

  bool _needsSubmissionFallback(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return true;
    final hasUsefulRow = rows.any((r) {
      final hasDate = (r['submitted_at'] ?? r['upload_date'] ?? '')
          .toString()
          .trim()
          .isNotEmpty;
      final hasUser = _resolveSubmissionUserId(r) != null;
      final name = (r['name'] ?? r['student_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final hasRealName =
          name.isNotEmpty && name != 'unknown' && name != 'unknown scholar';
      return hasDate || hasUser || hasRealName;
    });
    return !hasUsefulRow;
  }

  Future<List<Map<String, dynamic>>> _fetchPendingVerificationRows() async {
    try {
      final response = await http.get(
        ApiConfig.uri("get_pending_verifications.php"),
      );
      if (response.statusCode != 200) return [];
      final body = response.body.trim();
      if (body.isEmpty || body.startsWith('<')) return [];
      final decoded = json.decode(body);
      final list = decoded is Map && decoded['data'] is List
          ? decoded['data'] as List
          : (decoded is List ? decoded : []);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchScholarDirectory() async {
    try {
      final response = await http
          .get(ApiConfig.uri("get_scholars.php"));
      if (response.statusCode != 200) return;
      final body = response.body.trim();
      if (body.isEmpty || body.startsWith('<')) return;

      final decoded = json.decode(body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);
      if (list is! List) return;

      final map = <int, String>{};
      for (final raw in list) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = int.tryParse((item['user_id'] ?? '').toString());
        if (id == null || id <= 0) continue;

        final first = (item['first_name'] ?? '').toString().trim();
        final last = (item['last_name'] ?? '').toString().trim();
        final full = '$first $last'.trim();
        if (full.isNotEmpty) {
          map[id] = full;
        }
      }

      _scholarNameByUserId = map;
    } catch (_) {
      // Keep existing map if lookup fails.
    }
  }

  String _lastUpdatedLabel() {
    if (lastUpdatedAt == null) return "Not synced yet";
    final t = lastUpdatedAt!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return "Last updated $hh:$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F2F7),
      child: RefreshIndicator(
        onRefresh: () => _fetchAdminStats(),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _buildTopBar(),
            const SizedBox(height: 14),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildSubmissionsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Admin Operations Dashboard",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D0D44),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Live monitoring for scholars, verifications, and document flow",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6A5A79),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: isLoading ? null : () => _fetchAdminStats(),
            icon: isRefreshing
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text("Refresh"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _lastUpdatedLabel(),
          style: const TextStyle(
            color: Color(0xFF6A5A79),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final minCardWidth = 240.0;
            final spacing = 12.0;
            final columns =
                ((width + spacing) / (minCardWidth + spacing)).floor().clamp(1, 3);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statCardFlexible(
                  columns: columns,
                  spacing: spacing,
                  child: _buildStatCard(
                    title: "Total Scholars",
                    value: currentStats['total']!,
                    tint: const Color(0xFF5E35B1),
                    icon: Icons.groups_2_rounded,
                  ),
                ),
                _statCardFlexible(
                  columns: columns,
                  spacing: spacing,
                  child: _buildStatCard(
                    title: "Pending Verifications",
                    value: currentStats['pending']!,
                    tint: const Color(0xFFEF6C00),
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
                _statCardFlexible(
                  columns: columns,
                  spacing: spacing,
                  child: _buildStatCard(
                    title: "Active Scholars",
                    value: currentStats['active']!,
                    tint: const Color(0xFF2E7D32),
                    icon: Icons.verified_user_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statCardFlexible({
    required int columns,
    required double spacing,
    required Widget child,
  }) {
    if (columns <= 1) {
      return Expanded(child: child);
    }
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          left: spacing / 2,
          right: spacing / 2,
        ),
        child: child,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color tint,
    required IconData icon,
  }) {
    return SizedBox(
      width: 240,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              tint.withOpacity(0.08),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tint, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF4B3B5A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: tint,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Recent Submissions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D0D44),
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recentSubmissions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "No recent submissions found.",
                style: TextStyle(color: Color(0xFF6A5A79)),
              ),
            )
          else
            _buildSubmissionTable(),
        ],
      ),
    );
  }

  Widget _buildSubmissionTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F1FB),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Student Name')),
              Expanded(flex: 3, child: Text('Document Type')),
              Expanded(flex: 2, child: Text('Submitted')),
              Expanded(flex: 2, child: Text('Status')),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentSubmissions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (context, index) {
            final sub = recentSubmissions[index];
            final studentName = _resolveStudentName(sub);
            final documentType = _resolveDocumentType(sub);
            final submittedAt = _resolveSubmittedAt(sub);
            final status =
                (sub['status'] ?? sub['admin_status'] ?? 'Pending').toString();

            return Container(
              color: index.isEven ? Colors.white : const Color(0xFFFCFBFE),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      studentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      documentType,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      submittedAt,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(flex: 2, child: _statusBadge(status)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _resolveStudentName(Map<String, dynamic> sub) {
    final fullName = (sub['name'] ??
            sub['student_name'] ??
            sub['scholar_name'] ??
            sub['full_name'] ??
            sub['username'])
        ?.toString()
        .trim();
    if (fullName != null &&
        fullName.isNotEmpty &&
        fullName.toLowerCase() != 'unknown scholar' &&
        fullName.toLowerCase() != 'unknown') {
      return fullName;
    }

    final firstName = (sub['first_name'] ?? '').toString().trim();
    final lastName = (sub['last_name'] ?? '').toString().trim();
    final combined = "$firstName $lastName".trim();
    if (combined.isNotEmpty) return combined;

    final userId = _resolveSubmissionUserId(sub);
    if (userId != null && userId > 0) {
      final mapped = _scholarNameByUserId[userId];
      if (mapped != null && mapped.isNotEmpty) return mapped;
      return "Scholar #$userId";
    }

    return "Unlinked Scholar";
  }

  String _resolveDocumentType(Map<String, dynamic> sub) {
    final raw = (sub['type'] ??
            sub['document_type'] ??
            sub['doc_type'] ??
            sub['requirement_name'])
        ?.toString()
        .trim();

    if (raw != null && raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (lower == 'requirement #0') return 'Report of Grades';
      if (lower == 'requirement #1') return 'Renewal Letter';
      if (lower == 'requirement #2') return 'Enrollment Form';
      if (lower == 'document') return 'Submitted Document';
      return raw;
    }

    final reqId = (sub['requirement_id'] ?? '').toString().trim();
    switch (reqId) {
      case '0':
        return 'Report of Grades';
      case '1':
        return 'Renewal Letter';
      case '2':
        return 'Enrollment Form';
      default:
        return reqId.isEmpty ? 'Submitted Document' : 'Requirement #$reqId';
    }
  }

  String _resolveSubmittedAt(Map<String, dynamic> sub) {
    final raw = (sub['submitted_at'] ?? sub['upload_date'] ?? '').toString().trim();
    if (raw.isEmpty) return '-';

    DateTime? dt;
    dt = DateTime.tryParse(raw);
    dt ??= DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour12 = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$month $day, $year $hour12:$minute $ampm";
  }

  int? _resolveSubmissionUserId(Map<String, dynamic> sub) {
    final fromFields = int.tryParse(
      (sub['user_id'] ?? sub['scholar_id'] ?? '').toString(),
    );
    if (fromFields != null && fromFields > 0) return fromFields;

    final filePath = (sub['file_path'] ?? sub['image_url'] ?? '').toString();
    if (filePath.isNotEmpty) {
      final match = RegExp(r'_(\d+)\.[A-Za-z0-9]+$').firstMatch(filePath);
      final inferred = int.tryParse(match?.group(1) ?? '');
      if (inferred != null && inferred > 0) return inferred;
    }

    return null;
  }

  Widget _statusBadge(String status) {
    final value = status.toLowerCase();
    final bool approved = value.contains('approve');
    final bool rejected = value.contains('reject');

    final color = approved
        ? const Color(0xFF2E7D32)
        : rejected
            ? const Color(0xFFC62828)
            : const Color(0xFFEF6C00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
