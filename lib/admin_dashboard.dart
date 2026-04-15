import 'dart:async';
import 'package:flutter/material.dart';

import 'account_requests_modal.dart';
import 'services/backend_api.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 20);
  static const _scholarDirectoryTtl = Duration(minutes: 2);

  String selectedScholarType = 'Student Assistant';
  Map<String, String> currentStats = {
    'total': '0',
    'pending': '0',
    'active': '0',
  };

  List<Map<String, dynamic>> recentSubmissions = [];
  Map<int, String> _scholarNameByUserId = {};
  DateTime? _scholarDirectoryFetchedAt;
  int _pendingAccountRequests = 0;
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
    _loadPendingAccountRequests();
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
      await _ensureScholarDirectory();

      final decoded = await BackendApi.getJson(
        'get_admin_stats.php',
        query: {'scholar_type': selectedScholarType},
        cacheTtl: const Duration(seconds: 8),
        retries: 1,
      );

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

      _loadPendingAccountRequests();
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
      return await BackendApi.getList(
        "get_pending_verifications.php",
        cacheTtl: const Duration(seconds: 10),
        retries: 1,
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadPendingAccountRequests() async {
    try {
      final payload = await BackendApi.getJson(
        'get_account_requests.php',
        query: const {'status': 'pending', 'limit': '200'},
        cacheTtl: Duration.zero,
        retries: 1,
      );
      final items = payload['data'];
      final count = items is List ? items.length : 0;
      if (!mounted) return;
      setState(() => _pendingAccountRequests = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingAccountRequests = 0);
    }
  }

  Future<void> _fetchScholarDirectory() async {
    try {
      final map = <int, String>{};
      final list = await BackendApi.getList(
        "get_scholars.php",
        cacheTtl: _scholarDirectoryTtl,
        retries: 1,
      );
      for (final item in list) {
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
      _scholarDirectoryFetchedAt = DateTime.now();
    } catch (_) {
      // Keep existing map if lookup fails.
    }
  }

  Future<void> _ensureScholarDirectory({bool force = false}) async {
    if (!force &&
        _scholarDirectoryFetchedAt != null &&
        DateTime.now().difference(_scholarDirectoryFetchedAt!) <
            _scholarDirectoryTtl) {
      return;
    }
    await _fetchScholarDirectory();
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final refreshButton = FilledButton.icon(
            onPressed: isLoading ? null : () => _fetchAdminStats(),
            icon: isRefreshing
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text("Refresh"),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Admin Operations Dashboard",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D0D44),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Live monitoring for scholars, verifications, and document flow",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6A5A79),
                  ),
                ),
                const SizedBox(height: 12),
                refreshButton,
              ],
            );
          }

          return Row(
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
              const SizedBox(width: 12),
              _accountRequestsButton(),
              const SizedBox(width: 12),
              refreshButton,
            ],
          );
        },
      ),
    );
  }

  Widget _accountRequestsButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FilledButton.icon(
          onPressed: _openAccountRequestsModal,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text("Account Requests"),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B125A),
            foregroundColor: Colors.white,
          ),
        ),
        if (_pendingAccountRequests > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                _pendingAccountRequests.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openAccountRequestsModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AccountRequestsModal(),
    );
    await _loadPendingAccountRequests();
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
                ((width + spacing) / (minCardWidth + spacing)).floor().clamp(
                      1,
                      3,
                    );
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _statCardFlexible(
                  width: width,
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
                  width: width,
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
                  width: width,
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
    required double width,
    required int columns,
    required double spacing,
    required Widget child,
  }) {
    final cardWidth = columns <= 1
        ? width
        : (width - ((columns - 1) * spacing)) / columns;
    return SizedBox(
      width: cardWidth,
      child: child,
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
          child: _responsiveSubmissionRow(
            header: true,
            name: const Text('Student Name'),
            type: const Text('Document Type'),
            submitted: const Text('Submitted'),
            status: const Text('Status'),
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
              child: _responsiveSubmissionRow(
                header: false,
                name: Text(
                  studentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                type: Text(
                  documentType,
                  overflow: TextOverflow.ellipsis,
                ),
                submitted: Text(
                  submittedAt,
                  overflow: TextOverflow.ellipsis,
                ),
                status: _statusBadge(status),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _responsiveSubmissionRow({
    required bool header,
    required Widget name,
    required Widget type,
    required Widget submitted,
    required Widget status,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              Expanded(flex: 3, child: name),
              Expanded(flex: 3, child: type),
              Expanded(flex: 2, child: submitted),
              Expanded(flex: 2, child: status),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            name,
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _mobileSubmissionField(
                  label: 'Document',
                  child: type,
                  header: header,
                ),
                _mobileSubmissionField(
                  label: 'Submitted',
                  child: submitted,
                  header: header,
                ),
                _mobileSubmissionField(
                  label: 'Status',
                  child: status,
                  header: header,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _mobileSubmissionField({
    required String label,
    required Widget child,
    required bool header,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: header
                  ? const Color(0xFF2D0D44)
                  : const Color(0xFF6A5A79),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
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
