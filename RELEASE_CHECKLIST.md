# 将棋アプリ リリースチェックリスト

**リリース日**: ___________  
**アプリバージョン**: 1.0.0  
**リリースマネージャー**: __________

---

## Phase 1: 開発・コード準備

### コード品質
- [x] 全機能テスト完了（ローカル詰将棋）
- [x] 全機能テスト完了（ネットワーク対局）
- [x] セキュリティレビュー完了（TOCTOU対策等）
- [x] Firebase Cloud Functions レビュー完了
- [x] エラーハンドリング実装確認
- [ ] 最終本番環境テスト完了

### ドキュメント
- [x] プライバシーポリシー作成（HTTPS URL化）
- [x] 利用規約作成（HTTPS URL化）
- [x] セキュリティポリシー作成
- [x] メールアドレス統一（yourwishdev@gmail.com）
- [ ] ユーザーガイド作成（オプション）

### Git/ビルド
- [x] 全修正をブランチにコミット
- [x] コード検査完了（flutter analyze エラーなし）
- [x] 依存関係アップデート確認

---

## Phase 2: 環境・ツール準備

### ローカル環境
- [ ] Flutter 3.11.5+ インストール確認
- [ ] Java JDK 11+ インストール確認（Android）
- [ ] Xcode 14.0+ インストール確認（iOS）
- [ ] Android Gradle Plugin 更新確認

### キー・認証情報
- [ ] Android キーストア生成（shogi_app_release_key.jks）
- [ ] キーストアパスワード安全保管
- [ ] iOS Developer Account 登録確認
- [ ] Apple Team ID 確認
- [ ] iOS Provisioning Profile 設定完了

### Firebase設定
- [ ] Firebase Console petit-works-games に iOS Bundle ID 登録
- [ ] iOS GoogleService-Info.plist ダウンロード
- [ ] android/app/build.gradle に Google Services Plugin 確認
- [ ] iOS pod install 実行完了

---

## Phase 3: アセット準備

### アプリアイコン
- [ ] 512×512 px PNG アイコン作成
- [ ] 1024×1024 px 高解像度版作成
- [ ] Android Adaptive Icon 設計（レイヤー分離）
- [ ] iOS App Icon Set 設定完了
  - AppIcon.appiconset に 20×20, 29×29, ... 1024×1024 配置

### スクリーンショット（Google Play）
- [ ] スクリーンショット1: ローカル詰将棋画面 (1440×900)
- [ ] スクリーンショット2: AI対局画面 (1440×900)
- [ ] スクリーンショット3: ネットワーク対局・対局選択 (1440×900)
- [ ] スクリーンショット4: 対局チャット・報告機能 (1440×900)
- [ ] スクリーンショット5: ユーザープロフィール・統計 (1440×900)
- [ ] 各スクリーンショットに説明テキスト追加

### スクリーンショット（App Store）
- [ ] スクリーンショット1: iPhone SE サイズ対応 (1125×2436)
- [ ] スクリーンショット2-5: 上記に準じる
- [ ] iPad スクリーンショット作成（オプション: 2048×2732）

### プロモーション画像
- [ ] Google Play プロモ用グラフィック (1024×500)
- [ ] App Store プレビュー画像 (1200×630)

---

## Phase 4: メタデータ準備

### Google Play Console
- [ ] アプリタイトル: 「将棋 - 詰将棋・対局」
- [ ] 短説明作成: 80文字以内
- [ ] 完全な説明作成: 最大4000文字
  - 見出し・段落・プレイ方法説明・FAQ含む
- [ ] カテゴリ: ゲーム > ボードゲーム
- [ ] コンテンツレーティング: 回答済み
  - 暴力・差別・性的内容なし確認
- [ ] プライバシーポリシー URL 設定
- [ ] 連絡先メール設定: yourwishdev@gmail.com
- [ ] サポートメール設定
- [ ] サポート URL 設定

### App Store Connect
- [ ] アプリ名: 「将棋 - 詰将棋・対局」
- [ ] サブタイトル: 「オンライン対局・AI・詰将棋」
- [ ] プロモ用テキスト作成: 170文字以内
- [ ] キーワード: 将棋,詰将棋,オンライン,AI,ボード
- [ ] 説明: 4000文字以内
- [ ] スクリーンショット: 5-20枚
- [ ] プレビュー動画: オプション（30秒以内）
- [ ] 年齢制限区分: 4+（暴力・差別表現なし）
- [ ] カテゴリ: ゲーム > ボードゲーム
- [ ] プライバシーポリシー URL
- [ ] 利用規約 URL
- [ ] サポート URL
- [ ] マーケティング URL: オプション

---

## Phase 5: 本番環境設定

### AdMob 設定
- [ ] Google AdMob アカウント作成
- [ ] アプリ登録完了
- [ ] **本番 App ID 取得**: ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
- [ ] AndroidManifest.xml に本番ID 設定
- [ ] テスト用 Ad Unit ID 削除確認
- [ ] AdMob Console で配置確認

