import 'dart:async';

import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class AcademicDashboard extends StatefulWidget {
  final String userId;

  const AcademicDashboard({super.key, required this.userId});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard> {
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  Map<String, dynamic> scholarStats = {
    'academic_type': '',
    'status': 'Loading...',
    'course': '',
  };

  List<dynamic> myRecentSubmissions = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScholarData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchScholarData(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchScholarData({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final data = await BackendApi.getJson(
        'get_scholar_dashboard.php',
        query: {'user_id': widget.userId},
      );

      if (!mounted) return;

      setState(() {
        scholarStats = Map<String, dynamic>.from(
          (data['stats'] as Map?) ?? const <String, dynamic>{},
        );
        myRecentSubmissions = (data['submissions'] as List?) ?? <dynamic>[];
        isLoading = false;
        errorMessage = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Academic dashboard fetch error: $e');
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to refresh academic dashboard right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: RefreshIndicator(
        onRefresh: () async => _fetchScholarData(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Academic Performance Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3B125A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      if (!isNarrow) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Academic Type',
                                _academicTypeValue,
                                const Color(0xFFE6E29C),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                'Status',
                                _statusValue,
                                const Color(0xFFD1B3E2),
                                textColor: _statusTextColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                'Course',
                                _courseValue,
                                const Color(0xFF8EBDC4),
                                textColor: const Color(0xFF1F3A5F),
                              ),
                            ),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _buildStatCard(
                              'Academic Type',
                              _academicTypeValue,
                              const Color(0xFFE6E29C),
                            ),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _buildStatCard(
                              'Status',
                              _statusValue,
                              const Color(0xFFD1B3E2),
                              textColor: _statusTextColor,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _buildStatCard(
                              'Course',
                              _courseValue,
                              const Color(0xFF8EBDC4),
                              textColor: const Color(0xFF1F3A5F),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  if (errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF8A4B08),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Text(
                    'My Recent Document Uploads',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF3B125A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 420,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF3E5F5),
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'File Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Category',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Approval',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: myRecentSubmissions.map((sub) {
                                    final submission =
                                        Map<String, dynamic>.from(sub as Map);
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            (submission['name'] ?? '').toString(),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            (submission['type'] ?? '').toString(),
                                          ),
                                        ),
                                        DataCell(
                                          _statusBadge(
                                            (submission['status'] ?? 'Pending')
                                                .toString(),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/jmcbg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: const Color(0xFF3B125A).withOpacity(0.86),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Academic Scholar Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Track your academic details and submissions.",
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
            TextButton.icon(
              onPressed: () => _fetchScholarData(showLoader: false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
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

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = normalized == 'approved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color bgColor,
      {Color textColor = Colors.black}) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _academicTypeValue {
    final raw = (scholarStats['academic_type'] ?? '').toString().trim();
    if (raw.isEmpty || raw == '-') {
      return 'Not Set';
    }

    if (raw.toLowerCase().startsWith('type ')) {
      return 'Type ${raw.substring(5).trim().toUpperCase()}';
    }

    return 'Type ${raw.toUpperCase()}';
  }

  String get _statusValue {
    final raw = (scholarStats['status'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return 'Pending';
    }

    return raw
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get _courseValue {
    final raw = (scholarStats['course'] ?? '').toString().trim();
    return raw.isEmpty ? 'Not Set' : raw.toUpperCase();
  }

  Color get _statusTextColor {
    final normalized = _statusValue.toLowerCase();
    if (normalized == 'active' || normalized == 'qualified' || normalized == 'approved') {
      return Colors.green[800]!;
    }
    if (normalized == 'pending') {
      return Colors.orange[800]!;
    }
    return Colors.red[800]!;
  }
}
