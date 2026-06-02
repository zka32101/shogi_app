# セキュリティポリシー / Security Policy

**アプリ名**: 将棋 - Shogi Board  
**パッケージ**: com.petitStudio.shogiApp  
**最終更新**: 2026-05-23

---

## データ保護

### 通信セキュリティ
- すべてのネットワーク通信は **TLS 1.2以上** で暗号化
- Firebase Realtime Database への接続はHTTPS強制
- AdMob・Sentry・Google Play への通信もTLS必須

### ローカルデータ
- 棋譜・設定は `SharedPreferences` に保存（Android Keystore / iOS Keychain でプラットフォーム暗号化）
- 購入状態はデバイスキャッシュのみ（サーバー検証はGoogle Play / App Store経由）

### Firebase セキュリティルール（推奨設定）

```json
{
  "rules": {
    "rooms": {
      "$roomCode": {
        ".read": true,
        ".write": "auth != null || newData.child('status').val() == 'waiting'"
      }
    },
    "matchmaking": {
      ".read": true,
      ".write": true
    },
    "rankings": {
      ".read": true,
      "$userId": {
        ".write": "auth != null"
      }
    }
  }
}
```

> **⚠️ 本番前に必ず Firebase Console でルールを設定してください**

---

## 権限

| 権限 | 理由 |
|------|------|
| `INTERNET` | ネットワーク対局・Firebase同期・AdMob・Sentry |

**要求しない権限**: カメラ、位置情報、連絡先、マイク、ストレージ

---

## 脆弱性報告

セキュリティ上の問題を発見された場合は、公開前に **zkaz83@gmail.com** へご連絡ください。

---

## 本番リリース前チェックリスト

- [ ] Firebase Console でセキュリティルールを上記に設定
- [ ] `firebase_options.dart` を本番の値に置き換え
- [ ] AdMob App ID をテスト用から本番用に変更（AndroidManifest.xml）
- [ ] Sentry DSN を本番プロジェクトに設定（`.env` ファイル）
- [ ] Android 署名鍵ストアを作成して `build.gradle.kts` に設定
- [ ] Google Play Console でアプリ署名を設定
