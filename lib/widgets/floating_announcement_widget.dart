import 'dart:async';

import 'package:flutter/material.dart';

import '../services/backend_api.dart';
import '../services/api_config.dart';

class FloatingAnnouncementWidget extends StatefulWidget {
  final String userId;
  final String role;
  final String currentUserName;

  const FloatingAnnouncementWidget({
    super.key,
    required this.userId,
    required this.role,
    required this.currentUserName,
  });

  @override
  State<FloatingAnnouncementWidget> createState() =>
      _FloatingAnnouncementWidgetState();
}

class _FloatingAnnouncementWidgetState extends State<FloatingAnnouncementWidget> {
  static const double _minWidth = 320;
  static const double _minHeight = 360;
  static const double _maxWidth = 640;
  static const double _maxHeight = 760;

  Offset _position = const Offset(24, 120);
  Size _size = const Size(420, 560);
  bool _minimized = false;
  bool _loading = true;
  String? _error;

  Timer? _poller;

  List<Map<String, dynamic>> _announcements = <Map<String, dynamic>>[];
  final Set<int> _expanded = <int>{};
  final Map<int, List<Map<String, dynamic>>> _commentsByAnnouncement =
      <int, List<Map<String, dynamic>>>{};
  final Map<int, TextEditingController> _commentControllers =
      <int, TextEditingController>{};
  final Map<int, int?> _replyTargetByAnnouncement = <int, int?>{};
  final Map<int, bool> _sendingByAnnouncement = <int, bool>{};

