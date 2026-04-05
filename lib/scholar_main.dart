import 'package:flutter/material.dart';
import 'dart:async';

// --- IMPORT YOUR EXISTING SCREENS ---
import 'varsity_dashboard.dart';
import 'academic_dashboard.dart';
import 'gift_of_education_dashboard.dart';
import 'student_assistant_dashboard.dart';
import 'profile.dart'; // Student Assistant Profile
import 'varsity_profile.dart'; // Varsity Profile
import 'academic_profile.dart'; // Academic Profile
import 'upload_files.dart';
import 'notification.dart';
import 'services/backend_api.dart';
import 'services/api_config.dart';

class ScholarMainSkeleton extends StatefulWidget {
  final String scholarType;
  final String userId; // Essential for DB queries
  final String username; // For the personalized header
  final VoidCallback onLogout;
  final String? scholarshipCategory; // canonical backend category

  const ScholarMainSkeleton({
    super.key,
    required this.scholarType,
    required this.userId,
    required this.username,
    required this.onLogout,
    this.scholarshipCategory,
  });

  @override
  State<ScholarMainSkeleton> createState() => _ScholarMainSkeletonState();
}

class _ScholarMainSkeletonState extends State<ScholarMainSkeleton> {
  // Sets the default page to 'Dashboard'
  String activePage = 'Dashboard';
  int _unreadAnnouncements = 0;
  String? _profileImageUrl;
  Map<String, dynamic>? _announcementToast;
  int? _lastToastAnnouncementId;
  int? _openAnnouncementId;
  Timer? _toastTimer;
  Timer? _announcementPollTimer;

  static const double _drawerBreakpoint = 900;

