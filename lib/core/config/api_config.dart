/// URL du backend. Aucun secret ici.
/// En production, passer --dart-define=CITYCARE_API_URL=https://... (HTTPS).
library;

import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('CITYCARE_API_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      default:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }
}
