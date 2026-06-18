// lib/firebase_options.dart
// 本番環境設定（petit-works-apps-9029a）
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ─── Web ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyCkIt1e0hN8K3dl7HN2CoH_h95ztkNrgmg',
    appId:             '1:216377882454:web:c9d4f1f5e8b7a4c2',
    messagingSenderId: '216377882454',
    projectId:         'petit-works-apps-9029a',
    databaseURL:       'https://petit-works-apps-9029a-default-rtdb.asia-northeast1.firebasedatabase.app',
    storageBucket:     'petit-works-apps-9029a.firebasestorage.app',
  );

  // ─── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCkIt1e0hN8K3dl7HN2CoH_h95ztkNrgmg',
    appId:             '1:216377882454:android:67072520090e4812d108f7',
    messagingSenderId: '216377882454',
    projectId:         'petit-works-apps-9029a',
    databaseURL:       'https://petit-works-apps-9029a-default-rtdb.asia-northeast1.firebasedatabase.app',
    storageBucket:     'petit-works-apps-9029a.firebasestorage.app',
  );

  // ─── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyCkIt1e0hN8K3dl7HN2CoH_h95ztkNrgmg',
    appId:             '1:216377882454:ios:67072520090e4812',
    messagingSenderId: '216377882454',
    projectId:         'petit-works-apps-9029a',
    databaseURL:       'https://petit-works-apps-9029a-default-rtdb.asia-northeast1.firebasedatabase.app',
    storageBucket:     'petit-works-apps-9029a.firebasestorage.app',
    iosBundleId:       'com.petitWorks.shogiApp',
  );
}
