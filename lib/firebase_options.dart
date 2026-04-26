// Generated from android/app/google-services.json
// Project: luma-app-50cee | Package: com.example.my_luma

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured yet.');
      default:
        throw UnsupportedError(
            '${defaultTargetPlatform.name} is not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    // mobilesdk_app_id from google-services.json → client[0].client_info
    appId: '1:649320334805:android:f3385e15961c4f9633e95c',
    // client[0].api_key[0].current_key
    apiKey: 'AIzaSyBrSkcEzJnF7gONN6skA7i5VXjJ4HBLtag',
    // project_info.project_id
    projectId: 'luma-app-50cee',
    // project_info.project_number
    messagingSenderId: '649320334805',
    // project_info.storage_bucket
    storageBucket: 'luma-app-50cee.firebasestorage.app',
  );
}
