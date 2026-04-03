import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';
import 'services/backend_api.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;
  final Future<void> Function()? onRefreshCount;
  final ValueChanged<int>? onUnreadCountChanged;
  final int? initialAnnouncementId;

  const NotificationScreen({
    super.key,
    required this.userId,
    this.onRefreshCount,
    this.onUnreadCountChanged,
    this.initialAnnouncementId,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String _baseUrl = "${ApiConfig.baseUrl}/";

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _busyId;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  String? _profileImageUrl;
  bool _autoOpenedInitial = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadProfileImage();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parsed = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_notifications.php',
          query: {'user_id': widget.userId},
        ),
      );

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _isLoading = false;
        _selectionMode = false;
        _selectedIds.clear();
        _lastUpdated = DateTime.now();
      });
      _notifyUnreadCount();
      _maybeAutoOpenInitialAnnouncement();
      return;
    } catch (_) {
      // Fall through to error state.
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = "Failed to load notifications.";
    });
    _notifyUnreadCount();
  }

  void _maybeAutoOpenInitialAnnouncement() {
    final announcementId = widget.initialAnnouncementId;
    if (_autoOpenedInitial || announcementId == null || announcementId <= 0) {
      return;
    }

    final match = _items.cast<Map<String, dynamic>>().firstWhere(
          (item) => _announcementIdOf(item) == announcementId,
          orElse: () => const <String, dynamic>{},
        );
    if (match.isEmpty) {
      return;
    }

    _autoOpenedInitial = true;
    Future.microtask(() {
      if (!mounted) return;
      _openDetails(match);
    });
  }

  Future<void> _loadProfileImage() async {
    try {
      final payload = await BackendApi.getJson(
        'get_scholar_profile.php',
        query: {'user_id': widget.userId},
      );
      final profile =
          Map<String, dynamic>.from(payload['profile'] as Map? ?? const {});
      if (!mounted) return;
      setState(() {
        _profileImageUrl = ApiConfig.normalizeAssetUrl(
          profile['profile_image_url']?.toString(),
        );
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refresh() async {
    await _loadNotifications();
    await widget.onRefreshCount?.call();
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

  String _titleOf(Map<String, dynamic> item) {
    final explicitTitle = item['notification_title']?.toString().trim() ?? '';
    if (explicitTitle.isNotEmpty) return explicitTitle;

    final message = _stripAnnouncementMarker(item['message']?.toString() ?? '')
        .trim();
    final parts = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts.first;
    return 'Notification';
  }

  String _bodyOf(Map<String, dynamic> item) {
    final message = _stripAnnouncementMarker(item['message']?.toString() ?? '')
        .trim();
    if (message.isEmpty) return 'No details available.';

    final parts = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts.skip(1).join('\n');
    return message;
  }

  int? _announcementIdOf(Map<String, dynamic> item) {
    final raw = (item['message'] ?? '').toString();
    final parts = raw.split('\n');
    final firstLine = parts.isEmpty ? '' : parts.first.trim();
    if (!firstLine.toUpperCase().startsWith('ANNOUNCEMENT_ID:')) {
      return null;
    }
    final value = firstLine.substring('ANNOUNCEMENT_ID:'.length).trim();
    final id = int.tryParse(value);
    return (id != null && id > 0) ? id : null;
  }

  String _stripAnnouncementMarker(String message) {
    final lines = message.split('\n');
    if (lines.isEmpty) return message;
    final first = lines.first.trim();
    if (!first.toUpperCase().startsWith('ANNOUNCEMENT_ID:')) {
      return message;
    }
    return lines.skip(1).join('\n');
  }

  String _createdAtOf(Map<String, dynamic> item) {
    final value = item['created_at']?.toString().trim() ?? '';
    return value.isEmpty ? 'Unknown date' : value;
  }

  bool _isRead(Map<String, dynamic> item) {
    final readRaw = item['is_read'] ?? item['read'] ?? item['status'];
    final readValue = readRaw?.toString().toLowerCase();
    return readValue == '1' ||
        readValue == 'true' ||
        readValue == 'yes' ||
        readValue == 'read';
  }

  int _unreadCount() => _items.where((item) => !_isRead(item)).length;

  void _notifyUnreadCount() {
    widget.onUnreadCountChanged?.call(_unreadCount());
  }

  Future<void> _setReadState(Map<String, dynamic> item, bool read) async {
    final id = _notificationId(item);
    if (id.isEmpty) return;

    setState(() {
      final idx = _items.indexOf(item);
      if (idx != -1) {
        _items[idx] = {..._items[idx], 'is_read': read ? 1 : 0};
      }
    });
    _notifyUnreadCount();

    final endpoints = [
      Uri.parse("${_baseUrl}mark_notification_read.php"),
      Uri.parse("${_baseUrl}set_notification_read.php"),
      Uri.parse("${_baseUrl}update_notification_status.php"),
    ];

    for (final url in endpoints) {
      try {
        await http.post(url, body: {
          'notification_id': id,
          'user_id': widget.userId,
          'is_read': read ? '1' : '0',
          'status': read ? 'read' : 'unread',
        });
      } catch (_) {
        // Keep local state even if backend fallback fails.
      }
    }
  }

  Future<void> _setAllReadState(bool read) async {
    setState(() {
      _items = _items.map((e) => {...e, 'is_read': read ? 1 : 0}).toList();
    });
    _notifyUnreadCount();

    final endpoints = [
      Uri.parse("${_baseUrl}mark_all_notifications_read.php"),
      Uri.parse("${_baseUrl}set_all_notifications_read.php"),
      Uri.parse("${_baseUrl}update_all_notifications_status.php"),
    ];

    for (final url in endpoints) {
      try {
        await http.post(url, body: {
          'user_id': widget.userId,
          'is_read': read ? '1' : '0',
          'status': read ? 'read' : 'unread',
        });
      } catch (_) {
        // Keep local state even if backend fallback fails.
      }
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final id = _notificationId(item);
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'This will permanently remove the selected notification from your list.',
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

    setState(() => _busyId = id);

    try {
      final response = await http.post(
        Uri.parse("${_baseUrl}delete_notification.php"),
        body: {'notification_id': id},
      );

      final decoded = _tryDecodeJson(response.body);
      final success = response.statusCode == 200 &&
          (decoded is! Map<String, dynamic> ||
              decoded['success'] == true ||
              decoded['status']?.toString().toLowerCase() == 'success');

      if (!mounted) return;

      if (success) {
        setState(() {
          _busyId = null;
          _items.removeWhere((entry) => _notificationId(entry) == id);
        });
        _notifyUnreadCount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted.'),
            backgroundColor: Color(0xFF205C3B),
          ),
        );
      } else {
        setState(() => _busyId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded is Map<String, dynamic>
                  ? decoded['message']?.toString() ?? 'Delete failed.'
                  : 'Delete failed.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _toggleSelection(Map<String, dynamic> item) {
    final id = _notificationId(item);
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
          final id = _notificationId(item);
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
          'Delete ${_selectedIds.length} selected message(s)? This cannot be undone.',
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
        final response = await http.post(
          Uri.parse("${_baseUrl}delete_notification.php"),
          body: {'notification_id': id},
        );
        final decoded = _tryDecodeJson(response.body);
        final success = response.statusCode >= 200 &&
            response.statusCode < 300 &&
            (decoded is! Map<String, dynamic> ||
                decoded['success'] == true ||
                decoded['status']?.toString().toLowerCase() == 'success');
        if (success) {
          _items.removeWhere((entry) => _notificationId(entry) == id);
          _selectedIds.remove(id);
        }
      } catch (_) {
        // keep going
      }
    }

    if (!mounted) return;
    setState(() {
      _selectionMode = _selectedIds.isNotEmpty;
    });
    _notifyUnreadCount();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selected messages deleted.'),
        backgroundColor: Color(0xFF205C3B),
      ),
    );
  }

  Future<void> _replyTo(Map<String, dynamic> item) async {
    final replyController = TextEditingController();
    var visibility = 'admin';
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reply to ${_titleOf(item)}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bodyOf(item),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5A4A68),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: replyController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write your reply.',
                    filled: true,
                    fillColor: const Color(0xFFF7F3FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: visibility,
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
                    DropdownMenuItem(value: 'admin', child: Text('Admin only')),
                    DropdownMenuItem(value: 'all', child: Text('All scholars')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => visibility = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      final message = replyController.text.trim();
                      if (message.isEmpty) return;

                      setDialogState(() => isSending = true);
                      try {
                        final response = await http.post(
                          Uri.parse("${_baseUrl}save_reply.php"),
            body: {
              'notification_id': _notificationId(item),
              'message': message,
              'visibility': visibility,
              'user_id': widget.userId,
            },
                        );

                        final decoded = _tryDecodeJson(response.body);
                        final success = response.statusCode >= 200 &&
                            response.statusCode < 300 &&
                            (decoded is! Map<String, dynamic> ||
                                decoded['success'] == true ||
                                decoded['status']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'success');

                        if (!success) {
                          throw Exception(
                            decoded is Map<String, dynamic>
                                ? decoded['message']?.toString() ??
                                    'Reply failed.'
                                : 'Reply failed.',
                          );
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reply sent successfully.'),
                            backgroundColor: Color(0xFF205C3B),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setDialogState(() => isSending = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to send reply: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(isSending ? 'Sending...' : 'Send Reply'),
            ),
          ],
        ),
      ),
    );

    replyController.dispose();
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    if (!_isRead(item)) {
      await _setReadState(item, true);
    }
    if (!mounted) return;
    final thread = await _fetchThread(item);
    if (!mounted) return;

    final announcementId = _announcementIdOf(item);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationChatSheet(
        title: _titleOf(item),
        createdAt: _createdAtOf(item),
        profileImageUrl: _profileImageUrl,
        isAdminView: false,
        initialMessages: thread,
        onSendReply: (message) async {
          final response = announcementId != null
              ? await http.post(
                  Uri.parse("${_baseUrl}save_announcement_comment.php"),
                  body: {
                    'announcement_id': announcementId.toString(),
                    'message': message,
                    'user_id': widget.userId,
                  },
                )
              : await http.post(
                  Uri.parse("${_baseUrl}save_reply.php"),
                  body: {
                    'notification_id': _notificationId(item),
                    'message': message,
                    'visibility': 'Admin',
                    'user_id': widget.userId,
                  },
                );
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
    final announcementId = _announcementIdOf(item);
    if (announcementId != null) {
      try {
        final payload = await BackendApi.getJson(
          'get_announcement_thread.php',
          query: {'announcement_id': announcementId.toString()},
        );
        final announcement =
            Map<String, dynamic>.from(payload['announcement'] as Map? ?? const {});
        final commentsRaw = payload['comments'];
        final comments = commentsRaw is List
            ? commentsRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        final messages = <Map<String, dynamic>>[];
        final announcementBody = (announcement['message'] ?? '').toString().trim();
        final announcementCreated =
            (announcement['created_at'] ?? _createdAtOf(item)).toString();
        if (announcementBody.isNotEmpty) {
          messages.add({
            'message': announcementBody,
            'created_at': announcementCreated,
            'is_admin': true,
            'sender': 'Admin',
          });
        } else {
          messages.addAll(_fallbackThread(item, const []));
        }

        for (final comment in comments) {
          final msg = (comment['message'] ?? '').toString().trim();
          if (msg.isEmpty) continue;
          final sender = (comment['username'] ?? comment['sender'] ?? '')
              .toString()
              .trim();
          messages.add({
            'message': msg,
            'created_at': (comment['created_at'] ?? '').toString(),
            'is_admin': false,
            'sender': sender,
          });
        }

        return messages;
      } catch (_) {
        return _fallbackThread(item, const []);
      }
    }

    final id = _notificationId(item);
    if (id.isEmpty) {
      return _fallbackThread(item, const []);
    }

    try {
      final payload = await BackendApi.getJson(
        'get_replies.php',
        query: {'notification_id': id, 'user_id': widget.userId},
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

    final baseMessage = _bodyOf(item).trim();
    if (baseMessage.isNotEmpty) {
      messages.add({
        'message': baseMessage,
        'created_at': _createdAtOf(item),
        'is_admin': true,
        'sender': 'Admin',
      });
    }

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
        'is_admin': _replyIsAdmin(reply, widget.userId),
        'sender': reply['username']?.toString() ??
            reply['sender']?.toString() ??
            '',
        'reply_id': reply['reply_id']?.toString(),
      });
    }

    return messages;
  }

  bool _replyIsAdmin(Map<String, dynamic> reply, String userId) {
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
      return replyUserId != userId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount();
    final read = _items.length - unread;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummary(unread, read),
                            const SizedBox(height: 18),
                            _buildSectionTitle(),
                          ],
                        ),
                      ),
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
                        return _buildNotificationCard(_items[index ~/ 2]);
                      },
                      childCount: (_items.length * 2) - 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (_profileImageUrl != null &&
                        _profileImageUrl!.trim().isNotEmpty)
                    ? Image.network(
                        _profileImageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                      )
                    : const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track announcements, reply to messages, and manage your inbox.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  if (_lastUpdated != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last updated ${_formatTime(_lastUpdated!)}',
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
              onPressed: _isLoading ? null : _refresh,
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

  Widget _buildSummary(int unread, int read) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Total',
            _items.length.toString(),
            const Color(0xFF5B2C83),
            Icons.inbox_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Unread',
            unread.toString(),
            const Color(0xFFE08A00),
            Icons.mark_email_unread_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Read',
            read.toString(),
            const Color(0xFF1F7A55),
            Icons.mark_email_read_rounded,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF2B1A3A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
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
                'Open a card for full details, or manage your inbox directly here.',
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
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'read_all') {
                    await _setAllReadState(true);
                  } else if (value == 'unread_all') {
                    await _setAllReadState(false);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'read_all',
                    child: Text('Mark all as read'),
                  ),
                  PopupMenuItem(
                    value: 'unread_all',
                    child: Text('Mark all as unread'),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE1D6EB)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 18, color: Color(0xFF5F4B72)),
                      SizedBox(width: 8),
                      Text(
                        'Actions',
                        style: TextStyle(
                          color: Color(0xFF5F4B72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isRead = _isRead(item);
    final id = _notificationId(item);
    final isBusy = _busyId == id;
    final isSelected = _selectedIds.contains(id);

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
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7B1FA2)
                : isRead
                ? const Color(0xFFEAE2F2)
                : const Color(0xFFD7B8EA),
            width: isRead ? 1 : 1.4,
          ),
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isRead
                        ? const Color(0xFFF0EDF5)
                        : const Color(0xFFF5EAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          isRead
                              ? Icons.notifications_none_rounded
                              : Icons.notifications_active_rounded,
                          color: isRead
                              ? const Color(0xFF72617F)
                              : const Color(0xFF7B1FA2),
                        ),
                      ),
                      if (!isRead)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFD84343),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                            isRead ? 'Read' : 'Unread',
                            isRead
                                ? const Color(0xFF6B5A79)
                                : const Color(0xFF7B1FA2),
                          ),
                          _tagChip(_createdAtOf(item), const Color(0xFF6B5A79)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _bodyOf(item),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
                      : () => _replyTo(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F6B45),
                    side: const BorderSide(color: Color(0xFF9FD2B0)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Reply'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: isBusy || _selectionMode
                      ? null
                      : () => _deleteNotification(item),
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
              Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.red.shade400,
              ),
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
                onPressed: _refresh,
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
                'No notifications found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D0D44),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Announcements and replies sent to you will appear here.',
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

class _NotificationChatSheet extends StatefulWidget {
  const _NotificationChatSheet({
    required this.title,
    required this.createdAt,
    required this.profileImageUrl,
    required this.initialMessages,
    required this.onSendReply,
    required this.isAdminView,
  });

  final String title;
  final String createdAt;
  final String? profileImageUrl;
  final List<Map<String, dynamic>> initialMessages;
  final Future<void> Function(String message) onSendReply;
  final bool isAdminView;

  @override
  State<_NotificationChatSheet> createState() => _NotificationChatSheetState();
}

class _NotificationChatSheetState extends State<_NotificationChatSheet> {
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
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
      initialChildSize: 0.7,
      minChildSize: 0.4,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                  await widget.onSendReply(message);
                                  if (!mounted) return;
                                  setState(() {
                                    _messages.add({
                                      'message': message,
                                      'created_at':
                                          DateTime.now().toIso8601String(),
                                      'is_admin': false,
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
