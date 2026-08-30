# 対人対局安定性確認・UI/UX改善計画

**実施日**: 2026-08-29  
**対象**: ネットワーク対局機能全般（安定性・UI・ゲームバランス）  
**目標**: 複数ユーザーでの対局テスト・フィードバック収集・改善実装

---

## 📋 全体フロー

```
Phase 1: テスト環境構築 (1-2日)
   ├─ テスト用アカウント複数作成
   ├─ Firebase ローカルテスト設定
   └─ ログ・メトリクス収集仕組み構築
        ↓
Phase 2: 対人対局安定性テスト (3-5日)
   ├─ リアルタイム通信遅延測定
   ├─ 複数対局同時進行テスト
   ├─ タイムアウト処理検証
   └─ 通信切断時復帰テスト
        ↓
Phase 3: UI/UX 改善 (2-3日)
   ├─ 棋盤表示改善
   ├─ 駒操作性改善
   ├─ 対局履歴機能追加
   └─ チャット・マナー機能実装
        ↓
Phase 4: ゲームバランス検証 (2-3日)
   ├─ レーティングシステム精度確認
   ├─ マッチメイキング公平性確認
   └─ 段位進級条件妥当性確認
```

---

## Phase 1: テスト環境構築

### 1.1 テスト用アカウント作成

**3-5 個のテストアカウント を Firebase Authentication で作成**:

```bash
# Firebase CLI でテストユーザー作成（またはコンソール）
# 例:
# test_player_1@example.com
# test_player_2@example.com
# test_player_3@example.com
```

### 1.2 ログ・メトリクス収集フレームワーク

**`lib/services/stability_metrics_service.dart` を新規作成**:

```dart
class StabilityMetricsService {
  // リアルタイム通信遅延を計測
  Future<int> measureNetworkLatency() async {
    final start = DateTime.now();
    // ping 的な疎通確認
    final end = DateTime.now();
    final latency = end.difference(start).inMilliseconds;
    return latency;
  }

  // 対局中の通信イベントを記録
  void logMatchEvent(String matchId, String event, Map<String, dynamic> data) {
    // イベントログ: 盤面更新・チャット・タイムアウト等
    print('[MATCH $matchId] $event: $data');
  }

  // パフォーマンスメトリクス集約
  Future<Map<String, dynamic>> collectMetrics() async {
    return {
      'latency_ms': await measureNetworkLatency(),
      'timestamp': DateTime.now(),
    };
  }
}
```

---

## Phase 2: 対人対局安定性テスト

### 2.1 リアルタイム通信遅延測定

**テスト内容**:
1. Player A が手を指す → Player B が受信するまでの時間を計測
2. 1-5 秒の遅延を測定して記録
3. 複数対局で平均遅延を計算

**期待値**: 平均 500ms 以下

**実装**: `board_sync_service.dart` に遅延ログ追加

```dart
// 既存コード (board_sync_service.dart)
void _syncBoardState(String matchId, String boardState) async {
  // ここに以下を追加
  final startTime = DateTime.now();
  
  // Firebase に盤面更新を送信
  await FirebaseDatabase.instance
      .ref('games/$matchId/board_state')
      .set(boardState);
  
  final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
  print('📊 盤面同期遅延: ${elapsedMs}ms');
}
```

### 2.2 複数対局同時進行テスト

**テスト内容**:
- 3 個のテスト用アカウントで同時に複数対局を開始
- 各対局が独立して正常に動作するか確認
- メモリ・CPU 使用率が上昇しないか確認

**期待値**: 複数対局でも各対局は独立して正常に動作

**チェックリスト**:
- [ ] Match 1: Player A vs Player B
- [ ] Match 2: Player B vs Player C
- [ ] Match 3: Player A vs Player C
- [ ] 各対局で盤面が正確に同期される
- [ ] チャットが混同されない
- [ ] タイマーが独立して動作

### 2.3 タイムアウト処理検証

**テスト内容**:
1. Player A が手を指さない状態で 5 分放置
2. タイムアウト判定が正確に動作するか確認
3. 自動投了が実行されるか確認

**期待値**: 5 分後に自動投了 + 相手に勝利付与

