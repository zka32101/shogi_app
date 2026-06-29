---
name: shogi_app
description: 将棋アプリ（詰将棋 + ネットワーク対局 + AI対局）
---

# shogi_app - 開発ガイド

## プロジェクト概要
将棋アプリ（詰将棋 + ネットワーク対局）。詰将棋はLocal、ネットワーク対局はFirebase連携。

## 技術スタック
- **Flutter**: 3.11.5+
- **状態管理**: Riverpod 2.6.x
- **永続化**: SharedPreferences（詰将棋）
- **Firebase**: Authentication, Firestore, Realtime Database
- **ネットワーク対局**: Firebase（報告機能・アカウント停止）

## 主要ファイル
| ファイル | 役割 |
|---|---|
| `lib/logic.dart` | 将棋ロジック全般（GL, AI, RepetitionChecker, NyugyokuChecker） |
| `lib/game_screen.dart` | ローカル/AI対局画面（~5000行） |
| `lib/screens/match_screen.dart` | ネットワーク対局画面（Firebase RTDB同期） |
| `lib/services/cheat_detection_service.dart` | ソフト指し・遅延行為検出 + InGameSoftPlayTracker |
| `lib/screens/report_user_screen.dart` | 不正報告UI（ブロック機能含む） |
| `lib/screens/match_chat_widget.dart` | 対局チャット（禁止ワードフィルター付き） |
| `lib/services/network_service.dart` | Firebase通信（認証・対局・報告・ブロック） |
| `lib/services/matching_service.dart` | マッチング（ブロック除外対応） |
| `lib/services/board_sync_service.dart` | RTDB盤面同期 |

---

## 実装済み将棋ルール（重要）

### 千日手（RepetitionChecker — logic.dart）
- 4回同一局面 → 千日手（引き分け）
- 連続王手の千日手 → 王手をかけ続けた側の**負け**
- `_posInCheck` マップで初回訪問時の王手状態を記録
- **接続先**: `game_screen.dart/_updateGameState()` / `match_screen.dart/_checkSpecialEndings()`

### 持将棋（NyugyokuChecker — logic.dart）
- 大駒（飛・角）= 5点、小駒 = 1点、玉除外
- 両玉が敵陣入り後、**24点以上**で勝ち（正式ルール準拠）
- 片方のみ24点以上 → その側の勝ち / 両方24点以上 → 引き分け
- **接続先**: `game_screen.dart/_updateGameState()` の千日手チェック直後に組み込み済み
- **接続先**: `match_screen.dart/_checkJishogi()` でも動作（27→24点に修正済み、スコア表示付き）

### 打ち歩詰め・二歩（logic.dart）
- `GL.dropSquares()` 内で両方とも処理済み、追加実装不要

### 行き詰まり
- `hasLegalMove` で検出、`引き分け（行き詰まり）` として処理（千日手と区別）

---

## チート・嫌がらせ検出

### CheatDetectionService — 事後バッチ分析
スコア 0-100、6指標の重み付き平均:
| 指標 | 重み |
|---|---|
| 異常な勝率 | 0.28 |
| 超高速応答（<1秒） | 0.22 |
| レーティング急上昇 | 0.18 |
| 投了パターン | 0.10 |
| 遅延行為（持ち時間80%超を繰り返し） | 0.12 |
| 思考時間の変動係数 CV < 0.08（ソフトのタイマー制御疑い） | 0.10 |

70点以上 → 要注目、85点以上 → 自動フラグ

### InGameSoftPlayTracker — 対局中リアルタイム
- `recordMove(thinkTimeMs, timeLimitMs)` を相手の手番終了ごとに呼ぶ
- `isStallingNow()`: 直近8手中5手以上で80%超 → 遅延行為
- `isUniformThinkTime()`: CV < 0.08 → ソフト疑い
- `match_screen.dart` のストリーム `.map()` 内でターン変化を検出して自動記録
- 試合終了時に `CheatDetectionService.saveInGameTracking()` で Firestore 保存

---

