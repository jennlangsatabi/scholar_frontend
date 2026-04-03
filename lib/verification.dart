import 'package:flutter/material.dart';

import 'services/api_config.dart';
import 'services/backend_api.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  List<Map<String, dynamic>> pendingDocs = [];
  Map<int, String> _scholarNameByUserId = {};
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchPendingDocuments();
  }

  Future<void> fetchPendingDocuments() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      await _fetchScholarDirectory();
      final list = await BackendApi.getList(
        'get_pending_verifications.php',
        cacheTtl: const Duration(seconds: 10),
        retries: 1,
      );

      setState(() {
        pendingDocs = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Connection error: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchScholarDirectory() async {
    try {
      final map = <int, String>{};
      final list = await BackendApi.getList(
        'get_scholars.php',
        cacheTtl: const Duration(minutes: 2),
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
    } catch (_) {
      // Keep existing map if lookup fails.
    }
  }

  Future<void> updateStatus(String docId, String newStatus) async {
    try {
      final result = await BackendApi.postForm(
        'update_status.php',
        body: {'id': docId, 'status': newStatus},
        retries: 1,
      );
      final ok = result['success'] == true ||
          result['status']?.toString().toLowerCase() == 'success';

      if (!ok) {
        throw Exception(result.toString());
      }

      _showSnackBar("Status updated to $newStatus", Colors.green);
      fetchPendingDocuments();
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _resolveStudentName(Map<String, dynamic> doc) {
    final fullName = (doc['name'] ??
            doc['student_name'] ??
            doc['scholar_name'] ??
            doc['full_name'] ??
            doc['username'])
        ?.toString()
        .trim();
    if (fullName != null &&
        fullName.isNotEmpty &&
        fullName.toLowerCase() != 'unknown scholar' &&
        fullName.toLowerCase() != 'unknown') {
      return fullName;
    }

    final firstName = (doc['first_name'] ?? '').toString().trim();
    final lastName = (doc['last_name'] ?? '').toString().trim();
    final combined = "$firstName $lastName".trim();
    if (combined.isNotEmpty) return combined;

    final userId = int.tryParse((doc['user_id'] ?? '').toString());
    if (userId != null && userId > 0) {
      final mapped = _scholarNameByUserId[userId];
      if (mapped != null && mapped.isNotEmpty) return mapped;
      return "Scholar #$userId";
    }

    return "Unlinked Scholar";
  }

  String _resolveDocumentType(Map<String, dynamic> doc) {
    final raw = (doc['document_type'] ??
            doc['requirement_name'] ??
            doc['type'] ??
            doc['doc_type'])
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

    final reqId = (doc['requirement_id'] ?? '').toString().trim();
    switch (reqId) {
      case '0':
        return 'Report of Grades';
      case '1':
        return 'Renewal Letter';
      case '2':
        return 'Enrollment Form';
      default:
        return reqId.isEmpty ? '' : 'Requirement #$reqId';
    }
  }

  bool _isMissingValue(String value) {
    final v = value.trim();
    return v.isEmpty || v.toLowerCase() == 'n/a';
  }

  bool _isReportOfGrades(String docType, Map<String, dynamic> doc) {
    final type = docType.toLowerCase();
    if (type.contains('report') && type.contains('grade')) return true;

    final raw = (doc['document_type'] ?? doc['requirement_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw.contains('report') && raw.contains('grade')) return true;
    if (raw == 'requirement #0') return true;

    final reqId = (doc['requirement_id'] ?? '').toString().trim();
    return reqId == '0';
  }

  String _resolveSubmittedAt(Map<String, dynamic> doc) {
    final raw = (doc['submitted_at'] ?? doc['upload_date'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return '';

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

  String _resolveImageUrl(Map<String, dynamic> doc) {
    final candidates = [
      doc['image_url'],
      doc['file_path'],
      doc['document_image'],
      doc['image'],
      doc['path'],
    ];

    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      return Uri.encodeFull(ApiConfig.normalizeAssetUrl(value));
    }

    return '';
  }

  void _showFilePreview(Map<String, dynamic> doc) {
    final url = _resolveImageUrl(doc);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 900,
          height: 620,
          child: url.isEmpty
              ? const Center(child: Text('No preview available'))
              : InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Text('Unable to load image')),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (!isLoading && errorMessage.isEmpty) _buildSummary(),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : pendingDocs.isEmpty
                          ? _buildEmptyState()
                          : _buildVerificationList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final refreshButton = FilledButton.icon(
            onPressed: fetchPendingDocuments,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Document Verification Queue",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D0D44),
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
                child: Text(
                  "Document Verification Queue",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D0D44),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              refreshButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary() {
    final total = pendingDocs.length;
    final approved = pendingDocs.where((e) {
      return (e['admin_status'] ?? '')
              .toString()
              .toLowerCase()
              .contains('approved') ==
          true;
    }).length;
    final rejected = pendingDocs.where((e) {
      return (e['admin_status'] ?? '')
              .toString()
              .toLowerCase()
              .contains('rejected') ==
          true;
    }).length;
    final pending = total - approved - rejected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        final columns = width >= 1100
            ? 4
            : width >= 700
                ? 2
                : 1;
        final cardWidth = (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                "Total",
                total.toString(),
                const Color(0xFF5E35B1),
                Icons.layers_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                "Pending",
                pending.toString(),
                const Color(0xFFEF6C00),
                Icons.pending_actions_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                "Approved",
                approved.toString(),
                const Color(0xFF2E7D32),
                Icons.verified_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                "Rejected",
                rejected.toString(),
                const Color(0xFFC62828),
                Icons.cancel_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Color _shiftLightness(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  Widget _summaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftLightness(color, 0.30).withOpacity(0.55),
            Colors.white.withOpacity(0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -10,
            child: Opacity(
              opacity: 0.10,
              child: Icon(icon, size: 82, color: color),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D0D44),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 10),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton(onPressed: fetchPendingDocuments, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No documents awaiting review.",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildVerificationList() {
    return ListView.separated(
      itemCount: pendingDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = pendingDocs[index];
        final imageUrl = _resolveImageUrl(doc);
        final status = (doc['admin_status'] ?? 'Pending').toString();
        final docId = (doc['id'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final content = [
                _buildThumbnail(imageUrl, onTap: () => _showFilePreview(doc)),
                const SizedBox(width: 14, height: 14),
                Expanded(child: _buildDocMeta(doc, status)),
                const SizedBox(width: 14, height: 14),
                _buildActions(docId),
              ];

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(imageUrl, onTap: () => _showFilePreview(doc)),
                    const SizedBox(height: 12),
                    _buildDocMeta(doc, status),
                    const SizedBox(height: 12),
                    _buildActions(docId),
                  ],
                );
              }

              return Row(children: content);
            },
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(String imageUrl, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 160,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF1E9F7),
          border: Border.all(color: const Color(0xFFD9C4E8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl.isEmpty
              ? const Center(child: Text("No image"))
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDocMeta(Map<String, dynamic> doc, String status) {
    final studentName = _resolveStudentName(doc);
    final docType = _resolveDocumentType(doc);
    final term = (doc['academic_term'] ?? '').toString();
    final avg = (doc['computed_average'] ??
            doc['average'] ??
            doc['avg'] ??
            '')
        .toString();
    final submittedAt = _resolveSubmittedAt(doc);
    final showAverage = _isReportOfGrades(docType, doc) && !_isMissingValue(avg);

    final chips = <Widget>[
      _metaChip("Student: $studentName"),
      if (!_isMissingValue(docType)) _metaChip(docType),
      if (!_isMissingValue(term)) _metaChip(term),
      if (!_isMissingValue(submittedAt)) _metaChip(submittedAt),
      if (showAverage) _metaChip("Average: $avg%"),
      _statusChip(status),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...chips,
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "Tap thumbnail to preview full document",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF41205F),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    final color = s.contains('approved')
        ? Colors.green
        : s.contains('rejected')
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActions(String docId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: docId.isEmpty ? null : () => updateStatus(docId, 'Approved'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text("Approve"),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: docId.isEmpty ? null : () => updateStatus(docId, 'Rejected'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text("Reject"),
        ),
      ],
    );
  }
}
