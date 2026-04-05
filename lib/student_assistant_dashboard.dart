import 'dart:async';

import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class StudentAssistantDashboard extends StatefulWidget {
  final String? userId;

  const StudentAssistantDashboard({super.key, this.userId});

  @override
  State<StudentAssistantDashboard> createState() =>
      _StudentAssistantDashboardState();
}

class _StudentAssistantDashboardState extends State<StudentAssistantDashboard> {
  String hoursRendered = "0";
  String dutyStatus = "Active";
  String requiredHours = "400";
  String supervisor = "Scholarship Office";
  List<dynamic> submissionStatus = [];
  Timer? _timer;
  DateTime? _lastUpdated;
  String? _errorMessage;

  Color _shiftLightness(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    if (widget.userId == null || widget.userId!.trim().isEmpty) {
      debugPrint("Dashboard Sync Skipped: empty userId");
      return;
    }

    try {
      final results = await Future.wait([
        BackendApi.getJson(
          'get_sa_stats.php',
          query: {'user_id': widget.userId},
        ),
        BackendApi.getJson(
          'get_scholar_profile.php',
          query: {'user_id': widget.userId},
        ),
        BackendApi.getJson('get_monitoring_summary.php'),
      ]);

      final data = results[0];
      final profilePayload = results[1];
      final monitoringPayload = results[2];
      final profile = Map<String, dynamic>.from(
        profilePayload['profile'] as Map? ?? const <String, dynamic>{},
      );
      final detailRows = (profilePayload['detail_rows'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final detailRow =
          detailRows.isNotEmpty ? detailRows.first : <String, dynamic>{};
      final monitoringRow =
          _findMonitoringRow(monitoringPayload, widget.userId!.trim());
      final monitoringDuty = _splitDutyHours(
        (monitoringRow['duty_hours'] ?? '').toString(),
      );

      if (!mounted) return;
      setState(() {
        hoursRendered = _firstNonEmpty([
          monitoringDuty.$1,
          data['rendered_hours'],
          data['rendered'],
          hoursRendered,
        ], fallback: "0");
        dutyStatus =
            (data['duty_status'] ?? data['status'])?.toString() ?? "On-Going";
        requiredHours = _firstNonEmpty([
          monitoringDuty.$2,
          monitoringRow['required_hours'],
          detailRow['Required Hours'],
          data['required_hours'],
          data['required'],
          requiredHours,
        ], fallback: "400");
        supervisor = _firstNonEmpty([
          monitoringRow['supervisor'],
          detailRow['Supervisor'],
          profile['supervisor'],
          supervisor,
        ], fallback: "Scholarship Office");
        submissionStatus = data['submissions'] ?? [];
        _lastUpdated = DateTime.now();
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint("Dashboard Sync Error: $e");
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to refresh dashboard data right now. Please try again.';
      });
    }
  }

  Map<String, dynamic> _findMonitoringRow(
    Map<String, dynamic> payload,
    String userId,
  ) {
    final scholars = (payload['scholars'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    for (final scholar in scholars) {
      if ((scholar['user_id'] ?? '').toString() == userId) {
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

  String _firstNonEmpty(List<dynamic> values, {required String fallback}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: RefreshIndicator(
        onRefresh: () async => fetchData(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _heroHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF8A4B08),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  _statStrip(),
                  const SizedBox(height: 20),
                  _submissionPanel(),
                  const SizedBox(height: 18),
                  _tipPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/jmcbg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF2D0D44).withOpacity(0.82),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxWidth < 520;
            final iconBox = tight ? 44.0 : 54.0;
            final iconSize = tight ? 24.0 : 28.0;
            final titleSize = tight ? 20.0 : 26.0;
            final spacing = tight ? 12.0 : 16.0;

            final headerBody = Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.handyman_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Student Assistant Dashboard",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Track your hours, submissions, and duty updates in real time.",
                        style: TextStyle(color: Colors.white70),
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
              ],
            );

            final refreshButton = tight
                ? Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Refresh',
                      onPressed: fetchData,
                      icon: const Icon(Icons.refresh_rounded),
                      color: Colors.white,
                    ),
                  )
                : TextButton.icon(
                    onPressed: fetchData,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  );

            if (tight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerBody,
                  const SizedBox(height: 8),
                  refreshButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: headerBody),
                refreshButton,
              ],
            );
          },
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

  Widget _statStrip() {
    final stats = [
      _StatTile(
        label: "Hours Rendered",
        value: hoursRendered,
        accent: const Color(0xFF1565C0),
        icon: Icons.access_time_rounded,
      ),
      _StatTile(
        label: "Duty Status",
        value: dutyStatus,
        accent: const Color(0xFF2E7D32),
        icon: Icons.verified_user_rounded,
      ),
      _StatTile(
        label: "Required Hours",
        value: requiredHours,
        accent: const Color(0xFFE65100),
        icon: Icons.hourglass_bottom_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const gap = 14.0;

        // Match the varsity dashboard style on wide screens: 3 cards in one row.
        if (maxW >= 860) {
          return Row(
            children: [
              Expanded(child: _buildStatCard(stats[0])),
              const SizedBox(width: gap),
              Expanded(child: _buildStatCard(stats[1])),
              const SizedBox(width: gap),
              Expanded(child: _buildStatCard(stats[2])),
            ],
          );
        }

        // On smaller screens, wrap and keep them nicely sized.
        final cardW = (maxW >= 540) ? (maxW - 16) / 2 : maxW;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: stats
              .map((s) => SizedBox(width: cardW, child: _buildStatCard(s)))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatTile tile) {
    final c0 = _shiftLightness(tile.accent, 0.32);
    final c1 = _shiftLightness(tile.accent, 0.10);
    final tint = tile.accent.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, tint],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: tile.accent.withOpacity(0.22)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -14,
            child: Opacity(
              opacity: 0.10,
              child: Icon(tile.icon, size: 96, color: tile.accent),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c0, c1],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: tile.accent.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(tile.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      style: const TextStyle(
                        color: Color(0xFF6A5A79),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tile.value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D0D44),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submissionPanel() {
    final items = submissionStatus.isEmpty
        ? const <Map<String, dynamic>>[]
        : submissionStatus
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_upload_outlined, color: Color(0xFF6A1B9A)),
              SizedBox(width: 10),
              Text(
                "Submission Status",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D0D44),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              "No uploads yet. Submit your weekly report.",
              style: TextStyle(color: Colors.black54),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBFAFE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6DFF0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F5FB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'File',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D0D44),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D0D44),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...items.take(6).map((item) {
                    final title =
                        (item['doc_name'] ?? item['requirement_name'] ?? "Report")
                            .toString();
                    final status =
                        (item['status'] ?? item['admin_status'] ?? 'Pending')
                            .toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFEDE6F6), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D0D44),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _statusChip(status),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    Color color;
    if (lower.contains('approved') || lower.contains('verified')) {
      color = const Color(0xFF2E7D32);
    } else if (lower.contains('pending')) {
      color = const Color(0xFFEF6C00);
    } else {
      color = const Color(0xFFC62828);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tipPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1D6EB)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Color(0xFF6A1B9A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Ensure your supervisor has signed the physical DTR before uploading.",
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF4A148C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
}
