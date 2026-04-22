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
import 'services/session_store.dart';

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
  String? _pendingNoticeMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _tryHandleOAuthCallback();
    BackendApi.warmUp();
    if (_pendingNoticeMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingNoticeMessage == null) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(_pendingNoticeMessage!)),
          );
        }
        _pendingNoticeMessage = null;
      });
    }
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
    if (status != 'success' &&
        status != 'pending_account' &&
        status != 'pending_admin_access') {
      return;
    }

    final role = (qp['role'] ?? '').trim().toLowerCase();
    final userId = (qp['user_id'] ?? qp['id'] ?? '').trim();
    final displayName =
        (qp['name'] ?? qp['email'] ?? '').trim().isNotEmpty
            ? (qp['name'] ?? qp['email'] ?? '').trim()
            : 'Scholar';
    final email = (qp['email'] ?? '').trim();

    if (status == 'pending_admin_access') {
      SessionStore.clear();
      currentState = PortalState.login;
      selectedRole = 'Admin';
      currentUsername = displayName;
      currentAdminName = displayName;
      _pendingGoogleAccount = null;
      _pendingNoticeMessage = (qp['message'] ?? '').trim().isNotEmpty
          ? (qp['message'] ?? '').trim()
          : 'Your Google admin access is waiting for approval from an existing admin.';
      return;
    }

    if (status == 'pending_account') {
      SessionStore.clear();
      currentState = PortalState.login;
      selectedRole = role == 'admin' ? 'Admin' : 'Scholar';
      currentUsername = displayName;
      if (role == 'admin') {
        currentAdminName = displayName;
      } else {
        final rawCategory =
            (qp['scholarship_category'] ?? qp['scholarship_type'] ?? '').trim();
        selectedScholarType = _displayScholarshipType(
          rawCategory.isNotEmpty ? rawCategory : selectedScholarType,
        );
        currentScholarCategory = rawCategory.isNotEmpty
            ? _toBackendScholarshipCategory(rawCategory)
            : _toBackendScholarshipCategory(selectedScholarType);
      }
      _pendingGoogleAccount = <String, String>{
        'name': displayName,
        'email': email.isNotEmpty ? email : displayName,
        'role': role,
        if (role == 'scholar')
          'scholarship_category': currentScholarCategory.isNotEmpty
              ? currentScholarCategory
              : _toBackendScholarshipCategory(selectedScholarType),
        if ((qp['google_id'] ?? '').trim().isNotEmpty)
          'google_id': (qp['google_id'] ?? '').trim(),
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
        final rawCategory =
            (qp['scholarship_category'] ?? qp['scholarship_type'] ?? '').trim();
        selectedScholarType = _displayScholarshipType(
          rawCategory.isNotEmpty ? rawCategory : selectedScholarType,
        );
        currentScholarCategory = rawCategory.isNotEmpty
            ? _toBackendScholarshipCategory(rawCategory)
            : _toBackendScholarshipCategory(selectedScholarType);
        _pendingGoogleAccount = <String, String>{
          'name': displayName,
          'email': email.isNotEmpty ? email : displayName,
          'role': role,
          if (role == 'scholar')
            'scholarship_category': currentScholarCategory.isNotEmpty
                ? currentScholarCategory
                : _toBackendScholarshipCategory(selectedScholarType),
          if ((qp['google_id'] ?? '').trim().isNotEmpty)
            'google_id': (qp['google_id'] ?? '').trim(),
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
      SessionStore.write(
        role: 'admin',
        userId: userId,
        adminName: displayName,
        username: displayName,
      );
      return;
    }

    if (role == 'scholar') {
      final category = (qp['scholarship_category'] ?? qp['scholarship_type'] ?? '')
          .trim();
      setState(() {
        selectedRole = 'Scholar';
        currentUserId = userId;
        currentUsername = displayName;
        selectedScholarType = _displayScholarshipType(
          category.isNotEmpty ? category : 'Student Assistant Scholar',
        );
        currentScholarCategory = _toBackendScholarshipCategory(category);
        currentState = PortalState.scholarDashboard;
      });
      SessionStore.write(
        role: 'scholar',
        userId: userId,
        username: displayName,
        scholarType: _displayScholarshipType(
          category.isNotEmpty ? category : 'Student Assistant Scholar',
        ),
        scholarshipCategory: _toBackendScholarshipCategory(category),
      );
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
        initialGoogleId: details['google_id'] ?? '',
        initialUserId: details['user_id'] ?? '',
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
    final userId = (result['user_id'] ?? '').trim();
    final scholarshipCategory =
        (result['scholarship_category'] ?? details['scholarship_category'] ?? '')
            .trim();
    final normalizedScholarshipCategory =
        _toBackendScholarshipCategory(scholarshipCategory);

    if (role == 'admin') {
      setState(() {
        currentState = PortalState.login;
        selectedRole = 'Admin';
        currentUsername = displayName;
        currentAdminName = displayName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Admin request submitted for ${email.isNotEmpty ? email : displayName}. Wait for approval before logging in.',
          ),
        ),
      );
      return;
    }

    setState(() {
      currentUserId = userId;
      currentState = PortalState.scholarDashboard;
      selectedRole = 'Scholar';
      currentUsername = displayName;
      if (scholarshipCategory.isNotEmpty) {
        selectedScholarType =
            _displayScholarshipType(normalizedScholarshipCategory);
        currentScholarCategory = normalizedScholarshipCategory;
      }
    });
    SessionStore.write(
      role: 'scholar',
      userId: userId,
      username: displayName,
      scholarType: selectedScholarType,
      scholarshipCategory: normalizedScholarshipCategory,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scholar account created successfully for ${email.isNotEmpty ? email : displayName}.',
        ),
      ),
    );
  }

  String _displayScholarshipType(String category) {
    switch (_toBackendScholarshipCategory(category)) {
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

  String _toBackendScholarshipCategory(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'student_assistant' ||
        (normalized.contains('student') && normalized.contains('assistant'))) {
      return 'student_assistant';
    }
    if (normalized == 'varsity') {
      return 'varsity';
    }
    if (normalized == 'academic') {
      return 'academic';
    }
    if (normalized == 'gift_of_education' || normalized.contains('gift')) {
      return 'gift_of_education';
    }
    return '';
  }

  void _restoreSession() {
    final session = SessionStore.read();
    final role = session['role']?.trim().toLowerCase() ?? '';
    final userId = session['user_id']?.trim() ?? '';
    if (role.isEmpty || userId.isEmpty) {
      return;
    }

    if (role == 'admin') {
      currentUserId = userId;
      currentAdminName =
          (session['admin_name']?.trim().isNotEmpty ?? false)
              ? session['admin_name']!.trim()
              : 'Administrator';
      currentUsername = currentAdminName;
      selectedRole = 'Admin';
      currentState = PortalState.adminDashboard;
      return;
    }

    if (role == 'scholar') {
      final scholarshipCategory =
          (session['scholarship_category'] ?? '').trim();
      final scholarType = (session['scholar_type'] ?? '').trim();
      currentUserId = userId;
      currentUsername = (session['username'] ?? '').trim().isNotEmpty
          ? session['username']!.trim()
          : 'Scholar';
      selectedRole = 'Scholar';
      currentScholarCategory = scholarshipCategory;
      selectedScholarType = scholarType.isNotEmpty
          ? scholarType
          : _displayScholarshipType(
              scholarshipCategory.isNotEmpty
                  ? scholarshipCategory
                  : 'Student Assistant Scholar',
            );
      currentState = PortalState.scholarDashboard;
    }
  }

  void _logoutToRoleSelection() {
    SessionStore.clear();
    setState(() {
      currentState = PortalState.roleSelection;
      selectedRole = '';
      currentUserId = '';
      currentUsername = '';
      currentAdminName = 'Administrator';
      selectedScholarType = 'Student Assistant Scholar';
      currentScholarCategory = '';
      _pendingGoogleAccount = null;
      _pendingNoticeMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- NAVIGATION LOGIC ---

    // 1. ADMIN ROUTE
    if (currentState == PortalState.adminDashboard) {
      return AdminMainSkeleton(
        onLogout: _logoutToRoleSelection,
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
        onLogout: _logoutToRoleSelection,
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
            child: Container(color: const Color(0xFF3B125A).withValues(alpha: 0.6)),
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
                              final userId = userData['id'].toString();
                              final adminName =
                                  userData['name']?.toString() ??
                                      'Administrator';
                              setState(() {
                                currentUserId = userId;
                                currentAdminName = adminName;
                                currentState = PortalState.adminDashboard;
                              });
                              SessionStore.write(
                                role: 'admin',
                                userId: userId,
                                adminName: adminName,
                                username: adminName,
                              );
                            },
                            onBack: () => setState(
                                () => currentState = PortalState.roleSelection),
                          )
                        : ScholarLoginScreen(
                            key: const ValueKey('ScholarLogin'),
                            onLoginSuccess: (userData) {
                              final userId = userData['id'].toString();
                              final username =
                                  userData['name']?.toString() ?? "Scholar";
                              final scholarType =
                                  userData['type']?.toString() ??
                                      "Student Assistant Scholar";
                              final scholarshipCategory = userData[
                                          'scholarship_category']
                                      ?.toString() ??
                                  _toBackendScholarshipCategory(
                                    userData['type']?.toString() ?? '',
                                  );
                              setState(() {
                                currentUserId = userId;
                                currentUsername = username;
                                selectedScholarType = scholarType;
                                currentScholarCategory = scholarshipCategory;
                                currentState = userData['role'] == 'admin'
                                    ? PortalState.adminDashboard
                                    : PortalState.scholarDashboard;
                              });
                              SessionStore.write(
                                role: 'scholar',
                                userId: userId,
                                username: username,
                                scholarType: scholarType,
                                scholarshipCategory: scholarshipCategory,
                              );
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
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
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
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
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

