import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard_components.dart';
import 'services/backend_api.dart';

class GiftOfEducationDashboard extends StatefulWidget {
  final String userId;
  const GiftOfEducationDashboard({super.key, required this.userId});

  @override
  State<GiftOfEducationDashboard> createState() =>
      _GiftOfEducationDashboardState();
}

class _GiftOfEducationDashboardState extends State<GiftOfEducationDashboard> {
  Timer? _timer;
  DateTime? _lastUpdated;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(showLoader: false),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  _buildEducationStats(),
                  const SizedBox(height: 20),
                  _buildFormalContentBox(
                    title: "Submission Status",
                    children: [
                      _submissionRow("1773745702_4_8462b81b.png", "rejected",
                          Colors.red.shade50, Colors.red.shade700),
                      const SizedBox(height: 12),
                      _submissionRow("1773745409_4_4b8d11c6.png", "approved",
                          Colors.green.shade50, Colors.green.shade700),
                      const SizedBox(height: 12),
                      _submissionRow("1773745373_4_ab8c301b.jpg", "approved",
                          Colors.green.shade50, Colors.green.shade700),
                      const SizedBox(height: 12),
                      _submissionRow("1773744017_4_f1821eda.png", "approved",
                          Colors.green.shade50, Colors.green.shade700),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFormalContentBox(
                    title: "Grant Renewal Status",
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Semestral Grant",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          _badge("Active", Colors.green.shade400),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Academic Standing",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: 0.85,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.purple.shade300,
                                  const Color(0xFF6A1B9A)
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Retention Limit: 2.0",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                            ),
                          ),
                          Text(
                            "Current GWA: 1.25",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE1BEE7)),
                        ),
                        child: const Text(
                          "Your current GWA (1.25) is well above the required 2.0 for scholarship retention. Keep up the excellent academic performance!",
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF2D0D44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool showLoader = true}) async {
    // Optional: touch the same endpoint so we can show "Last updated" consistently.
    // This file currently uses static content for the panels.
    try {
      await BackendApi.getJson(
        'get_scholar_dashboard.php',
        query: {'user_id': widget.userId},
      );
      if (!mounted) return;
      setState(() {
        _lastUpdated = DateTime.now();
        _errorMessage = null;
      });
    } catch (_) {
      // Keep UI usable even if the refresh endpoint fails.
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to refresh grant data right now. Please try again.';
      });
    }
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
        color: const Color(0xFF3B125A).withValues(alpha: 0.86),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Gift of Education Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Track your grant status and submissions.",
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
              onPressed: () => _refresh(showLoader: false),
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

  Widget _buildFormalContentBox(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFAB47BC), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1B9A))),
          const Divider(height: 30),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEducationStats() {
    const spacing = 12.0;

    final cards = [
      DashProps.statBox(
        "General Weighted Ave.",
        "1.25",
        const Color(0xFFE9E59B), // Light Yellow
        Colors.black,
      ),
      DashProps.statBox(
        "Total Units",
        "21",
        const Color(0xFFD7BDE2), // Light Lavender
        Colors.black,
      ),
      DashProps.statBox(
        "Scholarship Status",
        "Qualified",
        const Color(0xFF90C2C2), // Muted Teal
        const Color(0xFF2E7D32), // Dark Green
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 3;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _submissionRow(
      String fileName, String status, Color bgColor, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2D0D44)),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 92),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

