import 'dart:async';

import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class VarsityDashboard extends StatefulWidget {
  final String userId;
  const VarsityDashboard({super.key, required this.userId});

  @override
  State<VarsityDashboard> createState() => _VarsityDashboardState();
}

class _VarsityDashboardState extends State<VarsityDashboard> {
  Map<String, dynamic> stats = const {};
  Map<String, dynamic> profile = const {};
  List<Map<String, dynamic>> submissions = const [];
  bool isLoading = true;
  String? errorMessage;
  Timer? _timer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        BackendApi.getJson(
          'get_scholar_dashboard.php',
          query: {'user_id': widget.userId},
        ),
        BackendApi.getJson(
          'get_scholar_profile.php',
          query: {'user_id': widget.userId},
        ),
      ]);
      final payload = results[0];
      final profilePayload = results[1];
      if (!mounted) return;
      setState(() {
        stats = Map<String, dynamic>.from(
          payload['stats'] as Map? ?? const <String, dynamic>{},
        );
        profile = Map<String, dynamic>.from(
          profilePayload['profile'] as Map? ?? const <String, dynamic>{},
        );
        submissions = (payload['submissions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        isLoading = false;
        errorMessage = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? _errorState(errorMessage!)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summaryCards(),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildGameScheduleShowcase(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _buildFormalContentBox(
                              title: "Recent Submissions",
                              subtitle:
                                  "Latest documents sent for verification.",
                              children: submissions.isEmpty
                                  ? const [
                                      Text(
                                        'No recent submissions found.',
                                        style: TextStyle(
                                          color: Color(0xFF6F5E7D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    ]
                                  : submissions
                                      .map(
                                        (item) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: _infoRow(
                                            Icons.upload_file,
                                            item['type']?.toString() ??
                                                'Document',
                                            item['status']?.toString() ??
                                                'Pending',
                                          ),
                                        ),
                                      )
                                      .toList(),
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
              child: const Icon(Icons.sports_martial_arts_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Varsity Scholar Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Track your status, submissions, and milestones.",
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
              onPressed: _load,
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

  Widget _buildFormalContentBox({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D0D44),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF6F5E7D),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGameScheduleShowcase() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A0D44),
            Color(0xFF4A148C),
            Color(0xFF6A1B9A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -8,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Text(
                  'LIVE VARSITY SCHEDULE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Game Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _gameScheduleValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.stadium_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Stay tuned for the next game schedule update.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6A1B9A)),
        const SizedBox(width: 10),
        Text(
          "$title: ",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D0D44),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4C3B59),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCards() {
    final sport = _sportValue;
    final status = stats['status']?.toString() ?? 'Pending';
    final course = stats['course']?.toString() ?? '-';
    return Row(
      children: [
        _statCard(
          title: 'Sport',
          value: sport,
          icon: Icons.sports_basketball_rounded,
          color: const Color(0xFF4A148C),
        ),
        const SizedBox(width: 14),
        _statCard(
          title: 'Status',
          value: status,
          icon: Icons.verified_rounded,
          color: const Color(0xFF1B5E20),
        ),
        const SizedBox(width: 14),
        _statCard(
          title: 'Course',
          value: course,
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF0D47A1),
        ),
      ],
    );
  }

  String get _sportValue =>
      profile['sport_type']?.toString().trim().isNotEmpty == true
          ? profile['sport_type'].toString()
          : stats['sport_type']?.toString() ?? 'Varsity Team';

  String get _gameScheduleValue =>
      profile['game_schedule']?.toString().trim().isNotEmpty == true
          ? profile['game_schedule'].toString()
          : 'No game schedule yet';

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6F5E7D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2D0D44),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 38),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6F5E7D)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $suffix";
  }
}
