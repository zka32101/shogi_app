# Android リリースビルド自動化セットアップ手順

`.github/workflows/deploy.yml` は、バージョンタグ（`v*`）のpush、または手動実行（workflow_dispatch）を
契機に、署名付きAndroid App Bundle(AAB)をビルドし、GitHub Actionsの成果物としてアップロードする。

**この環境（Linuxコンテナ、Android SDK/実機/Google Playアカウントへのアクセスなし）では
一度も実際に実行・検証できていない。** 以下の手順で準備したうえで、まず
`workflow_dispatch` で手動実行して動作確認すること。

## 1. アップロード用キーストアの準備

まだ署名鍵を作成していない場合、ローカルで以下を実行する（Java の `keytool` を使用）。

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

**このキーストアファイルと入力したパスワードは絶対に紛失しないこと。** 紛失すると、
Google Play にアップロード済みのアプリを同じ署名で更新できなくなる（Play App Signing を
有効にしていればアップロード鍵の失効申請で復旧可能だが、無効にしている場合は復旧不可）。

## 2. GitHub Secrets への登録

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** から、
以下を登録する。

| Secret名 | 内容 | 作り方 |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | `upload-keystore.jks` をbase64化した文字列 | `base64 -i upload-keystore.jks \| pbcopy`（Mac）/ `base64 -w0 upload-keystore.jks`（Linux） |
| `ANDROID_KEYSTORE_PASSWORD` | キーストア作成時に設定したパスワード（store password） | — |
| `ANDROID_KEY_ALIAS` | キーストア作成時に指定したalias（上記コマンド例では `upload`） | — |
| `ANDROID_KEY_PASSWORD` | キー自体のパスワード（key password。store passwordと同じ場合が多い） | — |

## 3. 初回実行

1. GitHubリポジトリの **Actions** タブ → **Build Signed Android App Bundle** →
   **Run workflow** で手動実行する
2. 成功したら、ワークフロー実行結果ページの **Artifacts** から `app-release-aab` を
   ダウンロードできる
3. ダウンロードしたAABは `bundletool` 等でローカル動作確認してから、
   **Google Play Console** に手動でアップロードする（初回のアプリ登録・ストア掲載情報の
   入力は自動化しておらず、Play Console上で行う必要がある）

## 4. Google Play Console への自動アップロードを追加する場合（任意・将来対応）

初回のアプリ登録が完了し、Play Console上にアプリのレコードが存在する状態になったら、
[`r0adkll/upload-google-play`](https://github.com/r0adkll/upload-google-play) 等の
GitHub Actionを追加してAABを直接内部テスト/製品トラック等にアップロードするよう
拡張できる。これには別途 Google Play Console のサービスアカウントJSON（Play Console の
**設定 → API アクセス** から発行）が必要。

## 5. 既知の未対応事項

- `android/app/build.gradle.kts` で `isMinifyEnabled`/`isShrinkResources` を有効化済み
  （`android/app/proguard-rules.pro` 参照）。この環境では実ビルドでの動作確認ができて
  いないため、初回のリリースビルドでは主要機能（Firebase認証・Firestore/RTDB同期・
  AdMob広告表示・課金・音声入力）が正常に動作するか一通り確認すること
- AdMobの本番Ad Unit ID / App IDは未設定（プレースホルダのまま）。
  `lib/ad_service_mobile.dart` のコメント、および
  `android/app/src/main/AndroidManifest.xml` の `APPLICATION_ID` 参照
