# 将棋アプリ ローカルビルド クイックリファレンス

**用途**: ローカルマシン（Flutter インストール環境）でのビルド実行  
**対象プラットフォーム**: Android APK / App Bundle、iOS IPA  
**所要時間**: Android 5-10分、iOS 10-15分（初回は +pod install）

---

## 🚀 クイックスタート

### Android リリース APK（最速）
```bash
cd /path/to/shogi_app
flutter clean
flutter pub get
flutter build apk --release

# 出力:
# ✅ build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle（Google Play 推奨）
```bash
flutter build appbundle --release

# 出力:
# ✅ build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA（App Store 対応）
```bash
# Mac のみ対応
flutter clean
flutter pub get

# Pod 依存関係更新（初回のみ）
cd ios
pod install --repo-update
cd ..

flutter build ios --release

# Xcode で Archive（GUI 操作）
open ios/Runner.xcworkspace
# Xcode: Product → Archive → Distribute App
```

---

## ⚙️ 環境チェック

```bash
# 環境確認
flutter doctor

# 必須チェック項目:
✓ Flutter version >= 3.11.5
✓ Dart version >= 3.1.0
✓ Android toolchain (Android SDK 34+)
✓ Xcode 14.0+ (iOS 開発の場合)
✓ Java JDK 11+ (Android)
```

---

## 🔑 初回ビルド前準備（Android）

### 1. キーストア生成（初回のみ）
```bash
keytool -genkey -v -keystore ~/shogi_app_release_key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias shogi_app_key

# 対話形式で以下を入力:
# Keystore password: [安全なパスワード8文字以上]
# Key password: [上記と同じ]
# CN (Common Name): Your Company Name
# OU (Org Unit): Engineering
# O (Organization): Your Company
# L (Locality): Tokyo
# ST (State): Tokyo
# C (Country): JP

# パスワード例:
# ✅ Shogi@2026!AppRelease
# ❌ 123456 (短い・弱い)
```

### 2. `android/key.properties` 作成
```properties
storeFile=/Users/username/shogi_app_release_key.jks
storePassword=Shogi@2026!AppRelease
keyPassword=Shogi@2026!AppRelease
keyAlias=shogi_app_key
```

