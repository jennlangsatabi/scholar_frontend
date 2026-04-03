import 'dart:ui';
import 'package:flutter/material.dart';

// Ensure these imports match your actual file names
import 'role_selection.dart';
import 'admin_login.dart';
import 'scholar_login.dart';
import 'admin_main.dart';
import 'scholar_main.dart';
import 'evaluation_form.dart';

void main() => runApp(const JMCFIScholarshipApp());

class JMCFIScholarshipApp extends StatelessWidget {
  const JMCFIScholarshipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JMCFI Scholarship System',
      theme: ThemeData(
        primaryColor: const Color(0xFF6A1B9A),
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const MainPortalPage(),
    );
  }
}

enum PortalState {
  roleSelection,
  login,
  adminDashboard,
  scholarDashboard,
  evaluationForm
}

class MainPortalPage extends StatefulWidget {
  const MainPortalPage({super.key});

  @override
  State<MainPortalPage> createState() => _MainPortalPageState();
}

class _MainPortalPageState extends State<MainPortalPage> {
  PortalState currentState = PortalState.roleSelection;
  String selectedRole = '';

  // State variables to hold logged-in user data
  String currentUserId = '';
  String currentUsername = '';
  String currentAdminName = 'Administrator';
  String selectedScholarType = 'Student Assistant Scholar';
  String currentScholarCategory = '';

  @override
  Widget build(BuildContext context) {
    // --- NAVIGATION LOGIC ---

    // 1. ADMIN ROUTE
    if (currentState == PortalState.adminDashboard) {
      return AdminMainSkeleton(
        onLogout: () =>
            setState(() => currentState = PortalState.roleSelection),
        adminName: currentAdminName,
      );
    }

    // 2. SCHOLAR ROUTE (Fixed: Passing required userId and username)
    if (currentState == PortalState.scholarDashboard) {
      return ScholarMainSkeleton(
        userId: currentUserId,
        username: currentUsername,
        scholarType: selectedScholarType,
        scholarshipCategory: currentScholarCategory,
        onLogout: () =>
            setState(() => currentState = PortalState.roleSelection),
      );
    }

    if (currentState == PortalState.evaluationForm) {
      return EvaluationFormScreen(
        onClose: () => setState(() => currentState = PortalState.roleSelection),
      );
    }

    // --- PORTAL (LOGIN/ROLE SELECTION) UI ---
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset('assets/jmcbg.jpg', fit: BoxFit.cover),
          ),

          // Global Purple Tint
          Positioned.fill(
            child: Container(color: const Color(0xFF3B125A).withOpacity(0.6)),
          ),

          // Center Branded Glass Card
          LayoutBuilder(
            builder: (context, viewport) {
              final isCompact = viewport.maxWidth < 600;
              final cardWidth = isCompact ? viewport.maxWidth - 32 : 480.0;
              final horizontalPadding = isCompact ? 24.0 : 32.0;
              final verticalPadding = isCompact ? 22.0 : 26.0;

              final content = Column(
                key: ValueKey<String>(currentState.toString()),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentState == PortalState.roleSelection)
                    RoleSelectionScreen(
                      key: const ValueKey('RoleSelect'),
                      onRoleSelected: (role) {
                        setState(() {
                          selectedRole = role;
                          currentState = PortalState.login;
                        });
                      },
                    )
                  else
                    (selectedRole == 'Admin'
                        ? AdminLoginScreen(
                            key: const ValueKey('AdminLogin'),
                            onLoginSuccess: (userData) {
                              setState(() {
                                currentUserId = userData['id'].toString();
                                currentAdminName =
                                    userData['name']?.toString() ??
                                        'Administrator';
                                currentState = PortalState.adminDashboard;
                              });
                            },
                            onBack: () => setState(
                                () => currentState = PortalState.roleSelection),
                          )
                        : ScholarLoginScreen(
                            key: const ValueKey('ScholarLogin'),
                            onLoginSuccess: (userData) {
                              setState(() {
                                currentUserId = userData['id'].toString();
                                currentUsername =
                                    userData['name']?.toString() ?? "Scholar";
                                selectedScholarType =
                                    userData['type']?.toString() ??
                                        "Student Assistant Scholar";
                                currentScholarCategory =
                                    userData['type']?.toString() ?? '';
                                currentState = userData['role'] == 'admin'
                                    ? PortalState.adminDashboard
                                    : PortalState.scholarDashboard;
                              });
                            },
                            onBack: () => setState(
                                () => currentState = PortalState.roleSelection),
                          )),
                  if (currentState == PortalState.roleSelection) ...[
                    const SizedBox(height: 18),
                    _GlassActionButton(
                      label: 'Evaluation Form',
                      icon: Icons.assignment_turned_in_rounded,
                      onTap: () =>
                          setState(() => currentState = PortalState.evaluationForm),
                    ),
                  ],
                ],
              );

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: cardWidth,
                          maxHeight: viewport.maxHeight - 32,
                        ),
                        child: Container(
                          width: cardWidth,
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
