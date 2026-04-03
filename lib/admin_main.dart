import 'package:flutter/material.dart';
import 'package:scholar_flutter/admin_managescholar.dart';
import 'admin_dashboard.dart';
import 'verification.dart';
import 'monitoring.dart';
import 'reports.dart';
import 'announcement.dart';
import 'admin_notification.dart'; // Added the missing import

class AdminMainSkeleton extends StatefulWidget {
  final VoidCallback onLogout;
  final String adminName;

  const AdminMainSkeleton({
    super.key,
    required this.onLogout,
    required this.adminName,
  });

  @override
  State<AdminMainSkeleton> createState() => _AdminMainSkeletonState();
}

class _AdminMainSkeletonState extends State<AdminMainSkeleton> {
  static const double _desktopBreakpoint = 900;

  // Track the current active page
  String activePage = 'Dashboard';

  // Map labels to their respective View Widgets
  Widget _getPageContent() {
    switch (activePage) {
      case 'Dashboard':
        return const AdminDashboardView();
      case 'Manage Scholar':
        return ManageScholarScreen();
      case 'Verification':
        return const VerificationScreen();
      case 'Monitoring':
        return const MonitoringScreen();
      case 'Notifications': // Added the case for the new module
        return const AdminNotificationScreen();
      case 'Reports':
        return const ReportsScreen();
      case 'Announcements':
        return const AnnouncementScreen();
      default:
        return const AdminDashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Scaffold(
          drawer: isDesktop ? null : Drawer(child: _buildSidebarContent()),
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 260,
                    child: _buildSidebarContent(),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(isDesktop: isDesktop),
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF3F2F7),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey<String>(activePage),
                              child: _getPageContent(),
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
      },
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSidebarContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3B125A),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildSidebarLogo(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navItem(Icons.grid_view_rounded, 'Dashboard'),
                _navItem(Icons.group_rounded, 'Manage Scholar'),
                _navItem(Icons.verified_user_rounded, 'Verification'),
                _navItem(Icons.analytics_rounded, 'Monitoring'),
                _navItem(Icons.notifications_active_rounded, 'Notifications'),
                _navItem(Icons.assessment_rounded, 'Reports'),
                _navItem(Icons.campaign_rounded, 'Announcements'),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _navItem(Icons.logout_rounded, 'Logout', isLogout: true),
          _buildAdminUserFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Image.asset(
              'assets/jmclogo.png',
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.school, size: 40, color: Color(0xFF3B125A)),
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'SCHOLARSHIP SYSTEM',
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool isDesktop}) {
    final titleSize = isDesktop ? 26.0 : 20.0;

    return Container(
      height: isDesktop ? 100 : 88,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/jmcbg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: const Color(0xFF3B125A).withOpacity(0.85),
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30 : 16),
        child: Row(
          children: [
            if (!isDesktop)
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  tooltip: 'Open navigation',
                ),
              ),
            if (!isDesktop) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activePage.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, letterSpacing: 2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Welcome, ${widget.adminName}",
                    style: TextStyle(
                      color: const Color(0xFFFFEB3B),
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool isLogout = false}) {
    bool isActive = activePage == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(
            icon,
            color: isActive ? const Color(0xFFFFEB3B) : Colors.white70,
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFFEB3B) : Colors.white,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isActive
              ? const Icon(Icons.arrow_right, color: Color(0xFFFFEB3B))
              : null,
          onTap: () {
            if (isLogout) {
              _confirmLogout();
            } else {
              setState(() => activePage = label);
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to exit the admin panel?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
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

  Widget _buildAdminUserFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFFFEB3B),
            child: Icon(Icons.admin_panel_settings,
                color: Color(0xFF3B125A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.adminName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'System Administrator',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
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
