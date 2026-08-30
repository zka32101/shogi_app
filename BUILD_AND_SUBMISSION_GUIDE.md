# 将棋アプリ リリースビルド・ストア提出ガイド

最終更新: 2026-08-27  
バージョン: 1.0.0  
対象プラットフォーム: Android (Google Play) / iOS (App Store)

---

## 📋 事前準備チェックリスト

### ✅ コード準備完了項目
- [x] セキュリティ修正（TOCTOU対策、千日手検出修正）
- [x] Firebase設定（`firebase_options.dart`）
- [x] ネットワークサービス（報告・ブロック機能）
- [x] プライバシーポリシー・利用規約（`release-outputs/`）
- [x] メールアドレス統一（yourwishdev@gmail.com）

### ⚠️ 手動対応必須項目
- [ ] **Google AdMob** - Production App ID取得・設定
- [ ] **iOS Firebase** - GoogleService-Info.plist取得（Firebase Console）
- [ ] **App Icons** - 1024x1024 PNG (Android: Adaptive Icon)
- [ ] **Screenshots** - 3-5枚（Google Play & App Store用）
- [ ] **Google Play Console** - アプリ登録・メタデータ入力
- [ ] **App Store Connect** - iOS アプリ登録・メタデータ入力

---

## 🔨 Phase 1: ローカルビルド準備

### 環境要件
```bash
Flutter: 3.11.5+
Dart:    3.1.x+
Java:    JDK 11+ (Android)
Xcode:   14.0+ (iOS - Mac必須)
```

### 1.1 ローカルマシンでの準備

```bash
# リポジトリクローン（ブランチ指定）
git clone https://github.com/zka32101/shogi_app.git
cd shogi_app
git checkout claude/shogi-app-security-yxlfcj

# 依存関係インストール
flutter pub get

# ビルド環境検証
flutter doctor
```

### 1.2 Android ビルド準備

**キーストア生成（初回のみ）**
```bash
keytool -genkey -v -keystore ~/shogi_app_release_key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias shogi_app_key

# 対話:
# - Keystore password: [安全なパスワード]
# - Key password: [上記と同じ]
# - CN (Common Name): Your Company Name
# - OU, O, L, ST, C: 適切に入力
```

**`android/key.properties` 作成**
```properties
storeFile=/path/to/shogi_app_release_key.jks
storePassword=[Keystore password]
keyPassword=[Key password]
keyAlias=shogi_app_key
```

**`android/app/build.gradle` 確認**
```gradle
android {
  ...
  signingConfigs {
    release {
      keyAlias keystoreProperties['keyAlias']
      keyPassword keystoreProperties['keyPassword']
      storeFile file(keystoreProperties['storeFile'])
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

### 1.3 iOS ビルド準備（Mac必須）

**Xcode設定**
```bash
open ios/Runner.xcworkspace  # .xcodeproj ではなく .xcworkspace で開く

# Xcode内:
# 1. Signing & Capabilities タブ
# 2. Bundle Identifier: com.petitworksapps.kouki に設定
# 3. Team を Apple Developer Account に指定
# 4. Provisioning Profile を自動生成
```

---

## 🏗️ Phase 2: ビルド実行

### 2.1 Android Release APK ビルド

```bash
cd /path/to/shogi_app

# Release APK
flutter build apk --release

# 出力:
# build/app/outputs/flutter-apk/app-release.apk
```

**テスト実機にインストール**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 2.2 Android App Bundle ビルド（推奨）

```bash
flutter build appbundle --release

# 出力:
# build/app/outputs/bundle/release/app-release.aab
```

> **注:** Google Playへの提出は App Bundle (`.aab`) が推奨  
> 自動的に端末別の最適化APKを生成

### 2.3 iOS ビルド（Mac）

```bash
flutter build ios --release

# Xcode でアーカイブ・署名
open ios/Runner.xcworkspace

