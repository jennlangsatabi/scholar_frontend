import 'dart:async';

import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic> summary = const {};
  List<Map<String, dynamic>> byType = const [];
  List<Map<String, dynamic>> statusDistribution = const [];
  bool isLoading = true;
  String? errorMessage;
  Timer? _poller;
  DateTime? _lastUpdated;

  static const _pageBg = Color(0xFFC5B4E3);
  static const _ink = Color(0xFF2D0D44);
  static const _surface = Colors.white;
  static const _surfaceTint = Color(0xFFF8F5FB);
  static const _accent = Color(0xFF6A1B9A);
  static const _accent2 = Color(0xFF4A148C);
  static const _border = Color(0xFFE6DFF0);

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final payload = await BackendApi.getJson('get_reports_summary.php');
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(
          payload['summary'] as Map? ?? const <String, dynamic>{},
        );
        byType = (payload['by_type'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        statusDistribution = (payload['status_distribution'] as List? ?? const [])
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
      backgroundColor: _pageBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFDAD2F3),
              Color(0xFFC5B4E3),
              Color(0xFFBBA7E1),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -140,
              right: -170,
              child: _DecorBlob(color: Color(0xFF6A1B9A), size: 420),
            ),
            const Positioned(
              bottom: -180,
              left: -190,
              child: _DecorBlob(color: Color(0xFF4A148C), size: 460),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'REPORTS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                                color: Color(0xFF6A5A79),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'REPORTS MANAGEMENT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                        ),
                        child: IconButton(
                          tooltip: 'Refresh',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, color: _ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (errorMessage != null)
                    Text(errorMessage!)
                  else ...[
                    Text(
                      _lastUpdatedLabel(),
                      style: const TextStyle(
                        color: Color(0xFF6A5A79),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        _buildStatCard(
                          'Total Scholars',
                          '${summary['total_scholars'] ?? 0}',
                          Icons.people_alt_rounded,
                          const Color(0xFF1E88E5),
                        ),
                        _buildStatCard(
                          'Approved',
                          '${summary['approved'] ?? 0}',
                          Icons.verified_rounded,
                          const Color(0xFF43A047),
                        ),
                        _buildStatCard(
                          'Pending',
                          '${summary['pending'] ?? 0}',
                          Icons.hourglass_top_rounded,
                          const Color(0xFFFB8C00),
                        ),
                        _buildStatCard(
                          'Rejected',
                          '${summary['rejected'] ?? 0}',
                          Icons.cancel_rounded,
                          const Color(0xFFE53935),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 980;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildChartContainer(
                                title: 'Scholars by Type',
                                icon: Icons.bar_chart_rounded,
                                child: _buildLiveBarChart(),
                              ),
                              const SizedBox(height: 20),
                              _buildChartContainer(
                                title: 'Status Distribution',
                                icon: Icons.donut_large_rounded,
                                child: _buildLivePieChart(),
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildChartContainer(
                                title: 'Scholars by Type',
                                icon: Icons.bar_chart_rounded,
                                child: _buildLiveBarChart(),
                              ),
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              flex: 1,
                              child: _buildChartContainer(
                                title: 'Status Distribution',
                                icon: Icons.donut_large_rounded,
                                child: _buildLivePieChart(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -14,
            child: Opacity(
              opacity: 0.08,
              child: Icon(icon, size: 92, color: accent),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withOpacity(0.12),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _ink,
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

  Widget _buildChartContainer({
    required String title,
    required Widget child,
    IconData icon = Icons.insights_rounded,
  }) {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(icon, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 30),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildLiveBarChart() {
    final data = _barData();
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final value = (item['value'] as double).clamp(0.0, 1.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: (250 * value),
              decoration: BoxDecoration(
                color: item['color'] as Color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item['label'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLivePieChart() {
    final legend = _statusLegend();
    final total = statusDistribution
        .map((e) => _intValue(e['value']))
        .fold<int>(0, (sum, v) => sum + v);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: total == 0
                ? const Center(
                    child: Icon(
                      Icons.pie_chart_outline,
                      size: 160,
                      color: _accent,
                    ),
                  )
                : CustomPaint(
                    painter: _StatusPiePainter(
                      statusDistribution: statusDistribution,
                      colorFor: _statusColor,
                    ),
                  ),
          ),
          const SizedBox(height: 30),
          ...legend.map((row) => _legendItem(row.$1, row.$2)).toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _barData() {
    if (byType.isEmpty) return [];

    final academic = _countFor('academic');
    final studentAssistant = _countFor('student_assistant');
    final varsity = _countFor('varsity');
    final gift = _countFor('gift_of_education');

    final total = [academic, studentAssistant, varsity, gift]
        .fold<int>(0, (sum, v) => sum + v);
    final denom = total <= 0 ? 1 : total;

    return [
      {
        'label': 'Academic',
        'value': academic / denom,
        'count': academic,
        'color': const Color(0xFF6A1B9A),
      },
      {
        'label': 'Student Assistant',
        'value': studentAssistant / denom,
        'count': studentAssistant,
        'color': const Color(0xFFAB47BC),
      },
      {
        'label': 'Varsity',
        'value': varsity / denom,
        'count': varsity,
        'color': const Color(0xFFCE93D8),
      },
      {
        'label': 'Gift of Ed.',
        'value': gift / denom,
        'count': gift,
        'color': const Color(0xFFE1BEE7),
      },
    ];
  }

  int _countFor(String key) {
    final entry = byType.firstWhere(
      (item) {
        final label = (item['label'] ?? '').toString().toLowerCase();
        if (key == 'student_assistant') {
          return label.contains('student') || label.contains('assistant');
        }
        if (key == 'gift_of_education') {
          return label.contains('gift');
        }
        return label.contains(key.split('_').first);
      },
      orElse: () => const <String, dynamic>{'value': 0},
    );
    return _intValue(entry['value']);
  }

  String _lastUpdatedLabel() {
    if (_lastUpdated == null) return 'Last updated: --';
    final t = _lastUpdated!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return 'Last updated: $hh:$mm:$ss';
  }

  List<(String, Color)> _statusLegend() {
    if (statusDistribution.isEmpty) {
      return const [
        ('Approved', Colors.green),
        ('Pending', Colors.orange),
        ('Rejected', Colors.red),
      ];
    }

    return statusDistribution.map((item) {
      final label = (item['label'] ?? '').toString();
      final color = _statusColor(label);
      return (label, color);
    }).toList();
  }

  Color _statusColor(String label) {
    final key = label.toLowerCase();
    if (key.contains('approve')) return Colors.green;
    if (key.contains('reject')) return Colors.red;
    return Colors.orange;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _legendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink.withOpacity(0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPiePainter extends CustomPainter {
  _StatusPiePainter({
    required this.statusDistribution,
    required this.colorFor,
  });

  final List<Map<String, dynamic>> statusDistribution;
  final Color Function(String label) colorFor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = statusDistribution
        .map((e) => _intValue(e['value']))
        .fold<int>(0, (sum, v) => sum + v);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;

    var startAngle = -1.5708; // -90 degrees
    for (final item in statusDistribution) {
      final value = _intValue(item['value']);
      if (value <= 0) continue;
      final sweep = (value / total) * 6.283185307179586; // 2 * pi
      paint.color = colorFor((item['label'] ?? '').toString());
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  bool shouldRepaint(covariant _StatusPiePainter oldDelegate) {
    return oldDelegate.statusDistribution != statusDistribution;
  }
}

class _DecorBlob extends StatelessWidget {
  const _DecorBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.22),
              color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}
