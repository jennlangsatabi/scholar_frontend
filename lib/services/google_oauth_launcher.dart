import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_env.dart';
import 'api_config.dart';

class GoogleOAuthLauncher {
  static Uri? buildAuthUri({required String portalRole}) {
    Uri baseUri;

    if (kIsWeb) {
      final webHost = Uri.base.host.toLowerCase();
      final isLocalWebDev = webHost == 'localhost' || webHost == '127.0.0.1';
      if (isLocalWebDev) {
        baseUri = ApiConfig.uri('google_oauth_start.php');
      } else if (AppEnv.hasGoogleOAuthUrl) {
        baseUri = Uri.parse(AppEnv.googleOAuthUrl);
      } else {
        baseUri = ApiConfig.uri('google_oauth_start.php');
      }
    } else {
      if (AppEnv.hasGoogleOAuthUrl) {
        baseUri = Uri.parse(AppEnv.googleOAuthUrl);
      } else {
        baseUri = ApiConfig.uri('google_oauth_start.php');
      }
    }

    final mergedQuery = <String, String>{...baseUri.queryParameters};
    mergedQuery['role'] = portalRole.toLowerCase().trim();
    if (kIsWeb && Uri.base.origin.isNotEmpty) {
      mergedQuery['success_url'] = Uri.base.origin;
    }

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

    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_self');
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
