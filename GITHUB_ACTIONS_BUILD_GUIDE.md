# GitHub Actions ビルド自動化ガイド

**概要**: ローカルマシンに Flutter をインストールせず、GitHub Actions で自動的に APK・AAB・iOS IPA ビルドを実行

**更新日**: 2026-08-28  
**対応プラットフォーム**: Android (APK/AAB)、iOS (IPA/TestFlight)

---

## 📋 概要

このプロジェクトは既に GitHub Actions による自動ビルドが実装されています：

| ワークフロー | トリガー | 出力 | 実行環境 |
|---|---|---|---|
| **deploy.yml** | タグ push (`v*`) または手動実行 | AAB ファイル | Ubuntu |
| **ios-testflight.yml** | タグ push (`v*`) または手動実行 | TestFlight アップロード | macOS |

---

## ✅ Phase 1: 事前準備（初回のみ）

### Step 1.1: Android Keystore 準備

#### 1. キーストア生成（ローカル環境で 1 回実行）

```bash
# ローカルマシンで実行
keytool -genkey -v -keystore ~/shogi_app_release_key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias shogi_app_key

# 対話:
# Keystore password: [安全なパスワード]
# Key password: [上記と同じ]
# CN (Common Name): Your Company Name
# その他の情報を入力
```

#### 2. Keystore を Base64 エンコード

```bash
# ローカルマシンで実行
cat ~/shogi_app_release_key.jks | base64 | pbcopy

# または Linux の場合:
base64 ~/shogi_app_release_key.jks | xclip -selection clipboard

# または、ファイルに保存して確認:
base64 ~/shogi_app_release_key.jks > keystore_base64.txt
```

#### 3. GitHub Secrets に登録

GitHub リポジトリの **Settings → Secrets and variables → Actions** に以下を追加：

| Secret 名 | 値 | 取得方法 |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Keystore の Base64 エンコード | 上記 Step 2 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore パスワード | Step 1 で入力したパスワード |
| `ANDROID_KEY_ALIAS` | `shogi_app_key` | Step 1 で指定した alias |
| `ANDROID_KEY_PASSWORD` | Keystore パスワード | Step 1 で入力したパスワード |

**登録画面**:
```
https://github.com/zka32101/shogi_app/settings/secrets/actions
```

### Step 1.2: iOS 証明書・プロビジョニングプロファイル準備（Mac 必須）

#### 1. Apple Developer Certificate（配布用）取得

