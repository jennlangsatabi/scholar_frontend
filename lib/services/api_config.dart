import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _defaultApiRoot = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultApiRoot.isNotEmpty) {
      return _defaultApiRoot;
    }

    if (kIsWeb) {
      // On Windows, `localhost` often resolves to IPv6 (`::1`), while XAMPP/Apache
      // commonly listens only on IPv4. Using 127.0.0.1 avoids fetch failures.
      return 'http://127.0.0.1/scholar_php';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator must use host loopback alias.
        return 'http://10.0.2.2/scholar_php';
      default:
        return 'http://127.0.0.1/scholar_php';
    }
  }

  static Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/'), '');
    return Uri.parse(
      '$normalizedBase/$normalizedPath',
    ).replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }
}
