// lib/firebase_options.dart
// 本番環境設定（koki-shogi-app / yourwishdev アカウント）
//
// 注意: Realtime Database の databaseURL は、Console でデータベースを作成
// した後に決まる。既定（us-central1）で作成した場合は、databaseURL を省略
// すると https://koki-shogi-app-default-rtdb.firebaseio.com が使われる。
// 別リージョンで作成した場合は、各 FirebaseOptions に databaseURL を追加すること。
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
    apiKey:            'AIzaSyCfbYeu3Da1GsZ7YbkgP2LNXVzDVUXXsWc',
    appId:             '1:419772713997:web:ac37a4efddb723e3d0d944',
    messagingSenderId: '419772713997',
    projectId:         'koki-shogi-app',
    authDomain:        'koki-shogi-app.firebaseapp.com',
    storageBucket:     'koki-shogi-app.firebasestorage.app',
  );

  // ─── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyAQNwFP4O9i7bWtE8Xj-uUNDCj74TqJD3o',
    appId:             '1:419772713997:android:68e31401620af449d0d944',
    messagingSenderId: '419772713997',
    projectId:         'koki-shogi-app',
    storageBucket:     'koki-shogi-app.firebasestorage.app',
  );

  // ─── iOS ───────────────────────────────────────────────────────────────────
  // 注意: Firebase 側は com.yourwish.koki で登録済みだが、iOS プロジェクトの
  // バンドルIDは com.petitworksapps.kouki のまま。iOS 配布前に揃えること。
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyD1TJE-tNltCkQB40C-kG85WKORjGC48-U',
    appId:             '1:419772713997:ios:510a28baa5e7233dd0d944',
    messagingSenderId: '419772713997',
    projectId:         'koki-shogi-app',
    storageBucket:     'koki-shogi-app.firebasestorage.app',
    iosBundleId:       'com.yourwish.koki',
  );
}