1. [Apple Developer Program](https://developer.apple.com/account) にログイン
2. Certificates, Identifiers & Profiles → Certificates
3. **Request a Certificate** → Distribution (App Store) を選択
4. CSR ファイルをアップロードして証明書を生成
5. .cer ファイルをダウンロード

#### 2. 証明書を .p12 に変換（Mac）

```bash
# ローカル macOS で実行
# Keychain Access で .cer をダブルクリックしてインストール
# Keychain Access → My Certificates → 右クリック → Export

# または openssl で変換:
openssl pkcs12 -export -in certificate.cer -inkey private_key.key -out certificate.p12
```

#### 3. .p12 を Base64 エンコード

```bash
base64 certificate.p12 | pbcopy
# または
base64 certificate.p12 > cert_base64.txt
```

#### 4. Provisioning Profile（App Store 配布用）取得

1. [Apple Developer - Provisioning Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. **Profiles** → **+** で新規作成
3. Type: **App Store** を選択
4. App ID: **com.petitworksapps.kouki** を選択
5. Certificate: 上記で作成した Distribution Certificate を選択
6. Download → .mobileprovision ファイル取得

#### 5. Provisioning Profile を Base64 エンコード

```bash
base64 profile.mobileprovision | pbcopy
# または
base64 profile.mobileprovision > profile_base64.txt
```

#### 6. App Store Connect API キー取得

1. [App Store Connect - API Keys](https://appstoreconnect.apple.com/access/api)
2. **Integrations** → **+** で新規キー生成
3. Role: **App Manager** を選択
4. Generate → .p8 ファイルダウンロード
5. Key ID と Issuer ID を記録

#### 7. .p8 を Base64 エンコード

```bash
base64 AuthKey_XXXXXXXXXX.p8 | pbcopy
```

#### 8. GitHub Secrets に iOS 関連を登録

| Secret 名 | 値 |
|---|---|
| `IOS_DIST_SIGNING_CERT_P12_BASE64` | 証明書 .p12 の Base64 |
| `IOS_DIST_SIGNING_CERT_PASSWORD` | .p12 作成時のパスワード |
| `IOS_PROVISIONING_PROFILE_BASE64` | Provisioning Profile の Base64 |
| `IOS_CI_KEYCHAIN_PASSWORD` | CI 環境での Keychain パスワード（任意） |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | .p8 ファイルの Base64 エンコード |
| `APPLE_TEAM_ID` | Apple Developer の10桁 Team ID |

---

## 🚀 Phase 2: ビルド実行方法

### 方法 A: タグ Push（推奨）

```bash
# ローカルマシンで実行
git tag v1.0.0
git push origin v1.0.0

# すると自動的に:
# - deploy.yml (Android AAB)
# - ios-testflight.yml (iOS TestFlight)
# が並列実行される
```

### 方法 B: 手動トリガー（workflow_dispatch）

GitHub Actions UI から手動実行：

1. リポジトリ → **Actions** タブ
2. **Build Signed Android App Bundle** を選択
3. **Run workflow** → **Run workflow** ボタン

または

1. リポジトリ → **Actions** タブ
2. **iOS TestFlight配信** を選択
3. **Run workflow** → **Run workflow** ボタン

---

## 📊 Phase 3: ビルド監視

### Android (deploy.yml) 実行状況確認

1. GitHub リポジトリ → **Actions**
2. **Build Signed Android App Bundle** → 最新実行
3. **Artifacts** セクションから **app-release-aab** をダウンロード

**出力物**: 
```
build/app/outputs/bundle/release/app-release.aab
```

### iOS (ios-testflight.yml) 実行状況確認

1. GitHub リポジトリ → **Actions**
2. **iOS TestFlight配信** → 最新実行
3. 実行ログで fastlane 出力を確認

**出力物**: 
```
TestFlight に自動アップロード済み
（App Store Connect で確認可能）
```

---

## ✨ Phase 4: Google Play Console 提出

### Step 4.1: AAB ファイルダウンロード

1. GitHub Actions → **Build Signed Android App Bundle**
2. 最新実行 → **Artifacts** → **app-release-aab**
3. ZIP ダウンロード → 解凍

### Step 4.2: Google Play Console へアップロード

1. [Google Play Console](https://play.google.com/console)
2. アプリ選択 → **リリース** → **本番環境**
3. **新しいリリースを作成** → AAB ファイルアップロード
4. リリース名・説明入力（`GOOGLE_PLAY_METADATA.md` 参照）
5. **レビュー申請**

---

## 📱 Phase 5: TestFlight Beta テスト

### iOS TestFlight 自動アップロード

`ios-testflight.yml` が実行されると、自動的に TestFlight にアップロードされます：

1. [App Store Connect](https://appstoreconnect.apple.com)
2. アプリ選択 → **TestFlight** → **iOS ビルド**
3. 最新ビルドを確認
4. テスター招待（Beta Groups で設定）

**注**: 初回アップロード後、Apple による処理待機（数分～1時間）

---

## 🔐 GitHub Secrets チェックリスト

**Android 必須**:
- [ ] `ANDROID_KEYSTORE_BASE64`
- [ ] `ANDROID_KEYSTORE_PASSWORD`
- [ ] `ANDROID_KEY_ALIAS`
- [ ] `ANDROID_KEY_PASSWORD`

**iOS 必須**:
- [ ] `IOS_DIST_SIGNING_CERT_P12_BASE64`
- [ ] `IOS_DIST_SIGNING_CERT_PASSWORD`
- [ ] `IOS_PROVISIONING_PROFILE_BASE64`
- [ ] `IOS_CI_KEYCHAIN_PASSWORD`
- [ ] `APP_STORE_CONNECT_API_KEY_ID`
- [ ] `APP_STORE_CONNECT_API_ISSUER_ID`
- [ ] `APP_STORE_CONNECT_API_KEY_CONTENT`
- [ ] `APPLE_TEAM_ID`

**確認コマンド**:
```bash
# リポジトリの Secrets を確認（読み取り専用）
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/zka32101/shogi_app/actions/secrets
```

---

## ⚠️ トラブルシューティング

### Android ビルド失敗: `ANDROID_KEYSTORE_BASE64 が設定されていません`

**原因**: GitHub Secret に `ANDROID_KEYSTORE_BASE64` が未設定

**対策**:
1. Settings → Secrets and variables → Actions
2. `ANDROID_KEYSTORE_BASE64` が存在するか確認
3. 値が Base64 エンコードされているか確認

### iOS ビルド失敗: `Provisioning profile not found`

**原因**: Provisioning Profile の Bundle ID が一致していない

**対策**:
1. Provisioning Profile が `com.petitworksapps.kouki` 用か確認
2. ios-testflight.yml 内の `IOS_BUNDLE_ID` と一致するか確認
3. Profile を再生成して GitHub Secret を更新

### iOS ビルド失敗: `Invalid authentication credentials`

**原因**: App Store Connect API キーが無効

**対策**:
1. [App Store Connect - API Keys](https://appstoreconnect.apple.com/access/api) で確認
2. キーの有効期限を確認
3. Key ID / Issuer ID / .p8 キー内容を再確認

### ビルド時間が長い（iOS）

**原因**: CocoaPods 依存関係の取得に時間がかかる

**対策**: 正常です。初回は 20 分程度、以降は 15 分程度。

---

## 📊 ビルド時間見積もり

| プラットフォーム | 初回 | 以降 | トリガー |
|---|---|---|---|
| Android AAB | 10 分 | 8 分 | タグ push / 手動 |
| iOS IPA | 20 分 | 15 分 | タグ push / 手動 |
| 並列実行 | 20 分 | 15 分 | タグ push |

---

## 🔄 ワークフロー詳細

### deploy.yml フロー

```
┌─ Push tag v*
└─ workflow_dispatch (手動)
   │
   ├─ Setup Flutter 3.x
   ├─ flutter pub get
   ├─ Restore keystore from GitHub Secret
   ├─ flutter build appbundle --release
   └─ Upload AAB as artifact
      └─ 30日間保持
```

### ios-testflight.yml フロー

```
┌─ Push tag v*
└─ workflow_dispatch (手動)
   │
   ├─ Setup Flutter 3.x
   ├─ flutter pub get
   ├─ pod install (CocoaPods)
   ├─ Import distribution certificate
   ├─ Install provisioning profile
   ├─ fastlane beta
   │  ├─ build_app (IPA ビルド)
   │  └─ upload_to_testflight
   └─ Complete
```

---

## 💡 ベストプラクティス

### 1. 本番リリース前には常にテストビルド実行

```bash
# テスト用タグで先にビルド
git tag v1.0.0-test
git push origin v1.0.0-test
# ビルド成功待機 → 削除
git tag -d v1.0.0-test
git push origin --delete v1.0.0-test
```

### 2. Secrets の定期的なローテーション（推奨）

- Apple 証明書: 年 1 回
- Keystore: 変更なし（有効期限 10 年）
- App Store Connect API キー: 1 年ごと

### 3. リリースノートの記録

```bash
# リリースノート作成
cat > RELEASE_v1.0.0.md << EOF
# v1.0.0 リリースノート

## 新機能
- 詰将棋モード
- AI対戦
- ネットワーク対局

## バグ修正
- セキュリティ 6 件

## ビルド情報
- ビルド日時: 2026-08-28
- Android AAB: app-release.aab
- iOS IPA: TestFlight アップロード済み
EOF

git add RELEASE_v1.0.0.md
git commit -m "chore: v1.0.0 リリースノート"
git push
```

---

## 📞 サポート情報

**トラブル時の確認項目**:
1. GitHub Actions ログ: リポジトリ → Actions → 失敗したワークフロー → Logs
2. エラーメッセージをコピー
3. 該当セクションのトラブルシューティング確認

**外部リソース**:
- [GitHub Actions - Flutter Documentation](https://flutter.dev/docs/deployment/cd)
- [Fastlane - iOS Deployment](https://docs.fastlane.tools/getting-started/ios/setup/)
- [Apple Developer - Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/)

---

## 🎯 次のステップ

1. ✅ GitHub Secrets 登録（Android 4 個 + iOS 4 個）
2. ✅ タグ push または手動トリガーでビルド開始
3. ✅ ビルド成功待機（15-20 分）
4. ✅ AAB / TestFlight 確認
5. ✅ Google Play Console / App Store Connect に提出

---

**すべて完了したら、ローカル Flutter インストール不要で自動ビルド・配信が可能になります！** 🎉