## ブロック機能
- `NetworkService`: `blockUser / unblockUser / isBlocked / getBlockedUserIds`
- Firestore パス: `users/{uid}/blocked_users/{targetUid}`
- マッチング時に自動除外（`matching_service.dart/_tryMatchmaking()` で blocked セット取得）
- 報告画面にブロック/解除トグルボタン

## 報告カテゴリ（report_user_screen.dart）
`soft_play` / `time_cheat` / `abandoned_game` / `intentional_stalling` / `abusive_chat` / `griefing` / `other`

## チャットフィルター（match_chat_widget.dart）
`_bannedWords` 定数リスト（約20語）でクライアント側送信ブロック

## 戻るボタン制御（match_screen.dart）
- `PopScope(canPop: isFinished)` — 試合終了後のみ戻れる
- 対局中に戻ろうとすると「投了して戻る？」ダイアログ
- 「投了して戻る」→ `finishMatchWithRating(..., 'resignation')` で相手に勝利付与

---

## AI エンジン（最新: c059de4）

### アーキテクチャ
| レイヤー | ファイル | 役割 |
|---|---|---|
| Isolateラッパー | `lib/services/ai_isolate.dart` | `compute()` でUIスレッドをブロックしない |
| コアAI | `lib/logic.dart` — `AI` class | α-β + TT + Killer + NMP + QSearch + LMR |
| 棋風設定 | `lib/ai_personality.dart` | attackBias / defenceBias / greedBias / depthBonus |
| やねうら王(Web) | `lib/yaneuraou_service_web.dart` | WASM + Web Worker（Web専用） |
| やねうら王(Mobile) | `lib/yaneuraou_service_stub.dart` | 常にfalse返却 → Dart AIにフォールバック |
| 条件切り替え | `lib/yaneuraou_service.dart` | `export ... if (dart.library.html)` |

### 主要メソッド
- `AI.bestMoveTimed(board, p1h, p2h, aiIsP1, {budget})` — 反復深化（depth=1〜10）+ 時間予算制御
- `AI.topMovesTimed(board, p1h, p2h, aiIsP1, {n, budget})` — 上位N手を反復深化で返す
- `AiIsolate.bestMoveTimed(...)` — Isolate内で bestMoveTimed を実行（UIブロックなし）
- `AiIsolate.topMovesTimed(...)` — Isolate内で topMovesTimed を実行

### LMR（Late Move Reductions）
- `_mm()` 内で手のindex >= 2 かつ depth >= 3 の非戦術手（非取り・非成り・王手なし）を削減
- index 2〜5: reduction=1、index 6+かつdepth>=5: reduction=2
- 削減した手がα/βを改善したら全深度で再探索

### 時間予算テーブル（depth別 ms）
`effectiveDepth` 1〜6: 200 / 350 / 600 / 1000 / 1800 / 3200 ms

### `_runAI()` フロー（game_screen.dart）
1. 序盤20手以内 + depth>=2 → 定跡ブック（50%確率）
2. depth<=3 → `AiIsolate.topMovesTimed()` → 60%/30%/10%でランダム選択
3. depth>=4 → `AiIsolate.bestMoveTimed()`

---

## Firebase Firestore スキーマ
```
users/{uid}/
  - username, rating, wins, losses
  - is_banned, banned_at
  - cheat_score, cheat_flags, flagged_for_review
  - blocked_users/{targetUid}: { blocked_at }

matches/{matchId}/
  - player1_id, player2_id, status, winner
  - moves[]: { player_id, think_time_ms, time_limit_ms }
  - tracking/{userId}: { think_times_ms[], time_usage_ratios[], stalling_score }

reports/{reportId}/
  - reporter_id, reported_user_id, match_id, reason, status

cheat_analysis/{userId}/
  - score, flags, analyzed_at, requires_review
```

---

## 既知の環境問題
- Google Drive パス（`G:\マイドライブ\`）で `flutter analyze` の symlink エラーが出ることがある（コードのエラーではない）
- リリースビルドは C: ドライブにコピーして実行すること

## よく使うコマンド
```bash
flutter pub get
flutter run
flutter build apk --release
```

## リリース準備
```bash
cd ../..
python .claude/skills/flutter-release-complete/scripts/orchestrator.py apps/shogi_app both 10
```
