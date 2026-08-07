# iOS TestFlight 自動配信セットアップ手順

`.github/workflows/ios-testflight.yml` は、バージョンタグ（`v*`）のpush、または手動実行（workflow_dispatch）を
契機に、macOSランナー上でiOSアプリをビルドし、fastlane経由でTestFlightにアップロードする。

このワークフローは **この環境（Linuxコンテナ、Flutter/Xcode/Apple Developer アカウントへのアクセスなし）では
一度も実際に実行・検証できていない。** Apple Developer Portal / App Store Connect側の設定はすべて人間が行う
必要があり、そのうえで初回実行時に細部（証明書のタイプ、プロファイルの権限セットなど）の調整が必要になる
可能性が高い。以下の手順に沿って準備したうえで、まず `workflow_dispatch` で手動実行して動作確認すること。

## 現在の状態

- Bundle Identifier: `com.petitworksapps.kouki`（Android の `applicationId` と同じ値に統一済み。
  `ios/Runner.xcodeproj` の `PRODUCT_BUNDLE_IDENTIFIER` を書き換え済み）
- コード署名スタイル: Xcodeプロジェクト上は `Automatic` のまま（ローカルXcode開発を壊さないため）。
  CI側では `fastlane build_app` の `xcargs` で `CODE_SIGN_STYLE=Manual` を明示的に上書きしてビルドする
- **`ios/Runner/GoogleService-Info.plist` が存在しない** = Firebase側でiOSアプリが未登録。
  Firebase Console でこのBundle ID（`com.petitworksapps.kouki`）のiOSアプリを追加し、
  `GoogleService-Info.plist` をダウンロードして `ios/Runner/GoogleService-Info.plist` に配置し、
  Xcodeで `Runner` ターゲットに追加（Copy items if needed）する必要がある。これをしないと
  実機で `Firebase.initializeApp()` が失敗しアプリがクラッシュする可能性が高い（TestFlightビルド自体は通る）
- **Push通知(APNs)のentitlementsが未設定。** `firebase_messaging` を使っているため、実際にプッシュ通知を
  受け取るには Apple Developer Portal でこのBundle IDの Push Notifications capability を有効化し、
  Xcode で `Runner` ターゲットに Push Notifications capability を追加（`ios/Runner/Runner.entitlements` が
  生成される）したうえで、Firebase Console に APNs認証キー(.p8) を登録する必要がある。
  本セットアップ（TestFlight配信の自動化）の範囲外なので、別途対応すること

## 1. Apple Developer Portal での作業

<https://developer.apple.com/account/resources/> にアクセスし、対象のTeamで以下を行う。

### 1-1. App ID (Bundle ID) の登録
- **Identifiers** → `+` → **App IDs** → **App**
- Bundle ID: **Explicit** で `com.petitworksapps.kouki` を入力
- 必要なCapabilitiesにチェック（現時点では Push Notifications は未対応のため付けなくても良いが、
  将来的に対応するなら先に有効化しておいてよい）

### 1-2. 配布用証明書 (Distribution Certificate) の作成
- **Certificates** → `+` → **Apple Distribution**
- ローカルMacの「キーチェーンアクセス」で CSR (Certificate Signing Request) を作成し、アップロードする
- 発行された証明書をダウンロードし、ダブルクリックしてキーチェーンにインストール
- キーチェーンアクセスで証明書を右クリック → **書き出す** → `.p12` 形式で書き出し、パスワードを設定
  （このパスワードは後で `IOS_DIST_SIGNING_CERT_PASSWORD` として使う）

### 1-3. App Store配布用プロビジョニングプロファイルの作成
- **Profiles** → `+` → **App Store** （Distribution欄）
- App ID: `com.petitworksapps.kouki` を選択
- 1-2で作成した証明書を選択
- プロファイル名は任意（ワークフロー側でプロファイルファイルから自動抽出するため、名前を
  GitHub Secretsに別途登録する必要はない）
- `.mobileprovision` ファイルをダウンロード

### 1-4. Team ID の確認
- Apple Developer Portal右上のメンバーシップ詳細、または **Membership** ページで確認できる10桁の英数字

## 2. App Store Connect での作業

<https://appstoreconnect.apple.com/> にアクセスする。

### 2-1. アプリレコードの作成（まだ無い場合）
- **My Apps** → `+` → **New App**
- Bundle ID: `com.petitworksapps.kouki`（1-1で登録したものが選択肢に出る）
- SKU・アプリ名などを入力して作成

### 2-2. App Store Connect API キーの発行
- **ユーザとアクセス** → **統合** タブ → **App Store Connect API**
- `+` でキーを生成。ロールは **App Manager** 以上（TestFlightアップロードに必要な権限）
- 表示される **Key ID** と **Issuer ID** を控える
- `.p8` 秘密鍵ファイルは**その場でしかダウンロードできない**ので必ず保存する

## 3. GitHub Secrets への登録

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** から、
以下をすべて登録する。値そのものをこのリポジトリやチャット上に貼り付けないこと。

| Secret名 | 内容 | 作り方 |
|---|---|---|
| `IOS_DIST_SIGNING_CERT_P12_BASE64` | 1-2で書き出した`.p12`をbase64化した文字列 | `base64 -i Certificates.p12 \| pbcopy`（Mac） |
| `IOS_DIST_SIGNING_CERT_PASSWORD` | `.p12`書き出し時に設定したパスワード | — |
| `IOS_CI_KEYCHAIN_PASSWORD` | CI上で一時キーチェーンを作るための任意パスワード | 何でもよい。ランダム文字列を新規に生成して使う |
| `IOS_PROVISIONING_PROFILE_BASE64` | 1-3でダウンロードした`.mobileprovision`をbase64化した文字列 | `base64 -i AppStore_Profile.mobileprovision \| pbcopy`（Mac） |
| `APP_STORE_CONNECT_API_KEY_ID` | 2-2で控えたKey ID | — |
| `APP_STORE_CONNECT_API_ISSUER_ID` | 2-2で控えたIssuer ID | — |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `.p8`ファイルの中身をbase64化した文字列 | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy`（Mac） |
| `APPLE_TEAM_ID` | 1-4で確認した10桁のTeam ID | — |

`IOS_BUNDLE_ID` は非機密情報のため `.github/workflows/ios-testflight.yml` の `env:` に平文で
直接書いてある。Bundle IDを変更した場合はワークフローファイルと `ios/Runner.xcodeproj` の
両方を更新すること。

## 4. 初回実行

1. GitHubリポジトリの **Actions** タブ → **iOS TestFlight配信** → **Run workflow** で手動実行する
   （最初から `v*` タグpushで走らせず、まず手動実行で確認するのを推奨）
2. 失敗した場合、ログの失敗箇所を見て以下をまず疑う:
   - 署名まわり（`CODE_SIGN_IDENTITY` が `Apple Distribution` と一致しない、
     プロビジョニングプロファイルがBundle IDやDevelopment Teamと不一致 等）
   - CocoaPods関連（`pod install` の失敗。Podfileのプラットフォームバージョンが古い等）
   - `GoogleService-Info.plist` 未配置によるFirebase関連のビルドエラー
     （前述の通り、この配置は本手順の対象外のため別途必要）

## 5. 既知の未対応事項

- Push通知(APNs) entitlementsの設定（上記参照）
- Firebase iOSアプリ未登録（`GoogleService-Info.plist` 未配置）
- `fastlane match` は導入していない（証明書・プロファイルはGitHub Secretsで直接管理する方式）。
  複数人・複数リポジトリで証明書を使い回す場合は `match` への移行を検討すること
