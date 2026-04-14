import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get apiBaseUrl {
    final runtime = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;

    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
  }

  static String get googleOAuthUrl {
    final runtime = dotenv.env['GOOGLE_OAUTH_URL']?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;

    return const String.fromEnvironment(
      'GOOGLE_OAUTH_URL',
      defaultValue: '',
    );
  }

  static String get supabaseUrl {
    final runtime = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;

    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
  }

  static String get supabaseAnonKey {
    final runtime = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;

    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
  }

  static bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;
  static bool get hasGoogleOAuthUrl => googleOAuthUrl.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
