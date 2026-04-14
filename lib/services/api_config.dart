import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final webHost = Uri.base.host.toLowerCase();
      final isLocalWebDev = webHost == 'localhost' || webHost == '127.0.0.1';

      // For `flutter run -d chrome`, force local PHP to avoid CORS pain with
      // remote backends and random localhost dev ports.
      if (isLocalWebDev) {
        return 'http://127.0.0.1/scholar_php';
      }

      if (AppEnv.hasApiBaseUrl) {
        return AppEnv.apiBaseUrl;
      }

      // On Windows, `localhost` often resolves to IPv6 (`::1`), while XAMPP/Apache
      // commonly listens only on IPv4. Using 127.0.0.1 avoids fetch failures.
      return 'http://127.0.0.1/scholar_php';
    }

    if (AppEnv.hasApiBaseUrl) {
      return AppEnv.apiBaseUrl;
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
      final host = parsed.host.toLowerCase();
      final isLoopbackHost =
          host == 'localhost' || host == '127.0.0.1' || host == '::1';

      if (isLoopbackHost && parsed.host != base.host) {
        return parsed
            .replace(
              scheme: forcedScheme,
              host: base.host,
              port: base.hasPort ? base.port : null,
            )
            .toString();
      }

      return parsed.replace(scheme: forcedScheme).toString();
    }

    final basePath = base.path.replaceAll(RegExp(r'^/+|/+$'), '');
    final withTrailingSlash = base.path.endsWith('/')
        ? base
        : base.replace(path: '${base.path}/');
    final origin = Uri.parse(base.origin);

    var normalizedPath = value.replaceAll('\\', '/').trim();
    final lowerPath = normalizedPath.toLowerCase();

    // Some backends return local Windows file paths. Convert those into
    // web-facing paths anchored to /scholar_php or /uploads when possible.
    final scholarPhpIndex = lowerPath.lastIndexOf('/scholar_php/');
    if (scholarPhpIndex >= 0) {
      normalizedPath = normalizedPath.substring(scholarPhpIndex);
    } else {
      final uploadsIndex = lowerPath.lastIndexOf('/uploads/');
      if (uploadsIndex >= 0) {
        normalizedPath = normalizedPath.substring(uploadsIndex);
      }
    }

    if (normalizedPath.startsWith('/')) {
      if (basePath.isNotEmpty &&
          (normalizedPath.startsWith('/uploads/') ||
              normalizedPath.startsWith('/serve_file.php'))) {
        return origin.resolve('/$basePath$normalizedPath').toString();
      }
      return origin.resolve(normalizedPath).toString();
    }

    if (basePath.isNotEmpty &&
        (normalizedPath == basePath ||
            normalizedPath.startsWith('$basePath/'))) {
      return origin.resolve('/$normalizedPath').toString();
    }

    return withTrailingSlash.resolve(normalizedPath).toString();
  }
}
