import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

class ApiConfig {
  static String get baseUrl {
    if (AppEnv.hasApiBaseUrl) {
      return AppEnv.apiBaseUrl;
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

  static String normalizeAssetUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    final base = Uri.parse(baseUrl);

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final parsed = Uri.tryParse(value);
      if (parsed == null) {
        return value;
      }

      final forcedScheme = base.scheme.isNotEmpty ? base.scheme : 'https';
      return parsed.replace(scheme: forcedScheme).toString();
    }

    final normalizedPath = value.replaceAll('\\', '/').replaceFirst(
      RegExp(r'^/?'),
      '',
    );
    return base.resolve(normalizedPath).toString();
  }
}
