# Google Play リリースチェックリスト
# 将棋 - Shogi Board（com.petitStudio.shogiApp）

生成日: 2026-05-23 | アプリタイプ: ボードゲーム / 教育（将棋）

---

## ✅ Phase 1: ビルド・署名

- [ ] **Android 署名鍵を作成**
  ```bash
  keytool -genkey -v -keystore shogi_release.jks \
    -alias shogi -keyalg RSA -keysize 2048 -validity 10000
  ```
- [ ] `build.gradle.kts` の `signingConfig` を debug → release に変更
  ```kotlin
  signingConfigs {
    create("release") {
      storeFile = file("shogi_release.jks")
      storePassword = System.getenv("KEY_STORE_PASSWORD")
      keyAlias = "shogi"
      keyPassword = System.getenv("KEY_PASSWORD")
    }
  }
  buildTypes {
    release { signingConfig = signingConfigs.getByName("release") }
  }
  ```
- [x] `flutter build apk --release` で APK 生成 ✅ 55.8MB（release-outputs/builds/android/app-release.apk）
- [x] `flutter build appbundle --release` で AAB 生成 ✅ 46.7MB（release-outputs/builds/android/app-release.aab）
- [x] AAB のサイズ確認 ✅ 46.7MB（推奨 100MB 以下 — OK）
- [ ] Google Play Console で **アプリ署名** を有効化（推奨）

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
  <!-- 現在: テスト用 ca-app-pub-3940256099942544~3347511713 -->
  <meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXX~XXXXXXXXXX"/>  <!-- ← 本番ID -->
  ```
- [ ] 広告ユニットID（Banner/Interstitial）を本番IDに変更
- [ ] テスト端末で広告表示確認

---

## ✅ Phase 4: IAP（アプリ内課金）設定

- [ ] Google Play Console → 収益化 → 製品 で以下を作成:
  | 製品ID | 種別 | 価格 | 説明 |
  |--------|------|------|------|
  | `liki_shogi_no_ads_monthly` | サブスク | ¥250/月 | Proプラン（広告非表示） |
  | `liki_shogi_theme_pack` | 買い切り | ¥120 | テーマパック（エメラルド・桜） |
- [ ] サブスクの自動更新・猶予期間を設定
- [ ] IAP の実機テスト（ライセンステスター登録）

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
- [ ] **アプリ名（日本語）**: 将棋 - Shogi Board
- [ ] **アプリ名（英語）**: Shogi - Japanese Chess Board
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
├── builds/
│   └── android/
│       ├── app-release.apk    ✅ 55.8MB（署名: debug key）
│       └── app-release.aab    ✅ 46.7MB（署名: debug key）
└── GOOGLE_PLAY_CHECKLIST.md   ✅ このファイル
```

---

## 🚨 リリース前の最重要 TODO

1. **Firebase 本番設定** (`firebase_options.dart` を置き換え)
2. **AdMob App ID** を本番IDに変更
3. **Android 署名鍵** を作成して設定
4. **プライバシーポリシー** を公開URLにホスティング
5. **IAP 製品** を Google Play Console に登録