### Firebase 本番設定
- [ ] Firebase Console にて Crashlytics 有効化
- [ ] Firebase Analytics 有効化確認
- [ ] Firestore セキュリティルール確認（本番モード）
- [ ] Realtime Database セキュリティルール確認
- [ ] Cloud Functions デプロイ確認
  - onMatchFinished（ELO計算）
  - cleanupStale（タイムアウト処理）
  - checkTimeouts（タイムアウト検出）

### iOS 本番設定
- [ ] GoogleService-Info.plist 配置確認
- [ ] Xcode Build Phases に plist を Copy Bundle Resources に追加確認
- [ ] Signing Certificate（開発・配布）取得
- [ ] Provisioning Profile（App Store 配布）設定

---

## Phase 6: ビルド・テスト

### Android ビルド
- [ ] `flutter clean` 実行
- [ ] `flutter pub get` 実行
- [ ] `flutter build apk --release` 実行成功
- [ ] リリース APK テスト実機へインストール
- [ ] `flutter build appbundle --release` 実行成功
- [ ] App Bundle Google Play Console で検証

### iOS ビルド（Mac）
- [ ] `flutter clean` 実行
- [ ] `pod install --repo-update` 実行（ios/）
- [ ] `flutter build ios --release` 実行成功
- [ ] Xcode で Archive 作成成功
- [ ] App Store Connect へアップロード成功

### 機能テスト
- [ ] ローカル詰将棋モード動作確認
- [ ] AI対局動作確認（複数レベル）
- [ ] ネットワーク対局作成・参加確認
- [ ] リアルタイム盤面同期確認
- [ ] 対局チャット送信・受信確認
- [ ] 報告機能動作確認
- [ ] ブロック機能動作確認
- [ ] 通知受信確認（FCM）
- [ ] ELO レーティング計算確認

### パフォーマンステスト
- [ ] 30分以上対局でメモリリークなし
- [ ] AI計算中 UI フリーズなし
- [ ] 回線断から復帰 正常確認
- [ ] バッテリー使用量正常範囲

### セキュリティテスト
- [ ] バンユーザープレイ禁止確認
- [ ] ELO 二重適用なし確認
- [ ] チート検出スコア算出確認
- [ ] XSS・SQLi対策確認

---

## Phase 7: ストア提出

### Google Play Console
- [ ] アプリ登録完了
- [ ] 全メタデータ入力完了
- [ ] アプリバイナリ (AAB) アップロード完了
- [ ] Google Play ポリシー確認
  - [ ] 年齢層フィルター対応
  - [ ] プライバシー要件満たす
  - [ ] 広告ポリシー準拠
- [ ] レビュー申請完了
- [ ] ステータス監視（レビュー中...）

### App Store Connect
- [ ] アプリ登録完了
- [ ] 全メタデータ入力完了
- [ ] ビルド (IPA) アップロード完了
- [ ] App Store ガイドライン確認
  - [ ] デザイン品質基準クリア
  - [ ] パフォーマンス基準クリア
  - [ ] プライバシー要件満たす
  - [ ] 広告ID (IDFA) 設定確認
- [ ] レビュー申請完了
- [ ] ステータス監視（審査中...）

---

## Phase 8: リリース・監視

### リリース戦略
- [ ] Google Play: 段階的ロールアウト設定
  - Day 1-2: 20% ユーザー
  - Day 3-5: 50% ユーザー
  - Day 6+: 100% ロールアウト
- [ ] App Store: 自動リリース OR 手動承認決定
- [ ] リリース日時スケジュール確定

### リリース直後監視（初1週間）
- [ ] Daily: クラッシュレポート確認（Firebase Crashlytics）
- [ ] Daily: ユーザーレビュー・評価監視
- [ ] Daily: Firebase Analytics ダッシュボード確認
  - インストール数トレンド
  - セッション数
  - ユーザー保持率
- [ ] Daily: エラーログ確認（Cloud Logging）

### 段階的ロールアウト監視
- [ ] Day 2 終了時: クラッシュ率・エラー率 < 0.1%
- [ ] Day 5 終了時: 平均レーティング > 4.0 星
- [ ] 重大バグ報告なし → 100% ロールアウト判断

---

## Phase 9: ポストリリース

### ユーザーサポート
- [ ] サポートメール確立
- [ ] FAQ ドキュメント公開
- [ ] よくある質問への対応マニュアル作成

### アナリティクス・KPI 監視
- [ ] DAU（Daily Active Users）トレンド
- [ ] セッション長さ（平均プレイ時間）
- [ ] ユーザー保持率（Day 1, 7, 30）
- [ ] Crash-free users %（目標: > 99.5%）
- [ ] 平均レーティング（目標: > 4.0）

### アップデート計画
- [ ] バグ修正リリース（不具合報告時）
- [ ] 機能追加ロードマップ作成
- [ ] 次バージョン（1.1）計画開始

---

## 署名・承認

| 役割 | 名前 | 署名 | 日付 |
|---|---|---|---|
| 開発者 | | | |
| QA担当者 | | | |
| リリースマネージャー | | | |
| プロジェクトマネージャー | | | |

---

**最後に**: このチェックリストは逐次更新してください。  
各フェーズ完了時に `✓` または日時を記入し、リリース履歴として保管してください。
