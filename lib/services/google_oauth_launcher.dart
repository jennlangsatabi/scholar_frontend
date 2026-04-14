import 'package:url_launcher/url_launcher.dart';

import '../config/app_env.dart';

class GoogleOAuthLauncher {
  static Uri? buildAuthUri({required String portalRole}) {
    if (!AppEnv.hasGoogleOAuthUrl) {
      return null;
    }

    final baseUri = Uri.parse(AppEnv.googleOAuthUrl);
    final mergedQuery = <String, String>{...baseUri.queryParameters};
    mergedQuery['role'] = portalRole.toLowerCase().trim();

    return baseUri.replace(queryParameters: mergedQuery);
  }

  static Future<bool> launch({required String portalRole}) async {
    final uri = buildAuthUri(portalRole: portalRole);
    if (uri == null) {
      return false;
    }

    if (!await canLaunchUrl(uri)) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
