import 'package:flutter/material.dart';

import 'services/backend_api.dart';

class AccountRequestsModal extends StatefulWidget {
  const AccountRequestsModal({super.key});

  @override
  State<AccountRequestsModal> createState() => _AccountRequestsModalState();
}

class _AccountRequestsModalState extends State<AccountRequestsModal> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payload = await BackendApi.getJson(
        'get_account_requests.php',
        query: const {'status': 'pending', 'limit': '200'},
        cacheTtl: Duration.zero,
        retries: 1,
      );
      final data = payload['data'];
      final items = data is List
          ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final requestId = (item['request_id'] ?? '').toString();
    if (requestId.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final response = await BackendApi.postForm(
        'approve_account_request.php',
        body: {'request_id': requestId},
        timeout: const Duration(seconds: 45),
        retries: 1,
      );

      if (!mounted) return;
      setState(() {
        _items.removeWhere((entry) =>
            (entry['request_id'] ?? '').toString() == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Request approved',
          ),
          backgroundColor: const Color(0xFF205C3B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to approve request: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _decline(Map<String, dynamic> item) async {
    final requestId = (item['request_id'] ?? '').toString();
    if (requestId.isEmpty || _isSaving) return;

    final controller = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Optional reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;

    setState(() => _isSaving = true);
    try {
      final response = await BackendApi.postForm(
        'decline_account_request.php',
        body: {
          'request_id': requestId,
          'review_note': note,
        },
        timeout: const Duration(seconds: 30),
        retries: 1,
      );

      if (!mounted) return;
      setState(() {
        _items.removeWhere((entry) =>
            (entry['request_id'] ?? '').toString() == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Request declined',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to decline request: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _scholarshipLabel(String category, String label) {
    if (label.trim().isNotEmpty) return label.trim();
    switch (category.trim().toLowerCase()) {
      case 'student_assistant':
        return 'Student Assistant Scholar';
      case 'varsity':
        return 'Varsity Scholar';
      case 'academic':
        return 'Academic Scholar';
      case 'gift_of_education':
        return 'Gift of Education Scholar';
      default:
        return category.isNotEmpty ? category : 'Scholar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Account Requests',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D0D44),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _loadRequests,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Approve or decline Google account requests before the user can log in.',
                style: TextStyle(color: Color(0xFF6A5A79)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : _items.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending account requests.',
                                  style: TextStyle(color: Color(0xFF6A5A79)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  final role = (item['role'] ?? '').toString();
                                  final name = (item['username'] ?? '').toString();
                                  final email = (item['email'] ?? '').toString();
                                  final category = (item['scholarship_category'] ?? '').toString();
                                  final label = _scholarshipLabel(
                                    category,
                                    (item['scholarship_type_label'] ?? '').toString(),
                                  );

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F5FB),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xFFE6DDF1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name.isNotEmpty ? name : email,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF2D0D44),
                                                ),
                                              ),
                                            ),
                                            _pill(role == 'admin' ? 'Admin' : 'Scholar'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            color: Color(0xFF4B3B5A),
                                          ),
                                        ),
                                        if (role == 'scholar') ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Scholarship: $label',
                                            style: const TextStyle(
                                              color: Color(0xFF4B3B5A),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _isSaving
                                                    ? null
                                                    : () => _decline(item),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.redAccent,
                                                ),
                                                child: const Text('Decline'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: _isSaving
                                                    ? null
                                                    : () => _approve(item),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF205C3B),
                                                ),
                                                child: const Text('Approve'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B125A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3B125A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

