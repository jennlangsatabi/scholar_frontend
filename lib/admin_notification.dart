import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';
import 'services/backend_api.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final String _baseUrl = "${ApiConfig.baseUrl}/";

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _busyId;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final decoded = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_admin_notifications.php',
          query: const {'limit': '120'},
          cacheTtl: const Duration(seconds: 8),
          retries: 1,
        ),
      );

      if (!mounted) return;
      setState(() {
        _items = decoded;
        _isLoading = false;
        _selectionMode = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  dynamic _tryDecodeJson(String source) {
    try {
      return json.decode(source);
    } catch (_) {
      return null;
    }
  }

  String _notificationId(Map<String, dynamic> item) {
    return (item['notification_id'] ?? item['id'] ?? '').toString();
  }

  List<String> _notificationIds(Map<String, dynamic> item) {
    final raw = item['_notification_ids'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    final single = _notificationId(item);
    return single.isEmpty ? <String>[] : <String>[single];
  }

  String _replyId(Map<String, dynamic> item) {
    return (item['reply_id'] ?? '').toString();
  }

  String _titleOf(Map<String, dynamic> item) {
    final replyFrom = _replyAuthor(item);
    final announcementTitle = _announcementTitle(item);
    if (announcementTitle.isNotEmpty) {
      return replyFrom.isEmpty
          ? 'Reply to: $announcementTitle'
          : 'Reply from $replyFrom';
    }
    return replyFrom.isEmpty ? 'Scholar Reply' : 'Reply from $replyFrom';
  }

  String _messageOf(Map<String, dynamic> item) {
    final reply = item['reply_message']?.toString().trim();
    if (reply != null && reply.isNotEmpty) return reply;
    return item['message']?.toString().trim().isNotEmpty == true
        ? item['message'].toString().trim()
        : 'No message content';
  }

  String _profileImageOf(Map<String, dynamic> item) {
    return ApiConfig.normalizeAssetUrl(
      item['profile_image_url']?.toString(),
    );
  }

  String _visibilityOf(Map<String, dynamic> item) {
    final raw = item['visibility']?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return 'admin';
    if (raw == 'all scholars' || raw == 'all') return 'all';
    return 'admin';
  }

  String _dateOf(Map<String, dynamic> item) {
    final value = item['reply_created_at']?.toString().trim() ??
        item['created_at']?.toString().trim() ??
        '';
    return value.isEmpty ? 'Unknown date' : value;
  }

  bool _isPrivate(Map<String, dynamic> item) =>
      _visibilityOf(item).toLowerCase() == 'admin';

  int _recipientCount(Map<String, dynamic> item) {
    final raw = item['_recipient_count'];
    if (raw is int) return raw;
    return _notificationIds(item).length;
  }

  String _replyAuthor(Map<String, dynamic> item) {
    final name = item['username']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = item['email']?.toString().trim() ?? '';
    return email;
  }

  String _announcementTitle(Map<String, dynamic> item) {
    final message = item['notification_message']?.toString().trim() ?? '';
    if (message.isEmpty) return '';
    final parts = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts.first;
    return '';
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final replyId = _replyId(item);
    if (replyId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'This will permanently remove the selected notification or reply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyId = replyId);

    final deleteTargets = <(Uri, Map<String, String>)>[
      (
        Uri.parse("${_baseUrl}delete_reply.php"),
        <String, String>{'reply_id': replyId}
      ),
    ];

    var success = false;
    var errorMessage = 'Unable to delete the selected item.';

    for (final target in deleteTargets) {
      try {
        final response = await http
            .post(target.$1, body: target.$2)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          continue;
        }

        final decoded = _tryDecodeJson(response.body);
        if (decoded is Map<String, dynamic>) {
          final isSuccess = decoded['success'] == true ||
              decoded['status']?.toString().toLowerCase() == 'success';
          if (isSuccess) {
            success = true;
            break;
          }
          errorMessage = decoded['message']?.toString() ?? errorMessage;
        } else {
          success = true;
          break;
        }
      } catch (_) {
        // Try the next endpoint.
      }
    }

    if (!mounted) return;

    setState(() {
      _busyId = null;
      if (success) {
        _items.removeWhere((entry) => _replyId(entry) == replyId);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(success ? 'Item deleted successfully.' : errorMessage),
        backgroundColor: success ? const Color(0xFF205C3B) : Colors.red.shade700,
      ),
    );
  }

  void _toggleSelection(Map<String, dynamic> item) {
    final id = _replyId(item);
    if (id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      _selectedIds.clear();
      if (selectAll) {
        for (final item in _items) {
          final id = _replyId(item);
          if (id.isNotEmpty) _selectedIds.add(id);
        }
      }
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text(
          'Delete ${_selectedIds.length} selected reply(ies)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final id in _selectedIds.toList()) {
      try {
        final response = await http
            .post(
              Uri.parse("${_baseUrl}delete_reply.php"),
              body: {'reply_id': id},
            )
            .timeout(const Duration(seconds: 12));
        final decoded = _tryDecodeJson(response.body);
        final success = response.statusCode >= 200 &&
            response.statusCode < 300 &&
            (decoded is! Map<String, dynamic> ||
                decoded['success'] == true ||
                decoded['status']?.toString().toLowerCase() == 'success');
        if (success) {
          _items.removeWhere((entry) => _replyId(entry) == id);
          _selectedIds.remove(id);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _selectionMode = _selectedIds.isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selected replies deleted.'),
        backgroundColor: Color(0xFF205C3B),
      ),
    );
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final initialVisibility = _visibilityOf(item);
    final profileUrl = _profileImageOf(item);
    final thread = await _fetchThread(item);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminNotificationChatSheet(
        title: _titleOf(item),
        createdAt: _dateOf(item),
        profileImageUrl: profileUrl,
        initialVisibility: initialVisibility,
        initialMessages: thread,
        isAdminView: true,
        onSendReply: (message, visibility) async {
          final response = await http
              .post(
                Uri.parse("${_baseUrl}save_reply.php"),
                body: {
                  'notification_id': _notificationId(item),
                  'message': message,
                  'visibility': visibility,
                },
              )
              .timeout(const Duration(seconds: 12));

          final decoded = _tryDecodeJson(response.body);
          final success = response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (decoded is! Map<String, dynamic> ||
                  decoded['success'] == true ||
                  decoded['status']?.toString().toLowerCase() == 'success');
          if (!success) {
            throw Exception(
              decoded is Map<String, dynamic>
                  ? decoded['message']?.toString() ?? 'Reply failed.'
                  : 'Reply failed.',
            );
          }
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchThread(
    Map<String, dynamic> item,
  ) async {
    final id = _notificationId(item);
    if (id.isEmpty) {
      return _fallbackThread(item, const []);
    }
    try {
      final payload = await BackendApi.getJson(
        'get_replies.php',
        query: {
          'notification_id': id,
          if (item['user_id'] != null) 'user_id': item['user_id'].toString(),
        },
      );
      final replies = _unwrapList(payload);
      return _fallbackThread(item, replies);
    } catch (_) {
      return _fallbackThread(item, const []);
    }
  }

  List<Map<String, dynamic>> _unwrapList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (payload is Map) {
      for (final key in ['data', 'replies', 'messages']) {
        final value = payload[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _fallbackThread(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> replies,
  ) {
    final messages = <Map<String, dynamic>>[];
    final baseMessage =
        (item['notification_message'] ?? item['message'] ?? '').toString().trim();
    if (baseMessage.isNotEmpty) {
      messages.add({
        'message': baseMessage,
        'created_at': item['created_at']?.toString() ?? '',
        'is_admin': true,
      });
    }

    final scholarId = item['user_id']?.toString() ?? '';
    for (final reply in replies) {
      final msg = (reply['reply_message'] ??
              reply['message'] ??
              reply['body'] ??
              '')
          .toString()
          .trim();
      if (msg.isEmpty) continue;
      messages.add({
        'message': msg,
        'created_at': (reply['reply_created_at'] ??
                reply['created_at'] ??
                '')
            .toString(),
        'is_admin': _replyIsAdmin(reply, scholarId),
        'reply_id': reply['reply_id']?.toString(),
      });
    }

    return messages;
  }

  bool _replyIsAdmin(Map<String, dynamic> reply, String scholarId) {
    final role = (reply['role'] ??
            reply['sender_role'] ??
            reply['user_role'] ??
            '')
        .toString()
        .toLowerCase();
    if (role.contains('admin')) return true;
    final flag = reply['is_admin'] ?? reply['from_admin'];
    if (flag == 1 || flag == true) return true;
    final replyUserId = reply['user_id']?.toString();
    if (replyUserId != null && replyUserId.isNotEmpty) {
      return replyUserId != scholarId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final privateCount = _items.where(_isPrivate).length;
    final publicCount = _items.length - privateCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFF8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildSummary(privateCount, publicCount),
                      const SizedBox(height: 18),
                      _buildSectionTitle(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 14);
                        }
                        final itemIndex = index ~/ 2;
                        return _buildNotificationCard(_items[itemIndex]);
                      },
                      childCount: _items.isEmpty ? 0 : (_items.length * 2) - 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D0D44), Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Review scholar messages, reply quickly, and keep the queue clean.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _loadNotifications,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4A176B),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(int privateCount, int publicCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        final columns = width >= 1000
            ? 3
            : width >= 640
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
                'Total',
                _items.length.toString(),
                const Color(0xFF5B2C83),
                Icons.inbox_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                'Admin Only',
                privateCount.toString(),
                const Color(0xFFE08A00),
                Icons.lock_outline_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryCard(
                'Public',
                publicCount.toString(),
                const Color(0xFF1F7A55),
                Icons.public_rounded,
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
      String label, String value, Color color, IconData icon) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(icon, color: color, size: 18),
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
                  color: Color(0xFF2B1A3A),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    final allSelected =
        _items.isNotEmpty && _selectedIds.length == _items.length;
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inbox Queue',
                style: TextStyle(
                  color: Color(0xFF2D0D44),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Use reply for follow-up and delete for items that are no longer needed.',
                style: TextStyle(color: Color(0xFF6F5E7D)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Checkbox(
              value: allSelected,
              onChanged: (value) => _toggleSelectAll(value == true),
            ),
            const SizedBox(width: 6),
            const Text('Select all'),
            const SizedBox(width: 12),
            if (_selectedIds.isNotEmpty)
              FilledButton.icon(
                onPressed: _deleteSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD84343),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text('Delete (${_selectedIds.length})'),
              )
            else
              Text(
                '${_items.length} item${_items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF6F5E7D),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final id = _notificationId(item);
    final isPrivate = _isPrivate(item);
    final isBusy = _busyId == id || (_busyId != null && _busyId == _replyId(item));
    final isSelected = _selectedIds.contains(_replyId(item));
    final profileUrl = _profileImageOf(item);

    return InkWell(
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(item);
        } else {
          _openDetails(item);
        }
      },
      onLongPress: () {
        if (!_selectionMode) {
          setState(() => _selectionMode = true);
        }
        _toggleSelection(item);
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(item),
              ),
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFEFE6F7),
                    backgroundImage: profileUrl.isNotEmpty
                        ? NetworkImage(profileUrl)
                        : null,
                    child: profileUrl.isEmpty
                        ? const Icon(Icons.person, color: Color(0xFF6A1B9A))
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isPrivate
                              ? Icons.lock_rounded
                              : Icons.campaign_rounded,
                          size: 12,
                          color: isPrivate
                              ? const Color(0xFFD98B00)
                              : const Color(0xFF1662A8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleOf(item),
                      style: const TextStyle(
                        color: Color(0xFF251330),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tagChip(
                          isPrivate ? 'Admin only' : 'Visible to scholars',
                          isPrivate
                              ? const Color(0xFFD98B00)
                              : const Color(0xFF1662A8),
                        ),
                        if (_recipientCount(item) > 1)
                          _tagChip(
                            'Sent to ${_recipientCount(item)} scholars',
                            const Color(0xFF2F6B45),
                          ),
                        _tagChip(_dateOf(item), const Color(0xFF6B5A79)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _messageOf(item),
            style: const TextStyle(
              color: Color(0xFF524360),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: isBusy || _selectionMode
                    ? null
                    : () => _openDetails(item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2F6B45),
                  side: const BorderSide(color: Color(0xFF9FD2B0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('View & Reply'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: isBusy || _selectionMode
                    ? null
                    : () => _deleteItem(item),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD84343),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(isBusy ? 'Working...' : 'Delete'),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _tagChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 52, color: Colors.red.shade400),
              const SizedBox(height: 14),
              const Text(
                'Unable to load notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D0D44),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6F5E7D)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_read_rounded,
                size: 54,
                color: Color(0xFF8B6BA4),
              ),
              SizedBox(height: 14),
              Text(
                'No notifications to review',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D0D44),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'New scholar updates and replies will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6F5E7D)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNotificationChatSheet extends StatefulWidget {
  const _AdminNotificationChatSheet({
    required this.title,
    required this.createdAt,
    required this.profileImageUrl,
    required this.initialVisibility,
    required this.initialMessages,
    required this.isAdminView,
    required this.onSendReply,
  });

  final String title;
  final String createdAt;
  final String? profileImageUrl;
  final String initialVisibility;
  final List<Map<String, dynamic>> initialMessages;
  final bool isAdminView;
  final Future<void> Function(String message, String visibility) onSendReply;

  @override
  State<_AdminNotificationChatSheet> createState() =>
      _AdminNotificationChatSheetState();
}

class _AdminNotificationChatSheetState
    extends State<_AdminNotificationChatSheet> {
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;
  late String _visibility;
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialVisibility.toLowerCase().trim();
    _visibility = initial == 'all' || initial == 'all scholars' ? 'all' : 'admin';
    _messages = List<Map<String, dynamic>>.from(widget.initialMessages);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFBFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8CBE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFEFE6F7),
                        backgroundImage: (widget.profileImageUrl != null &&
                                widget.profileImageUrl!.isNotEmpty)
                            ? NetworkImage(widget.profileImageUrl!)
                            : null,
                        child: (widget.profileImageUrl == null ||
                                widget.profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person,
                                color: Color(0xFF6A1B9A))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF251330),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.createdAt,
                              style: const TextStyle(
                                color: Color(0xFF6B5A79),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isAdmin = message['is_admin'] == true;
                      final alignRight =
                          widget.isAdminView ? isAdmin : !isAdmin;
                      return _chatBubble(message, alignRight);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: DropdownButtonFormField<String>(
                    value: _visibility,
                    decoration: InputDecoration(
                      labelText: 'Visibility',
                      filled: true,
                      fillColor: const Color(0xFFF7F3FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Admin only'),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All scholars'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _visibility = value);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            filled: true,
                            fillColor: const Color(0xFFF7F3FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _sending
                            ? null
                            : () async {
                                final message =
                                    _replyController.text.trim();
                                if (message.isEmpty) return;
                                setState(() => _sending = true);
                                try {
                                  await widget.onSendReply(
                                      message, _visibility);
                                  if (!mounted) return;
                                  setState(() {
                                    _messages.add({
                                      'message': message,
                                      'created_at':
                                          DateTime.now().toIso8601String(),
                                      'is_admin': true,
                                    });
                                    _replyController.clear();
                                    _sending = false;
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _sending = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to send reply: $e'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chatBubble(Map<String, dynamic> message, bool alignRight) {
    final bg = alignRight
        ? const Color(0xFF6A1B9A)
        : const Color(0xFFF1EAF7);
    final fg = alignRight ? Colors.white : const Color(0xFF2D0D44);
    final time = (message['created_at'] ?? '').toString();
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['message']?.toString() ?? '',
              style: TextStyle(color: fg, height: 1.4),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: fg.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
