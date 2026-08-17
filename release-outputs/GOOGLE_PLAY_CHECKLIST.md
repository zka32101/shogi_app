# Google Play リリースチェックリスト
# 効棋 / Kouki（com.petitworksapps.kouki）

生成日: 2026-05-23 | 更新日: 2026-08-17 | アプリタイプ: ボードゲーム / 教育（将棋）

> ⚠️ このファイルは 2026-05-23 時点の生成後、しばらく更新されずアプリ名・
> パッケージ名・IAP商品ID等が実装と食い違っていた（旧アプリ名「将棋 - Shogi Board」
> ／旧パッケージ名 `com.petitStudio.shogiApp` のまま）。現在の実装（`android/app/
> build.gradle.kts` の `applicationId` = `com.petitworksapps.kouki`、
> `AndroidManifest.xml` のアプリラベル = 「効棋 - Kouki」、
> `lib/purchase_service.dart` のIAP商品ID）に合わせて更新済み。

---

## ✅ Phase 1: ビルド・署名

- [x] `android/app/build.gradle.kts` の `signingConfig` は `key.properties`（gitignore対象）を
      参照する構成に済み。**未対応**: `key.properties` 自体の作成とCI用Secretsの登録
      （手順は `android/ANDROID_RELEASE_SETUP.md` を参照）
  ```bash
  keytool -genkey -v -keystore upload-keystore.jks \
    -alias upload -keyalg RSA -keysize 2048 -validity 10000
  ```
- [x] `android/app/build.gradle.kts` で `isMinifyEnabled`/`isShrinkResources` を有効化済み
      （`android/app/proguard-rules.pro` 参照。要実ビルド動作確認）
- [ ] `.github/workflows/deploy.yml`（`workflow_dispatch`）で署名付きAABをビルドし、
      Actions成果物としてダウンロード（詳細は `android/ANDROID_RELEASE_SETUP.md`）
- [ ] Google Play Console で **アプリ署名** を有効化（推奨）

> 以前このセクションには「APK/AAB生成済み・55.8MB/46.7MB・署名: debug key」という
> チェック済み記載があったが、実体は debug 鍵で署名された提出不可能なビルドで、
> リポジトリに直接コミットされていた（現在は履歴から削除・.gitignore対象化済み）。
> 提出用のAABは上記の正しい署名フローで都度ビルドし直すこと。

---

## ✅ Phase 2: Firebase 本番設定

- [ ] Firebase Console で本番プロジェクトを作成
- [ ] `flutterfire configure` を実行して `firebase_options.dart` を上書き
- [ ] Realtime Database セキュリティルールを設定（`release-outputs/policies/SECURITY_POLICY.md` 参照）
- [ ] Firebase Console → Authentication を必要に応じて有効化
- [ ] テスト用のルームデータを削除

---

## ✅ Phase 3: AdMob 設定