  @override
  void initState() {
    super.initState();
    _loadAnnouncements(showLoader: true);
    _poller = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadAnnouncements(showLoader: false),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAnnouncements({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_announcements.php',
          query: {'user_id': widget.userId, 'limit': '40'},
          cacheTtl: Duration.zero,
          retries: 1,
        ),
      );

      if (!mounted) return;
      setState(() {
        _announcements = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load announcements: $e';
      });
    }
  }

  Future<void> _loadThread(int announcementId) async {
    try {
      final payload = await BackendApi.getJson(
        'get_announcement_thread.php',
        query: {
          'announcement_id': announcementId.toString(),
          'user_id': widget.userId,
        },
        cacheTtl: Duration.zero,
        retries: 1,
      );

      final rawComments = payload['comments'];
      final comments = rawComments is List
          ? rawComments
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _commentsByAnnouncement[announcementId] = comments;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load comments: $e')),
      );
    }
  }

  Future<void> _postComment(int announcementId) async {
    final controller = _commentControllers.putIfAbsent(
      announcementId,
      TextEditingController.new,
    );
    final message = controller.text.trim();
    if (message.isEmpty) return;

    final parentCommentId = _replyTargetByAnnouncement[announcementId];

    setState(() => _sendingByAnnouncement[announcementId] = true);
    try {
      await BackendApi.postForm(
        'save_announcement_comment.php',
        body: {
          'announcement_id': announcementId.toString(),
          'user_id': widget.userId,
          'message': message,
          if (parentCommentId != null && parentCommentId > 0)
            'parent_comment_id': parentCommentId.toString(),
        },
        retries: 1,
      );

      controller.clear();
      if (!mounted) return;
      setState(() => _replyTargetByAnnouncement[announcementId] = null);
      await _loadThread(announcementId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingByAnnouncement[announcementId] = false);
      }
    }
  }

  List<_CommentNode> _buildCommentTree(List<Map<String, dynamic>> comments) {
    final byParent = <int, List<Map<String, dynamic>>>{};
    final byId = <int, Map<String, dynamic>>{};

    for (final item in comments) {
      final id = int.tryParse((item['comment_id'] ?? '0').toString()) ?? 0;
      if (id > 0) {
        byId[id] = item;
      }
    }

    for (final item in comments) {
      final parentId =
          int.tryParse((item['parent_comment_id'] ?? '0').toString()) ?? 0;
      final key = parentId > 0 ? parentId : 0;
      byParent.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }

    _CommentNode buildNode(Map<String, dynamic> raw) {
      final id = int.tryParse((raw['comment_id'] ?? '0').toString()) ?? 0;
      final childrenRaw = byParent[id] ?? <Map<String, dynamic>>[];
      final children = childrenRaw.map(buildNode).toList();
      return _CommentNode(raw: raw, children: children);
    }

    final rootsRaw = <Map<String, dynamic>>[];
    for (final raw in comments) {
      final parentId =
          int.tryParse((raw['parent_comment_id'] ?? '0').toString()) ?? 0;
      if (parentId <= 0 || !byId.containsKey(parentId)) {
        rootsRaw.add(raw);
      }
    }

    return rootsRaw.map(buildNode).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAllowedWidth = constraints.maxWidth * 0.95;
        final maxAllowedHeight = constraints.maxHeight * 0.9;
        final widgetWidth = _size.width.clamp(_minWidth, maxAllowedWidth);
        final widgetHeight = _size.height.clamp(_minHeight, maxAllowedHeight);

        final maxLeft = (constraints.maxWidth - widgetWidth).clamp(0.0, double.infinity);
        final maxTop = (constraints.maxHeight - (_minimized ? 62.0 : widgetHeight))
            .clamp(0.0, double.infinity);

        final left = _position.dx.clamp(0.0, maxLeft);
        final top = _position.dy.clamp(0.0, maxTop);

        return Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            elevation: 24,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: widgetWidth,
              height: _minimized ? 62 : widgetHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5DDF0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildHeader(),
                      if (!_minimized) Expanded(child: _buildBody()),
                    ],
                  ),
                  if (!_minimized)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            final newWidth =
                                (_size.width + details.delta.dx).clamp(_minWidth, _maxWidth);
                            final newHeight = (_size.height + details.delta.dy)
                                .clamp(_minHeight, _maxHeight);
                            _size = Size(newWidth, newHeight);
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 18,
                            color: Color(0xFF7C6C8E),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _position = Offset(
            _position.dx + details.delta.dx,
            _position.dy + details.delta.dy,
          );
        });
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          gradient: LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Announcements',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _minimized = !_minimized),
              icon: Icon(
                _minimized ? Icons.open_in_full_rounded : Icons.minimize_rounded,
                color: Colors.white,
              ),
              tooltip: _minimized ? 'Maximize' : 'Minimize',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorState(_error!);
    }
    if (_announcements.isEmpty) {
      return _errorState('No announcements yet.');
    }

    return RefreshIndicator(
      onRefresh: () => _loadAnnouncements(showLoader: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final item = _announcements[index];
          return _buildAnnouncementCard(item);
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    final announcementId =
        int.tryParse((item['announcement_id'] ?? '0').toString()) ?? 0;
    final title = (item['title'] ?? 'Announcement').toString();
    final content = (item['content'] ?? item['message'] ?? '').toString();
    final createdAt = (item['created_at'] ?? '').toString();

    final expanded = _expanded.contains(announcementId);
    final comments = _commentsByAnnouncement[announcementId] ?? <Map<String, dynamic>>[];
    final tree = _buildCommentTree(comments);

    final commentController = _commentControllers.putIfAbsent(
      announcementId,
      TextEditingController.new,
    );
    final replyTarget = _replyTargetByAnnouncement[announcementId];
    final sending = _sendingByAnnouncement[announcementId] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFFE7D8F4),
                child: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF5A2D80)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D0D44),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _prettyTime(createdAt),
                      style: const TextStyle(
                        color: Color(0xFF7C6C8E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D0D44),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(color: Color(0xFF4A4157)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  if (expanded) {
                    setState(() => _expanded.remove(announcementId));
                  } else {
                    setState(() => _expanded.add(announcementId));
                    await _loadThread(announcementId);
                  }
                },
                icon: Icon(
                  expanded ? Icons.expand_less_rounded : Icons.comment_rounded,
                  color: const Color(0xFF6A1B9A),
                ),
                label: Text(
                  expanded ? 'Hide Comments' : 'Comments',
                  style: const TextStyle(
                    color: Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            if (tree.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'No comments yet.',
                  style: TextStyle(color: Color(0xFF7C6C8E), fontSize: 12),
                ),
              )
            else
              ...tree.map((node) => _buildCommentNode(announcementId, node, 0)),
            const SizedBox(height: 6),
            if (replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF6A1B9A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to comment #$replyTarget',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => _replyTargetByAnnouncement[announcementId] = null);
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      splashRadius: 14,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: replyTarget != null
                          ? 'Write a reply...'
                          : 'Write a comment...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F3FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: sending ? null : () => _postComment(announcementId),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentNode(int announcementId, _CommentNode node, int depth) {
    final raw = node.raw;
    final commentId = int.tryParse((raw['comment_id'] ?? '0').toString()) ?? 0;
    final name = (raw['display_name'] ?? raw['username'] ?? 'User').toString();
    final message = (raw['message'] ?? '').toString();
    final createdAt = (raw['created_at'] ?? '').toString();
    final avatarUrl =
        ApiConfig.normalizeAssetUrl(raw['profile_image_url']?.toString());

    final indent = (depth * 14).toDouble();

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAE1F4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFE5D7F2),
                  backgroundImage:
                      (avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl.isEmpty)
                      ? const Icon(Icons.person, size: 16, color: Color(0xFF6C4A89))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D0D44),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Text(
                            _prettyTime(createdAt),
                            style: const TextStyle(
                              color: Color(0xFF87779A),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF4A4157),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyTargetByAnnouncement[announcementId] = commentId;
                          });
                        },
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: Color(0xFF6A1B9A),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (node.children.isNotEmpty)
            ...node.children
                .map((child) => _buildCommentNode(announcementId, child, depth + 1)),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7C6C8E)),
        ),
      ),
    );
  }

  String _prettyTime(String raw) {
    if (raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} $hh:$mm $suffix';
  }
}

class _CommentNode {
  final Map<String, dynamic> raw;
  final List<_CommentNode> children;

  _CommentNode({
    required this.raw,
    required this.children,
  });
}


