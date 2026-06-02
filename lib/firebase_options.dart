// lib/firebase_options.dart
// ──────────────────────────────────────────────────────────────────────────────
// ⚠️  TODO: 本番リリース前に自分の Firebase プロジェクト設定に置き換えてください
//
// 設定方法:
//   1. https://console.firebase.google.com/ でプロジェクトを作成
//   2. Realtime Database を有効化（アジアリージョン推奨）
//   3. `npm install -g firebase-tools` → `flutterfire configure` で自動生成
//
// または手動で各値を書き換えてください。
// ──────────────────────────────────────────────────────────────────────────────
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
        return web; // fallback
    }
  }

  // ─── Web ───────────────────────────────────────────────────────────────────
  // TODO: Firebase コンソール → プロジェクト設定 → マイアプリ → ウェブ の値に変更
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'YOUR_WEB_API_KEY',
    appId:             'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    databaseURL:       'https://YOUR_PROJECT_ID-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
  );

  // ─── Android ───────────────────────────────────────────────────────────────
  // TODO: google-services.json をダウンロードして android/app/ に配置 + 以下も更新
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'YOUR_ANDROID_API_KEY',
    appId:             'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    databaseURL:       'https://YOUR_PROJECT_ID-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
  );

  // ─── iOS ───────────────────────────────────────────────────────────────────
  // TODO: GoogleService-Info.plist をダウンロードして ios/Runner/ に配置 + 以下も更新
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'YOUR_IOS_API_KEY',
    appId:             'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    databaseURL:       'https://YOUR_PROJECT_ID-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    iosBundleId:       'com.yourcompany.shogiApp',
  );
}