### 3. `android/app/build.gradle` 確認
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withInputStream { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? 
                file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

## 📱 テスト実機インストール

### Android
```bash
# 実機接続確認
adb devices

# APK インストール
adb install build/app/outputs/flutter-apk/app-release.apk

# アンインストール（必要な場合）
adb uninstall com.petitworksapps.kouki

# ログ確認
adb logcat | grep flutter
```

### iOS（Mac）
```bash
# 実機接続確認
open ios/Runner.xcworkspace

# Xcode GUI: Product → Run on device
# または
flutter run -v  # 詳細ログ出力
```

---

## 🧪 リリース前チェック

### コード品質
```bash
# 構文チェック
flutter analyze

# テスト実行（ユニットテストがある場合）
flutter test

# 出力確認
# ✓ No issues found! (エラーなし)
```

### ビルド成功確認
```bash
# APK 署名確認
jarsigner -verify -verbose -certs \
  build/app/outputs/flutter-apk/app-release.apk

# 出力例:
# [certificate is valid from 2/27/2026 to 12/24/3005]
# jar verified.
```

---

## 📦 ファイル出力場所

```
build/app/outputs/
├── flutter-apk/
│   └── app-release.apk              ← Android APK
├── bundle/
│   └── release/
│       └── app-release.aab          ← Android App Bundle (推奨)
└── ios/
    └── ipa/
        └── Runner.ipa               ← iOS IPA
```

---

## ⚠️ よくあるエラーと対処法

### 「Could not find Android SDK」
```bash
# Flutter SDK 再設定
flutter config --android-sdk /path/to/android/sdk

# 例:
flutter config --android-sdk ~/Library/Android/sdk
```

### 「Module not found」（iOS）
```bash
cd ios
pod install --repo-update
cd ..
flutter pub get
flutter build ios --release
```

### 「Gradle build failed」
```bash
flutter clean
rm -rf ./build ./pubspec.lock
flutter pub get
flutter build apk --release
```

### 「Undefined symbol」（iOS）
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter build ios --release
```

---

## 🔒 本番ビルド注意事項

### ✅ 実施すべきこと
- [x] `flutter analyze` でエラーなし確認
- [x] 実機でテスト実行（オンライン対局含む）
- [x] メモリプロファイル確認（長時間対局後）
- [x] Firebase 本番接続確認（Firestore・RTDB）
- [x] AdMob 本番ID 設定確認
- [x] iOS GoogleService-Info.plist 配置確認

### ❌ 避けるべきこと
- APK/AAB を複数回生成後、署名が異なるまま提出
- Keystore パスワード保存の見直しなし
- Debug フラグを削除せず提出
- テスト中の AdMob ID（`ca-app-pub-3940256099942544~...`）のまま提出

---

## 📊 ビルド実行タイムライン

### Android APK（最速パス）
```
$ flutter clean                           (2秒)
$ flutter pub get                         (10秒)
$ flutter build apk --release             (5分)
────────────────────────────────────────
合計: 約 5分30秒
```

### Android App Bundle
```
$ flutter build appbundle --release       (8分)
────────────────────────────────────────
合計: 約 8分
```

### iOS IPA
```
$ flutter clean                           (2秒)
$ pod install --repo-update              (3分, 初回のみ)
$ flutter build ios --release             (10分)
────────────────────────────────────────
合計: 約 15分（初回）/ 12分（以降）
```

---

## 🎯 Google Play Console 提出フロー

```
✅ ローカルビルド完了
   ↓
📤 AAB ファイル (app-release.aab) をアップロード
   ↓
📝 メタデータ入力（GOOGLE_PLAY_METADATA.md 参照）
   ↓
🔍 自動スキャン
   ├─ コンテンツレーティング: 一般向け確認
   ├─ ターゲット API レベル: 34 確認
   └─ 必須権限: Internet, SharedPreferences 確認
   ↓
✅ レビュー申請
   ↓
⏳ Google 審査（1-3時間）
   ↓
🎉 本番リリース
```

---

## 🎯 App Store Connect 提出フロー

```
✅ ローカル iOS ビルド完了
   ↓
📤 Xcode Archive → Organizer で Distribution
   ↓
📤 App Store Connect へアップロード
   ↓
📝 メタデータ入力（APP_STORE_METADATA.md 参照）
   ↓
🔍 自動スキャン
   ├─ 年齢制限区分: 4+ 確認
   ├─ プライバシー: 暴力・性的描写なし確認
   └─ Bundle ID: com.petitworksapps.kouki 確認
   ↓
✅ レビュー申請
   ↓
⏳ Apple 審査（1-3日）
   ↓
🎉 本番リリース
```

---

## 💾 ビルドアーティファクト保管

```bash
# バージョン別ディレクトリ作成
mkdir -p releases/v1.0.0/{android,ios}

# ビルドアーティファクト保管
cp build/app/outputs/flutter-apk/app-release.apk \
   releases/v1.0.0/android/

cp build/app/outputs/bundle/release/app-release.aab \
   releases/v1.0.0/android/

cp build/ios/ipa/Runner.ipa \
   releases/v1.0.0/ios/

# 署名情報保管（パスワードは別途安全保管）
# DO NOT: Git に Keystore を保管
# DO: 1Password, Vault 等で安全保管
```

---

## 📞 トラブルシューティング連絡先

**ビルドエラー**: 
- `flutter doctor -v` の出力をコピー
- `flutter build apk --verbose` でエラーログ確認
- GitHub Issues で検索

**ストア提出エラー**:
- Google Play Console：サポートチャット
- App Store Connect：Apple Developer Support

---

## 🔗 リファレンスドキュメント

- **詳細ビルドガイド**: `BUILD_AND_SUBMISSION_GUIDE.md`
- **リリースチェックリスト**: `RELEASE_CHECKLIST.md`
- **Google Play メタデータ**: `release-outputs/GOOGLE_PLAY_METADATA.md`
- **App Store メタデータ**: `release-outputs/APP_STORE_METADATA.md`
- **プライバシーポリシー**: `release-outputs/PRIVACY_POLICY.md`
- **利用規約**: `release-outputs/TERMS_OF_SERVICE.md`

---

**最後に**: 初回ビルドは時間がかかります。夜間実行をお勧めします。  
本番提出前に 24 時間以上の内部テスト期間を設けてください。