# Xcode: Product → Archive
# Organizer で Distribution 選択 → App Store Connect へアップロード
```

---

## 🧪 Phase 3: テスト・QA

### 3.1 機能テスト
- [ ] ローカル詰将棋モード（AI対局含む）
- [ ] ネットワーク対局（Firebase接続確認）
- [ ] 報告機能（不正報告送信）
- [ ] ブロック機能（ブロック・解除）
- [ ] チャット機能（禁止ワード検出）
- [ ] 通知（FCM受信確認）

### 3.2 パフォーマンステスト
- [ ] 長時間対局でのメモリリーク確認
- [ ] AI計算時のUIフリーズなし
- [ ] 回線断時の復帰動作

### 3.3 セキュリティテスト
- [ ] バンユーザーのプレイ禁止確認
- [ ] 二重実行バグなし（重複ELO適用なし）
- [ ] チート検出スコア算出確認

---

## 📦 Phase 4: ストア提出

### 4.1 Google Play Console 登録

**事前準備**
1. [Google Play Console](https://play.google.com/console) にログイン
2. 「新しいアプリを作成」
3. アプリ名: 「将棋 - 詰将棋・対局」
4. アプリカテゴリ: ゲーム > ボードゲーム

**必須情報**

| 項目 | 内容 | 備考 |
|---|---|---|
| **アプリタイトル** | 将棋 - 詰将棋・対局 | 最大50文字 |
| **短説明** | オンライン対局・AI対戦・詰将棋 | 最大80文字 |
| **説明** | 見出し・段落・プレイ方法・サポート含む | 最大4000文字 |
| **スクリーンショット** | 最小3枚、最大8枚 (1440×900 px推奨) | PNG/JPG |
| **プレビュー動画** | オプション (最大30秒) | MP4推奨 |
| **プロモ用グラフィック** | 1024×500 px (PNG/JPG) | 1枚 |
| **アイコン** | 512×512 px (PNG) | 透明背景なし |
| **プライバシーポリシー** | 公開URL | 必須（HTTPS） |
| **連絡先** | yourwishdev@gmail.com | 公開情報 |
| **カテゴリ** | ゲーム > ボードゲーム | - |
| **コンテンツレーティング** | 未評価 → 記入必須 | - |

**リリース方法**
- 基本リリース: 全ユーザーに即座に配信
- 段階的リリース: 初回は20% → 段階的に拡大（推奨）

### 4.2 App Store Connect 登録（iOS）

**事前準備**
1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. 「マイApp」→「新規アプリ」
3. プラットフォーム: iOS 選択
4. アプリ名: 「将棋 - 詰将棋・対局」
5. Bundle ID: com.petitworksapps.kouki（Firebase Console で事前登録必須）

**必須情報** (Google Play と同様 + 以下追加)

| 項目 | 内容 |
|---|---|
| **キーワード** | 将棋,詰将棋,オンライン対局,AI,ボードゲーム |
| **サポートURL** | https://yourwishdev.example.com/support |
| **プライバシーポリシー** | 公開URL (HTTPS) |
| **利用規約** | 公開URL (HTTPS) |
| **年齢区分** | 4+ (暴力・差別表現なし) |
| **Apple Sign In** | 不要（ただしサードパーティ認証を使う場合は必須） |

**審査期間**
- Google Play: 数時間～24時間
- App Store: 1-3日（要件不足で却下の可能性あり）

---

## 🔒 Phase 5: 本番環境設定（重要）

### 5.1 AdMob 本番ID 設定

**現在の状態**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
    <!-- ⚠️ PLACEHOLDER - 本番前に置き換え必須 -->
```

**対応方法**
1. [Google AdMob](https://admob.google.com) にログイン
2. アプリ追加 → 「新しいアプリを追加」
3. プラットフォーム: Android
4. アプリ名: 「将棋」
5. **App ID** 取得 → AndroidManifest.xml に貼付

```bash
# コマンドラインでの置き換え
sed -i 's/ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy/YOUR_ADMOB_APP_ID/g' \
  android/app/src/main/AndroidManifest.xml
```

### 5.2 Firebase iOS 設定

**iOS GoogleService-Info.plist 取得**
1. [Firebase Console](https://console.firebase.google.com)
2. プロジェクト: petit-works-games
3. 設定 → プロジェクト設定
4. 「Google-Services ファイルをダウンロード」
5. `ios/Runner/GoogleService-Info.plist` に配置

**Xcode での確認**
```bash
open ios/Runner.xcworkspace
# Xcode: Runner → Build Phases → Copy Bundle Resources
# GoogleService-Info.plist が含まれていることを確認
```

---

## 📱 Phase 6: リリース直後の監視

### 6.1 クラッシュレポート監視

**Firebase Crashlytics**
```bash
# Build Phases に自動追加済み
# Firebase Console → Crashlytics で確認
```

### 6.2 ユーザー反応監視
- Google Play Console のレビュー・評価
- Firebase Analytics（インストール数・セッション数）
- エラーレポート（Firebase Reporting）

### 6.3 段階的ロールアウト
```
Day 1-2: 20% ユーザー
Day 3-5: 50% ユーザー
Day 6+:  100% ロールアウト
```

---

## 🆘 トラブルシューティング

### ビルドエラー

**「Flutter SDK not found」**
```bash
which flutter
# 未検出の場合: flutter のインストールパス確認
export PATH="$PATH:$(dirname $(dirname $(which flutter)))"
```

**「Gradle build failed」**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

**「Module not found」**
```bash
cd ios
pod install --repo-update
cd ..
flutter pub get
```

### ストア提出エラー

**Google Play「ターゲット API レベルが古い」**
- `android/app/build.gradle` の `targetSdkVersion` を確認
- 現在: `targetSdkVersion 34`（最新要件対応済み）

**App Store「プライバシーマニフェストが不足」**
- Xcode でプライバシーマニフェスト追加（手動）
- または PrivacyInfo.xcprivacy ファイル作成

---

## 📞 サポート連絡先

**開発者メール:** yourwishdev@gmail.com  
**プロジェクト:** zka32101/shogi_app (GitHub)  
**Firebase Project:** petit-works-games  
**ストア公開後の問合せ:** 別途サポートメール設定

---

## 附録: 自動化スクリプト例

### build_all.sh - 全プラットフォームビルド
```bash
#!/bin/bash
set -e

echo "🔨 Building Android APK..."
flutter build apk --release

echo "📦 Building Android App Bundle..."
flutter build appbundle --release

echo "✅ All builds completed!"
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
```

### validate_release.sh - リリース前検証
```bash
#!/bin/bash

echo "📋 Validating release checklist..."

CHECKS=(
  "firebase_options.dart contains petit-works-games"
  "AndroidManifest.xml AdMob ID is NOT placeholder"
  "ios/Runner/GoogleService-Info.plist exists"
  "PRIVACY_POLICY.md exists in release-outputs"
  "TERMS_OF_SERVICE.md exists in release-outputs"
)

for check in "${CHECKS[@]}"; do
  echo "- [ ] $check"
done
```

---

**最後に**: 本ドキュメントは段階的リリースを想定しています。  
初回は内部テスト（20%）から始め、ユーザーフィードバックを確認してから段階拡大をお勧めします。
