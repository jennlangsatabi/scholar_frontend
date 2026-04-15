import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensure these imports match your actual file names
import 'role_selection.dart';
import 'admin_login.dart';
import 'scholar_login.dart';
import 'admin_main.dart';
import 'scholar_main.dart';
import 'evaluation_form.dart';
import 'create_account_modal.dart';
import 'services/backend_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fall back to dart-define values when .env is not bundled.
  }
  runApp(const JMCFIScholarshipApp());
}

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
  Map<String, String>? _pendingGoogleAccount;

  @override
  void initState() {
    super.initState();
    _tryHandleOAuthCallback();
    BackendApi.warmUp();
    if (_pendingGoogleAccount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingGoogleAccount == null) return;
        _showCreateAccountModal(_pendingGoogleAccount!);
      });
    }
  }

  void _tryHandleOAuthCallback() {
    final qp = Uri.base.queryParameters;
    if (qp.isEmpty) {
      return;
    }

    final status = (qp['status'] ?? '').trim().toLowerCase();
    if (status != 'success' && status != 'pending_account') {
      return;
    }

    final role = (qp['role'] ?? '').trim().toLowerCase();
    final userId = (qp['user_id'] ?? qp['id'] ?? '').trim();
    final displayName =
        (qp['name'] ?? qp['email'] ?? '').trim().isNotEmpty
            ? (qp['name'] ?? qp['email'] ?? '').trim()
            : 'Scholar';
    final email = (qp['email'] ?? '').trim();

    if (status == 'pending_account') {
      currentState = PortalState.login;
      selectedRole = role == 'admin' ? 'Admin' : 'Scholar';
      currentUsername = displayName;
      if (role == 'admin') {
        currentAdminName = displayName;
      } else {
        selectedScholarType = (qp['scholarship_category'] ??
                qp['scholarship_type'] ??
                selectedScholarType)
            .trim();
        currentScholarCategory = selectedScholarType;
      }
      _pendingGoogleAccount = <String, String>{
        'name': displayName,
        'email': email.isNotEmpty ? email : displayName,
        'role': role,
        if (role == 'scholar') 'scholarship_category': selectedScholarType,
        if (userId.isNotEmpty) 'user_id': userId,
      };
      return;
    }

    if (userId.isEmpty) {
      if (status == 'success') {
        currentState = PortalState.login;
        selectedRole = role == 'admin' ? 'Admin' : 'Scholar';
        currentUsername = displayName;
        if (role == 'admin') {
          currentAdminName = displayName;
        }
        selectedScholarType = (qp['scholarship_category'] ??
                qp['scholarship_type'] ??
                selectedScholarType)
            .trim();
        currentScholarCategory = selectedScholarType;
        _pendingGoogleAccount = <String, String>{
          'name': displayName,
          'email': email.isNotEmpty ? email : displayName,
          'role': role,
          if (role == 'scholar')
            'scholarship_category': selectedScholarType,
        };
      }
      return;
    }

    if (role == 'admin') {
      setState(() {
        selectedRole = 'Admin';
        currentUserId = userId;
        currentAdminName = displayName;
        currentState = PortalState.adminDashboard;
      });
      return;
    }

    if (role == 'scholar') {
      final category = (qp['scholarship_category'] ?? qp['scholarship_type'] ?? '')
          .trim();
      setState(() {
        selectedRole = 'Scholar';
        currentUserId = userId;
        currentUsername = displayName;
        selectedScholarType =
            category.isNotEmpty ? category : 'Student Assistant Scholar';
        currentScholarCategory = category;
        currentState = PortalState.scholarDashboard;
      });
    }
  }

  Future<void> _showCreateAccountModal(Map<String, String> details) async {
    _pendingGoogleAccount = null;
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateAccountModal(
        initialName: details['name'] ?? '',
        initialEmail: details['email'] ?? '',
        initialScholarshipType:
            details['scholarship_category'] ?? selectedScholarType,
        initialRole: details['role'] ?? 'scholar',
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final role = (result['role'] ?? details['role'] ?? 'scholar')
        .trim()
        .toLowerCase();
    final displayName =
        (result['name'] ?? details['name'] ?? 'User').trim();
    final email = (result['email'] ?? details['email'] ?? '').trim();
    final scholarshipCategory =
        (result['scholarship_category'] ?? details['scholarship_category'] ?? '')
            .trim();

    setState(() {
      currentState = PortalState.login;
      selectedRole = role == 'admin' ? 'Admin' : 'Scholar';
      currentUsername = displayName;
      currentAdminName = displayName;
      if (scholarshipCategory.isNotEmpty) {
        selectedScholarType = _displayScholarshipType(scholarshipCategory);
        currentScholarCategory = scholarshipCategory;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request submitted for ${email.isNotEmpty ? email : displayName}. Wait for admin approval before logging in.',
        ),
      ),
    );
  }

  String _displayScholarshipType(String category) {
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
        return category.isNotEmpty ? category : 'Student Assistant Scholar';
    }
  }

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