- [ ] [AdMob Console](https://admob.google.com/) でアプリを登録
- [ ] 本番 App ID を `AndroidManifest.xml` に設定
  ```xml
  <!-- 現在: テスト用 ca-app-pub-3940256099942544~3347511713（TODOコメント有り） -->
  <meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXX~XXXXXXXXXX"/>  <!-- ← 本番ID -->
  ```
- [x] 広告ユニットID（Banner）はリリースビルドで `--dart-define=ADMOB_ANDROID_BANNER_ID=...`
      `--dart-define=ADMOB_IOS_BANNER_ID=...` を指定する方式に変更済み
      （`lib/ad_service_mobile.dart`）。デバッグビルドはGoogle公式テストIDを自動使用。
      **未対応**: 本番Ad Unit IDの取得・実際の指定
- [ ] テスト端末で広告表示確認

---

## ✅ Phase 4: IAP（アプリ内課金）設定

- [ ] Google Play Console → 収益化 → 製品 で以下を作成（`lib/purchase_service.dart` と
      一致させること。旧版は `liki_shogi_no_ads_monthly`/`liki_shogi_theme_pack` という
      異なる商品IDで記載されていたが、実装と食い違っていたため修正）:
  | 製品ID | 種別 | 価格目安 | 説明 |
  |--------|------|------|------|
  | `liki_shogi_plan_300` | 買い切り（non-consumable） | ¥300 | プレミアム機能解放 |
  | `liki_shogi_plan_500` | 買い切り（non-consumable） | ¥500 | プレミアム機能解放（上位プラン） |

  いずれか一方を購入すればプレミアム状態になる（`PurchaseService.isPremium`）。
  サブスクリプションではなく買い切りのため、自動更新・猶予期間の設定は不要。
- [ ] IAP の実機テスト（ライセンステスター登録・`restorePurchases`の動作確認）

---

## ✅ Phase 5: Sentry 設定

- [ ] [Sentry.io](https://sentry.io/) で Flutter プロジェクトを作成
- [ ] `.env` ファイルに本番 DSN を設定
  ```
  SENTRY_DSN=https://your_key@sentry.io/your_project_id
  ```
- [ ] クラッシュレポートの受信テスト

---

## ✅ Phase 6: Google Play Console 設定

### ストア掲載情報
- [ ] **アプリ名（日本語）**: 効棋 (Kouki)
- [ ] **アプリ名（英語）**: Kouki - Shogi
- [ ] **短い説明（80文字以内）**: 本格将棋アプリ。AI対局・ネット対局・棋譜管理・手筋トレーニング搭載
- [ ] **詳細説明（4000文字以内）**: ↓ 以下をカスタマイズ
  ```
  日本の伝統ボードゲーム「将棋」を本格的に楽しめるアプリです。

  【主な機能】
  🤖 AI対局 — 5段階の難易度（15級〜三段）
  🌐 ネット対局 — 友人・不特定多数とのマッチング
  👁 観戦モード — 進行中の対局をリアルタイム観戦
  📋 棋譜管理 — KIFファイルのインポート/エクスポート
  🧩 手筋トレーニング — 50問・5カテゴリ
  📊 成績グラフ — レーティング・段位推移
  🏆 グローバルランキング — 全国プレイヤーと段位を競う
  🎨 8種テーマ — 標準・ダーク・本榧・漆金・和紙・AI瑠璃・エメラルド・桜
  ```
- [ ] **カテゴリ**: ゲーム > ボードゲーム
- [ ] **コンテンツレーティング**: 全年齢（暴力・性的コンテンツなし）

### 画像素材（`release-outputs/images/` を参照）
- [ ] **アイコン**: 512×512px PNG（角丸なし）
- [ ] **フィーチャーグラフィック**: 1024×500px PNG/JPG
- [ ] **スクリーンショット**: 電話用 2〜8枚（推奨解像度: 1080×1920）
  - [ ] ホーム画面（モードセレクト）
  - [ ] AI対局中（盤面）
  - [ ] ネット対局（マッチング画面）
  - [ ] 手筋トレーニング
  - [ ] 棋譜管理・レーティンググラフ
- [ ] タブレット用スクリーンショット（任意）

---

## ✅ Phase 7: コンテンツ・法的事項

- [ ] **プライバシーポリシーURL** をホスティング（GitHub Pages 等に掲載）
  - `release-outputs/policies/PRIVACY_POLICY.md` の内容を HTML に変換して公開
- [ ] **利用規約URL** を同様に公開
- [ ] Google Play Console にプライバシーポリシー URL を登録
- [ ] **データセーフティ** フォームに記入:
  | 項目 | 回答 |
  |------|------|
  | データ収集 | あり（Firebase・AdMob） |
  | データ暗号化 | あり（転送中: TLS） |
  | ユーザーが削除可能 | あり（アンインストール） |
  | 子ども向け | いいえ |

---

## ✅ Phase 8: 技術要件

- [ ] `minSdkVersion` を確認（現在: flutter.minSdkVersion = 21）
- [ ] `targetSdkVersion` を最新に（Google Play 要件: API 34以上）
  ```kotlin
  targetSdk = 34  // flutter.targetSdkVersionを上書きする場合
  ```
- [ ] 64bit 対応確認（flutter build appbundle は自動対応）
- [ ] ネットワーク接続なしでの動作確認（オフラインで基本機能が使えること）
- [ ] バックボタン動作確認
- [ ] 縦向き固定 or 横向き対応を確認

---

## ✅ Phase 9: テスト

- [ ] 内部テスト → クローズドテスト → オープンテストの順で段階リリース
- [ ] ANR・クラッシュが0件であること（Sentry で確認）
- [ ] Firebase Test Lab での自動テスト（任意）
- [ ] 複数の画面サイズで UI 確認（スマホ・タブレット）
- [ ] Firebase 本番環境での対局テスト

---

## 📦 生成されたファイル

```
release-outputs/
├── policies/
│   ├── PRIVACY_POLICY.md      ✅ 生成済み
│   ├── SECURITY_POLICY.md     ✅ 生成済み
│   └── TERMS_OF_SERVICE.md    ✅ 生成済み
├── images/
│   └── android/
│       ├── SCREENSHOT_GUIDE.md  ✅ 生成済み
│       └── screenshots/         ← スクリーンショットをここに配置
└── GOOGLE_PLAY_CHECKLIST.md   ✅ このファイル
```

> `builds/android/app-release.{apk,aab}` は debug 鍵で署名された提出不可能な
> ビルドで、リポジトリに直接コミットされていたため削除した（`.gitignore` で
> `release-outputs/builds/` を対象化済み）。提出用ビルドは
> `android/ANDROID_RELEASE_SETUP.md` の手順で都度生成すること。

---

## 🚨 リリース前の最重要 TODO

1. **AdMob App ID / Ad Unit ID** を本番IDに変更（`AndroidManifest.xml`・`ios/Runner/Info.plist`・`--dart-define`）
2. **Android 署名鍵** を作成し `android/ANDROID_RELEASE_SETUP.md` の手順でGitHub Secretsに登録
3. **プライバシーポリシー・利用規約** を公開URLにホスティング（`release-outputs/policies/`。連絡先は現状プレースホルダ `support@petitworksapps.example` のため実際の連絡先メールに差し替えること）
4. **IAP 製品**（`liki_shogi_plan_300`／`liki_shogi_plan_500`）を Google Play Console に登録
5. `isMinifyEnabled`/`isShrinkResources` 有効化後のリリースビルドで主要機能の動作確認
