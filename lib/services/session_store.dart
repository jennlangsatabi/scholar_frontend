import 'session_store_stub.dart'
    if (dart.library.html) 'session_store_web.dart' as impl;

class SessionStore {
  static const String _roleKey = 'scholar_session_role';
  static const String _userIdKey = 'scholar_session_user_id';
  static const String _usernameKey = 'scholar_session_username';
  static const String _adminNameKey = 'scholar_session_admin_name';
  static const String _scholarTypeKey = 'scholar_session_scholar_type';
  static const String _scholarshipCategoryKey =
      'scholar_session_scholarship_category';
  static const String _supervisorIdKey = 'scholar_session_supervisor_user_id';
  static const String _supervisorNameKey = 'scholar_session_supervisor_name';
  static const String _supervisorTokenKey = 'scholar_session_supervisor_token';

  static Map<String, String> read() {
    return {
      'role': impl.read(_roleKey),
      'user_id': impl.read(_userIdKey),
      'username': impl.read(_usernameKey),
      'admin_name': impl.read(_adminNameKey),
      'scholar_type': impl.read(_scholarTypeKey),
      'scholarship_category': impl.read(_scholarshipCategoryKey),
      'supervisor_user_id': impl.read(_supervisorIdKey),
      'supervisor_name': impl.read(_supervisorNameKey),
      'supervisor_token': impl.read(_supervisorTokenKey),
    };
  }

  static void write({
    required String role,
    required String userId,
    String username = '',
    String adminName = '',
    String scholarType = '',
    String scholarshipCategory = '',
    String supervisorUserId = '',
    String supervisorName = '',
    String supervisorToken = '',
  }) {
    impl.write(_roleKey, role);
    impl.write(_userIdKey, userId);
    impl.write(_usernameKey, username);
    impl.write(_adminNameKey, adminName);
    impl.write(_scholarTypeKey, scholarType);
    impl.write(_scholarshipCategoryKey, scholarshipCategory);
    impl.write(_supervisorIdKey, supervisorUserId);
    impl.write(_supervisorNameKey, supervisorName);
    impl.write(_supervisorTokenKey, supervisorToken);
  }

  static void clear() {
    impl.remove(_roleKey);
    impl.remove(_userIdKey);
    impl.remove(_usernameKey);
    impl.remove(_adminNameKey);
    impl.remove(_scholarTypeKey);
    impl.remove(_scholarshipCategoryKey);
    impl.remove(_supervisorIdKey);
    impl.remove(_supervisorNameKey);
    impl.remove(_supervisorTokenKey);
  }
}
