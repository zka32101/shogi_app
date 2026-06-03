# shogi_app（効棋 / Kouki）プロジェクト進捗

## 概要
- **製品名**: 効棋 (Kouki) — AI対局・定跡学習・棋譜管理アプリ
- **屋号**: Petit Studio
- **バージョン**: v1.0.10+10
- **最終更新**: 2026-06-02
- **プラットフォーム**: Flutter (Android / iOS / Web)

## ⚠️ 重要：開発パス（2026-06-02 移行）
- **ソースコード（現行）**: `G:\マイドライブ\apps\shogi_app\` ← 今後はここで開発
- **APK 保存先**: `G:\マイドライブ\apk\`
- **旧パス（参照のみ）**: `C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\`
- Google Drive 側で git 初期化済み（commit: f09c572 "Initial commit"、remote なし）

## 技術スタック
- Flutter ^3.11.5 / Dart ^3.11.5
- Riverpod ^2.6.1（状態管理）
- Firebase Realtime Database（ネットワーク対局）
- in_app_purchase ^3.2.0 / google_mobile_ads ^5.3.0
- share_plus ^7.0.0（X投稿）/ path_provider ^2.1.2
- CustomPainter（盤面描画）

## 実装済み機能（v1.0.10）
- AI対局（難度: ランダム/初級/中級/上級）、ネットワーク対局、ローカル対局、観戦
- 棋譜再生（自動再生 1.5秒/手、終盤10手は2秒/手）
- 動画録画→MP4→X(Twitter)投稿（投稿しなければ削除）
- テーマ6種: standard, dark, zen, emerald, cherry, **textured**（質感あり）
- 変則ルール6種（VariantType: normal, captureForced, checkForced, hiddenPieces, kagemusha, invader）
- 囲い方ガイド（矢印表示）、定跡、手筋、詰将棋、格言
- 感想戦（AI対局ボタン＋検討モード）、AI候補手リアルタイム表示
- 千日手・持将棋判定、棋譜フィルター・ソート、局面画像DL、音声読み上げ
- バッジ、レーティング、勝率グラフ、週次AI振り返り(Premium)
- Web PWA 対応

## 主要ファイル（lib/）
- `main.dart` — エントリ、4タブ（対局/棋譜/学習/設定）
- `game_screen.dart` — メイン対局、BoardPainter、GameMode/GameSettings/AILevel/VariantType/PieceTheme 定義
- `theme_config.dart` — BoardThemeConfig（テーマ色一元管理）
- `kifu_replay_screen.dart` — 棋譜自動再生＋録画
- `tutorial_screen.dart` — チュートリアル（詰み盤面デモ含む）
- `ai_service.dart` / `ai_data_service.dart` — AIエンジン
- `castle_guide_service.dart` — 囲い方ガイド
- 全54 Dartファイル

## 引き継ぎドキュメント（旧パスに存在）
- CODE_HANDOVER_2026-05-29.md（詳細リファレンス）
- QUICK_SETUP_CHECKLIST.md（5分セットアップ）
- VSCODE_SETUP_GUIDE.md（IDE設定）
- HANDOVER_SUMMARY.md（総合ガイド）

## 📌 次のアクション：「将棋アプリ1位」戦略（2026-06-02 提案）

### 差別化戦略
**「初心者を最速で強くする学習特化型」×「気軽なオンライン対局」**
- 競合1位の将棋ウォーズ（700万DL）は対局・段位が核だが、学習・初心者育成・UXが弱い
- 効棋はその空白市場（"入口で挫折する層"の救済）を狙う

### 最短アクション TOP3（実装候補）
1. **AI指導対局＋1局講評**（最大の差別化／既存の候補手表示・感想戦を発展＝最速実装可）
   - 対局中リアルタイム評価、待った→正着教示コーチモード、1局ごとAI講評レポート、弱点克服カリキュラム自動生成
2. **詰将棋1000問＋デイリー**（集客の入口・継続の核）
   - 1〜15手詰、日替わり詰将棋、ランキング、連続正解、タイムアタック
3. **段位認定付きオンライン**（権威付け・口コミ源）
   - 15級〜九段、持ち時間バリエーション、フェアプレー対策（AI検知/通報）、観戦/再戦/フレンド

### その他優先機能
- 段位別レッスン体系化、デイリーミッション/ストリーク、棋力推移グラフ
- プロ棋譜閲覧（藤井聡太人気活用）、道場/クラン、月例トーナメント
- 子供向け（ひらがな）/高齢者向け（大駒）モード、多言語対応（海外＝競合不在）

### マネタイズ
- 無料（対局・基本詰将棋・広告）/ プレミアム ¥480/月（AI講評し放題・全レッスン・広告なし・詰将棋全問）/ 単発課金（テーマ・駒）
- 主軸＝「AI講評し放題」の月額（ウォーズの"棋神"成功モデルの発展）

**→ 次セッション: 上記TOP3のどれから着手するか決定 → 設計・実装。最有力は「AI指導対局」（既存資産を活かせる）**

## 既知の課題・注意点
- リリースビルド（`flutter build apk --release`）で DartWorker メモリエラー発生実績
  → 回避策: デバッグビルド `flutter build apk --debug --no-shrink` を使用
- `flutter clean` が .dart_tool/ephemeral のロックで失敗することあり
- Google Drive 上の git は index.lock が残りやすい（PowerShell で削除して対応）

---
詳細は CLAUDE.md / 旧パスのハンドオーバー資料を参照。