**実装確認**: `functions/index.js` の `checkTimeouts` トリガー

```javascript
// 既存: Cloud Functions
exports.checkTimeouts = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    // 5分以上対局が進まないゲームを検出
    // 自動投了を実行
  });
```

### 2.4 通信切断時復帰ロジック

**テスト内容**:
1. Player A の通信を意図的に遮断（Wi-Fi オフ）
2. 5-30 秒後に復帰
3. 対局が正常に再開するか確認

**期待値**: 通信復帰後、盤面・対局状態が完全に復元される

**チェックリスト**:
- [ ] 通信切断時: UI に警告表示
- [ ] 通信復帰時: 自動的に盤面同期
- [ ] 手番が正確に復元される
- [ ] 手番判定エラーなし

**実装**: `network_game_home.dart` に復帰ロジックを追加

```dart
// 例: 通信復帰時のリコンシリエーション
void _onConnectivityChanged(ConnectivityResult result) {
  if (result != ConnectivityResult.none) {
    // 通信復帰 → 最新盤面を再取得
    _syncBoardWithServer();
    print('🔄 対局を再同期しました');
  }
}
```

---

## Phase 3: UI/UX 改善

### 3.1 棋盤表示改善

**現在の問題**:
- 駒のサイズが小さくて見づらい場合がある
- 手番の視認性が低い
- 最後の手の位置が不明確

**改善案**:

1. **駒のサイズ拡大**
   - 現在: 36×36 px
   - 改善後: 44×44 px（10% 拡大）
   
2. **手番表示の改善**
   - 色をより目立つ色に変更（AppTheme.primary → AppTheme.accent）
   - テキストサイズを大きく
   
3. **最後の手を強調**
   - 前回の駒の移動元・移動先をハイライト表示
   - 背景色を変更（黄色・薄い背景）

**ファイル**: `lib/widgets/shogi_board_widget.dart`

### 3.2 駒の移動操作改善

**現在の問題**:
- タップの認識領域が狭い
- ドラッグ開始位置の判定が厳密すぎる
- 誤操作が多い可能性

**改善案**:

1. **タップ領域を拡大**
   - 駒の中心から±5px の範囲を有効区間に
   
2. **ドラッグ開始条件を緩和**
   - ドラッグ開始までの移動距離: 10px → 5px
   
3. **フィードバック改善**
   - 駒を持ち上げた時の視覚フィードバック（拡大・影）
   - 合法手の移動先をハイライト表示

**ファイル**: `lib/widgets/network_board_widget.dart`

### 3.3 対局履歴表示・検索機能

**新機能実装**:

1. **対局履歴画面を改善**
   - 日時・相手プレイヤー・結果・レーティング変化を表示
   - 検索機能: 相手名・結果・日付範囲で絞り込み
   - ソート機能: 最新順・古い順・レーティング変化の大きい順

2. **棋譜再生機能**
   - 過去対局の手順を再生
   - 前後の手を切り替え
   - 特定の局面を保存・コメント機能

**ファイル**: `lib/screens/match_history_screen.dart` を拡張

### 3.4 チャット・マナー機能実装

**現在の問題**:
- チャットが簡素
- スポーツマンシップ的な機能がない

**改善案**:

1. **定型チャット（クイックメッセージ）**
   - 「頑張ります」「よろしく」「ありがとう」等のボタン
   - クリック 1 つで送信

2. **対局マナー機能**
   - 「引き分け提案」（既存・確認）
   - 「投了」ボタン（確認ダイアログ付き）
   - 「悔い改めて」「次の対局へ」（対局終了後）

3. **相手の評価機能**
   - 対局終了後に相手を 1-5 つ星で評価
   - 高マナーユーザーを表示・優遇マッチング

**ファイル**: `lib/screens/match_chat_widget.dart` を拡張

---

## Phase 4: ゲームバランス検証

### 4.1 レーティングシステム精度確認

**テスト内容**:

1. **ELO 計算精度**
   - 既知の結果（強者 vs 弱者）でレーティング変化を検証
   - 期待値（ELO 計算式が正確）と一致するか確認

