// File generated for Firebase project: mediconnect-26
// Database URL: https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app
//
// ⚠️  HOW TO FILL IN YOUR CREDENTIALS:
//    1. Go to https://console.firebase.google.com → select "mediconnect-26"
//    2. Click Project Settings (gear icon) → Your apps → Android
//    3. Download google-services.json and place it in android/app/
//    4. Copy the values below from that file:
//       apiKey        → client[0].api_key[0].current_key
//       appId         → client[0].client_info.mobilesdk_app_id
//       messagingSenderId → project_info.project_number
//
// Alternatively, run: dart pub global activate flutterfire_cli
//                 then: flutterfire configure --project=mediconnect-26
// That command auto-generates this file with all correct values.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android ────────────────────────────────────────────────────────────────
  // Values sourced from: android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAS1txeJ0S3aH_JSZ3It4nsIoVIAFZThz4',
    appId: '1:12644297251:android:67224f39998acf277e1f96',
    messagingSenderId: '12644297251',
    projectId: 'mediconnect-26',
    storageBucket: 'mediconnect-26.firebasestorage.app',
    databaseURL:
        'https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // ── iOS ────────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    // TODO: Replace with values from ios/Runner/GoogleService-Info.plist
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'mediconnect-26',
    storageBucket: 'mediconnect-26.firebasestorage.app',
    databaseURL:
        'https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app',
    iosBundleId: 'com.mediconnect.mediconnect',
  );

  // ── macOS ──────────────────────────────────────────────────────────────────
  static const FirebaseOptions macos = FirebaseOptions(
    // TODO: Replace with values from macOS Firebase app
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'mediconnect-26',
    storageBucket: 'mediconnect-26.firebasestorage.app',
    databaseURL:
        'https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app',
    iosBundleId: 'com.mediconnect.mediconnect',
  );

  // ── Web ────────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAS1txeJ0S3aH_JSZ3It4nsIoVIAFZThz4',
    appId: '1:12644297251:android:67224f39998acf277e1f96',
    messagingSenderId: '12644297251',
    projectId: 'mediconnect-26',
    storageBucket: 'mediconnect-26.firebasestorage.app',
    databaseURL:
        'https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app',
    authDomain: 'mediconnect-26.firebaseapp.com',
  );

  // ── Windows ────────────────────────────────────────────────────────────────
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAS1txeJ0S3aH_JSZ3It4nsIoVIAFZThz4',
    appId: '1:12644297251:android:67224f39998acf277e1f96',
    messagingSenderId: '12644297251',
    projectId: 'mediconnect-26',
    storageBucket: 'mediconnect-26.firebasestorage.app',
    databaseURL:
        'https://mediconnect-26-default-rtdb.asia-southeast1.firebasedatabase.app',
    authDomain: 'mediconnect-26.firebaseapp.com',
  );
}