  @override
  void initState() {
    super.initState();
    _loadUnreadAnnouncements();
    _loadProfileImage();
    _announcementPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadUnreadAnnouncements(),
    );
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _announcementPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadAnnouncements() async {
    try {
      final items = await BackendApi.unwrapList(
        BackendApi.getJson(
          'get_notifications.php',
          query: {'user_id': widget.userId, 'limit': '80'},
          cacheTtl: Duration.zero,
          retries: 1,
        ),
      );
      final unreadItems = items.where((item) {
        final readValue =
            (item['is_read'] ?? item['read'] ?? '').toString().toLowerCase();
        return !(readValue == '1' ||
            readValue == 'true' ||
            readValue == 'yes' ||
            readValue == 'read');
      }).toList(growable: false);
      final unread = unreadItems.length;

      final latestAnnouncement = unreadItems.cast<Map<String, dynamic>>().firstWhere(
            (item) => _announcementIdFromMessage((item['message'] ?? '').toString()) != null,
            orElse: () => const <String, dynamic>{},
          );
      if (latestAnnouncement.isNotEmpty) {
        final id = _announcementIdFromMessage(
          (latestAnnouncement['message'] ?? '').toString(),
        );
        if (id != null && id > 0 && id != _lastToastAnnouncementId) {
          _lastToastAnnouncementId = id;
          _showAnnouncementToast(latestAnnouncement);
        }
      }
      if (mounted) {
        setState(() => _unreadAnnouncements = unread);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unreadAnnouncements = 0);
      }
    }
  }

  int? _announcementIdFromMessage(String message) {
    final lines = message.split('\n');
    if (lines.isEmpty) return null;
    final first = lines.first.trim();
    if (!first.toUpperCase().startsWith('ANNOUNCEMENT_ID:')) return null;
    final raw = first.substring('ANNOUNCEMENT_ID:'.length).trim();
    final id = int.tryParse(raw);
    return (id != null && id > 0) ? id : null;
  }

  String _announcementTitleFromMessage(String message) {
    final lines = message.split('\n').map((e) => e.trim()).toList();
    if (lines.isEmpty) return 'Announcement';
    var idx = 0;
    if (lines.first.toUpperCase().startsWith('ANNOUNCEMENT_ID:')) {
      idx = 1;
    }
    if (idx < lines.length && lines[idx].isNotEmpty) return lines[idx];
    return 'Announcement';
  }

  void _showAnnouncementToast(Map<String, dynamic> item) {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _announcementToast = item);
    _toastTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      setState(() => _announcementToast = null);
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
      // ignore; keep default avatar
    }
  }

  /// --- NAVIGATION ROUTING LOGIC ---
  /// This method maps the sidebar selection to the corresponding widget
  Widget _getPageContent() {
    // Normalize category/type for routing
    String canon(String raw) {
      final t = raw.toLowerCase();
      if (t.contains('student') && t.contains('assistant')) return 'student_assistant';
      if (t.contains('varsity')) return 'varsity';
      if (t.contains('academic')) return 'academic';
      if (t.contains('gift')) return 'gift';
      return '';
    }

    final normalized = canon(widget.scholarshipCategory ?? widget.scholarType);

    // 1. DASHBOARD LOGIC (Varies by Scholar Type)
    if (activePage == 'Dashboard') {
      if (normalized == 'student_assistant') {
        return StudentAssistantDashboard(userId: widget.userId);
      }
      if (normalized == 'varsity') {
        return VarsityDashboard(userId: widget.userId);
      }
      if (normalized == 'gift') {
        return GiftOfEducationDashboard(userId: widget.userId);
      }
      // default academic for academic/unknown
      return AcademicDashboard(userId: widget.userId);
    }

    // 2. PROFILE LOGIC (Varies by Scholar Type)
    if (activePage == 'Profile') {
      if (normalized == 'student_assistant') {
        return ProfileScreen(userId: widget.userId);
      }
      if (normalized == 'varsity') {
        return VarsityProfileScreen(userId: widget.userId);
      }
      if (normalized == 'academic') {
        return AcademicProfileScreen(userId: widget.userId);
      }
      if (normalized == 'gift') {
        return ProfileScreen(userId: widget.userId);
      }
      return ProfileScreen(userId: widget.userId);
    }

    // 3. GENERAL PAGES (Same for everyone)
    switch (activePage) {
      case 'Upload Files':
        return UploadFilesPage(userId: widget.userId);
      case 'Notification':
        return NotificationScreen(
          userId: widget.userId,
          onRefreshCount: _loadUnreadAnnouncements,
          onUnreadCountChanged: (count) {
            if (mounted) {
              setState(() => _unreadAnnouncements = count);
            }
          },
          initialAnnouncementId: _openAnnouncementId,
        );
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < _drawerBreakpoint;

        Widget buildMainContent({VoidCallback? onOpenMenu}) {
          return Stack(
            children: [
              Column(
                children: [
                  _buildWelcomeHeader(
                    "Welcome, ${widget.username}!",
                    showMenu: useDrawer,
                    onMenuPressed: onOpenMenu,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _getPageContent(),
                    ),
                  ),
                ],
              ),
              if (_announcementToast != null)
                Positioned(
                  top: 14,
                  right: 16,
                  child: _AnnouncementToast(
                    title: _announcementTitleFromMessage(
                      (_announcementToast!['message'] ?? '').toString(),
                    ),
                    onClose: () {
                      if (!mounted) return;
                      setState(() => _announcementToast = null);
                    },
                    onView: () {
                      final id = _announcementIdFromMessage(
                        (_announcementToast!['message'] ?? '').toString(),
                      );
                      if (id != null) {
                        setState(() {
                          _openAnnouncementId = id;
                          activePage = 'Notification';
                          _announcementToast = null;
                        });
                      } else {
                        setState(() {
                          activePage = 'Notification';
                          _announcementToast = null;
                        });
                      }
                    },
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3E5F5),
          drawerEnableOpenDragGesture: true,
          drawer: useDrawer
              ? Drawer(child: _buildSidebarContent(isDrawer: true))
              : null,
          body: useDrawer
              ? Builder(
                  builder: (scaffoldContext) => buildMainContent(
                    onOpenMenu: () => Scaffold.of(scaffoldContext).openDrawer(),
                  ),
                )
              : Row(
                  children: [
                    _buildSidebar(),
                    Expanded(child: buildMainContent()),
                  ],
                ),
        );
      },
    );
  }

  /// --- SIDEBAR WIDGET ---
  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF3B125A),
      child: _buildSidebarContent(isDrawer: false),
    );
  }

  Widget _buildSidebarContent({required bool isDrawer}) {
    final content = Container(
      color: const Color(0xFF3B125A),
      child: Column(
        children: [
          SizedBox(height: isDrawer ? 20 : 40),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/jmclogo.png',
              height: 60,
              width: 60,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.school, size: 40, color: Color(0xFF3B125A)),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Scholar\nManagement',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navItem(Icons.grid_view_rounded, 'Dashboard',
                    closeDrawer: isDrawer),
                _navItem(Icons.person_outline, 'Profile', closeDrawer: isDrawer),
                _navItem(Icons.upload_file, 'Upload Files',
                    closeDrawer: isDrawer),
                _navItem(Icons.notifications_none, 'Notification',
                    closeDrawer: isDrawer),
              ],
            ),
          ),
          const Divider(color: Colors.white24, indent: 20, endIndent: 20),
          _navItem(Icons.logout, 'Logout',
              isLogout: true, closeDrawer: isDrawer),
          _buildSystemUserSection(),
        ],
      ),
    );

    return isDrawer ? SafeArea(child: content) : content;
  }

  /// --- NAVIGATION ITEM BUILDER ---
  Widget _navItem(
    IconData icon,
    String label, {
    bool isLogout = false,
    bool closeDrawer = false,
  }) {
    bool isActive = activePage == label;
    return ListTile(
      // Highlight the active menu item
      tileColor: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
      leading: _buildNavIcon(icon, label, isActive),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFFFFD54F) : Colors.white,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        if (closeDrawer) {
          Navigator.of(context).pop();
        }
        if (isLogout) {
          _confirmLogout();
        } else {
          setState(() => activePage = label);
        }
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content:
            const Text("Are you sure you want to exit the scholar panel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, bool isActive) {
    final baseIcon = Icon(
      icon,
      color: isActive ? const Color(0xFFFFD54F) : Colors.white70,
      size: 22,
    );

    if (label != 'Notification' || _unreadAnnouncements <= 0) {
      return baseIcon;
    }

    final badgeText =
        _unreadAnnouncements > 99 ? '99+' : _unreadAnnouncements.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// --- HEADER WIDGET ---
  Widget _buildWelcomeHeader(
    String msg, {
    bool showMenu = false,
    VoidCallback? onMenuPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final fontSize = compact ? 20.0 : 28.0;
        final topPadding = compact ? 18.0 : 35.0;
        final menuInset = showMenu ? 48.0 : 0.0;
        final leftPadding = (compact ? 16.0 : 25.0) + menuInset;

        return Container(
          height: 110,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/jmcbg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: const Color(0xFF9C27B0).withOpacity(0.7),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: leftPadding, top: topPadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        msg,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFFFEB3B),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (showMenu)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            tooltip: 'Menu',
                            onPressed: onMenuPressed,
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

  /// --- USER PROFILE MINI-CARD (BOTTOM SIDEBAR) ---
  Widget _buildSystemUserSection() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 30),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            backgroundImage: (_profileImageUrl != null &&
                    _profileImageUrl!.isNotEmpty)
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.scholarType,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementToast extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback onView;

  const _AnnouncementToast({
    required this.title,
    required this.onClose,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1D6EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'New Announcement',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D0D44),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  splashRadius: 18,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4A148C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('View'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