2. **段位間の実力差**
   - 段位別に統計データ収集
   - 同段位プレイヤーの勝率が 50% に近いか確認
   - 隣接段位の勝率が適切（60-40 程度）か確認

**実装**: `lib/services/rating_service.dart` にテストケース追加

```dart
// テストケース例:
void testEloCalculation() {
  // 初期: Player A = 1600, Player B = 1400
  // 結果: Player A が勝利
  
  final newRatings = calcElo(1600, 1400, true);
  // 期待値: Player A ≈ 1608, Player B ≈ 1392
  
  assert(newRatings['player_a'] > 1600);
  assert(newRatings['player_b'] < 1400);
}
```

### 4.2 マッチメイキング公平性確認

**テスト内容**:

1. **マッチング精度**
   - ランダムに複数プレイヤーをマッチング
   - マッチングされたペアの実力差が適切か確認
   - 実力差が大きすぎるペアが生成されないか確認

2. **ブロック機能の正常動作**
   - Player A が Player B をブロック
   - マッチング時に Player A と Player B がマッチングされないか確認

3. **連勝・連敗の回避**
   - 同じ相手との重複マッチングが少ないか確認
   - 得意・不得意な相手が偏らないか確認

**実装**: `lib/services/matching_service.dart` にテストロジック追加

### 4.3 段位進級条件の妥当性確認

**テスト内容**:

段位システムが明確に定義されているか確認

（未実装の場合は実装）

例：
- 初段: 1400-1500
- 二段: 1500-1600
- 三段以上: 1600+

---

## 🧪 テスト実行計画

### テスト期間: 2 週間

| 週 | フェーズ | タスク |
|---|---|---|
| Week 1 | Phase 1, 2 | テスト環境構築 + 安定性テスト |
| Week 1-2 | Phase 3 | UI/UX 改善実装 |
| Week 2 | Phase 4 | ゲームバランス検証 |

---

## 📊 テスト結果記録フォーマット

### 通信遅延測定

```
[Test: Network Latency]
Date: 2026-08-29
Test Condition: 2 players, Japan region
Results:
  - Move 1: 342ms
  - Move 2: 287ms
  - Move 3: 451ms
  - Average: 360ms
Status: ✅ PASS (< 500ms)
```

### 対局テスト

```
[Test: Multiplayer Stability]
Date: 2026-08-29
Participants: test_player_1, test_player_2, test_player_3
Matches Played:
  - Match 1 (A vs B): ✅ Completed normally
  - Match 2 (B vs C): ✅ Completed normally
  - Match 3 (A vs C): ✅ Completed normally
Observations: All matches synchronized correctly
Status: ✅ PASS
```

---

## ✅ テスト完了チェックリスト

- [ ] テスト用アカウント 3-5 個作成
- [ ] StabilityMetricsService 実装
- [ ] ネットワーク遅延測定（目標: 500ms 以下）
- [ ] 複数対局同時進行テスト（目標: 3 対局同時）
- [ ] タイムアウト処理テスト（目標: 正確に 5 分後投了）
- [ ] 通信切断復帰テスト（目標: 30 秒以内に再同期）
- [ ] 棋盤表示改善実装
- [ ] 駒操作性改善実装
- [ ] 対局履歴機能実装
- [ ] チャット・マナー機能実装
- [ ] ELO 計算精度検証
- [ ] マッチメイキング公平性検証
- [ ] 段位システム確認

---

## 📝 実装優先度

### 優先度 A（即座に実装）:
1. ネットワーク遅延測定・ログ機能
2. 通信切断復帰ロジック
3. UI 改善（棋盤表示・駒操作）

### 優先度 B（次フェーズ）:
1. 対局履歴機能拡張
2. チャット・マナー機能
3. ゲームバランス検証

### 優先度 C（オプション）:
1. 段位システム実装
2. マナースコア表示
3. 対局分析機能

---

## 🎯 目標

✅ **安定性**: ネットワーク遅延 < 500ms、通信復帰 < 30 秒  
✅ **UI/UX**: ユーザーが直感的に操作できる棋盤  
✅ **ゲームバランス**: 公平で楽しい対局体験

**完了予定**: 2026-09-12（2 週間）

---

最初に実装すべき改善を確認してから、実装を開始します。
