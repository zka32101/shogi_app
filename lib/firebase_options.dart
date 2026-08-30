// lib/firebase_options.dart
// 本番環境設定（petit-works-games）
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
    apiKey:            'AIzaSyCdIuk0UifwgliMGDdU-06TwUsvkJESPc0',
    appId:             '1:250444577503:web:38cb968cde213222c1476a',
    messagingSenderId: '250444577503',
    projectId:         'petit-works-games',
    databaseURL:       'https://petit-works-games-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'petit-works-games.firebasestorage.app',
  );

  // ─── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCdIuk0UifwgliMGDdU-06TwUsvkJESPc0',
    appId:             '1:250444577503:android:38cb968cde213222c1476a',
    messagingSenderId: '250444577503',
    projectId:         'petit-works-games',
    databaseURL:       'https://petit-works-games-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'petit-works-games.firebasestorage.app',
  );

  // ─── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyCdIuk0UifwgliMGDdU-06TwUsvkJESPc0',
    appId:             '1:250444577503:ios:38cb968cde213222c1476a',
    messagingSenderId: '250444577503',
    projectId:         'petit-works-games',
    databaseURL:       'https://petit-works-games-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'petit-works-games.firebasestorage.app',
    iosBundleId:       'com.petitworksapps.kouki',
  );
}
