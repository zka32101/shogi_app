# 効棋（Kouki）— アプリ概念・機能一覧

> Flutter製将棋アプリ。詰将棋・ローカル対局・ネットワーク対局・AI対局を搭載。
> バージョン: v1.1.2+13（2026-06-10時点）
> APK: 67.0MB / minSdk 21 / Flutter 3.11.5+

---

## アプリ概要

| 項目 | 内容 |
|------|------|
| アプリ名 | 効棋（Kouki） |
| ジャンル | 将棋 ボードゲーム |
| ターゲット | 将棋初心者〜中級者 |
| マネタイズ | サブスクリプション（月額）＋買い切りパック2種 |
| バックエンド | Firebase（Auth / Firestore / Realtime Database / Crashlytics） |
| 課金SDK | in_app_purchase ^3.2.0 |
| 広告 | google_mobile_ads ^5.3.0 |

---

## 課金プラン一覧

### 1. サブスクリプション（月額）
- ID: `liki_shogi_no_ads_monthly`
- SharedPrefs key: `subscription_active`

| 特典 | 説明 |
|------|------|
| 広告非表示 | すべての広告をオフ |
| AI週次振り返り | 毎週の対局をAIが詳しく分析 |
| クラウド同期 | 棋譜・設定を自動バックアップ |
| 対局履歴 無制限 | 全ての過去対局を閲覧 |
| プレミアムバッジ | プロフィールに特別マーク表示 |
| キャラアイコン「将軍/天狗/龍王」 | サブスク限定3種を使用可能 |

### 2. テーマパック（買い切り）
- ID: `liki_shogi_theme_pack`
- SharedPrefs key: `theme_pack_purchased`
- 内容: テクスチャー・エメラルド・チェリー テーマ解放

### 3. キャラクターパック（買い切り）
- ID: `liki_shogi_character_pack`
- SharedPrefs key: `character_pack_purchased`
- 内容: 狐火🦊・鷹🦅・虎🐯・狼🐺・鬼👹・仙人🧙 の6種解放

---

## キャラクターアイコン仕様

ファイル: `lib/character_icons.dart`

### ティア別一覧

| ID | 名前 | 絵文字 | 背景色 | ティア |
|----|------|--------|--------|--------|
| samurai | 武士 | ⚔️ | #1565C0（青） | 無料 |
| ninja | 忍者 | 🥷 | #37474F（暗灰） | 無料 |
| kenshi | 剣士 | 🗡️ | #455A64（slate） | 無料 |
| shogun | 将軍 | 👑 | #B8860B（金） | サブスク限定 |
| tengu | 天狗 | 👺 | #C62828（赤） | サブスク限定 |
| ryuou | 龍王 | 🐉 | #4A148C（紫） | サブスク限定 |
| kitsunebi | 狐火 | 🦊 | #E65100（橙） | キャラパック |
| taka | 鷹 | 🦅 | #4E342E（茶） | キャラパック |
| tora | 虎 | 🐯 | #F57F17（黄） | キャラパック |
| ookami | 狼 | 🐺 | #546E7A（青灰） | キャラパック |
| oni | 鬼 | 👹 | #880E4F（暗赤） | キャラパック |
| sennin | 仙人 | 🧙 | #00695C（緑） | キャラパック |

### SharedPreferences キー
- `character_icon_id` — 選択中のキャラID（文字列）

### 表示場所
- ローカル対局 `_playerBar`（game_screen.dart）- 人間プレイヤー側に24×24バッジ
- ネットワーク対局 `_buildPlayerBar`（match_screen.dart）- 自分側に26×26バッジ（cyan枠）
- カスタマイズ画面（customize_screen.dart）- ティア別グリッド選択UI
- プレミアム画面（premium_screen.dart）- キャラパックカード（6種プレビュー付き）

---

## 全実装機能一覧

### 🎯 将棋コア（logic.dart / game_screen.dart）
- 合法手判定（成り・不成・打ち駒含む）
- 9段階ハンデ（平手〜10枚落ち）
- 詰み判定・王手検出
- 千日手検出（盤面ハッシュ4回一致で引き分けダイアログ）
- 持将棋検出（両王が敵陣 + 飛角5点・他1点で双方27点以上）
- フィッシャー方式タイマー（着手後に持ち時間加算 0/5/10/15/30秒）
- 局面メモ（手番単位でテキストメモ、AppBarアンバーアイコン）

### 🤖 AI対局
- Minimax（αβ枝刈り）AIエンジン
- 難易度選択
- コーチモード（手の評価: ★好手/✓良手/？疑問手/✗悪手）
- 評価値バー（リアルタイム先手/後手有利表示）
- AI思考中インジケーター

### 📖 詰将棋
- 複数問題（段位別）
- タイムアタックモード（3分間・ランダム出題・スコア記録）
  - SharedPrefs: `tsume_best_time_{idx}`, `tsume_streak`
- ヒント表示

### 🌐 ネットワーク対局
- Firebase Realtime Database 盤面同期（BoardSyncService）
- マッチング（MatchingService）
- リアルタイムチャット（MatchChatWidget）
- 対局後棋譜分析画面（MatchAnalyzerScreen）
- 不正報告機能（10件でアカウント停止）
- 千日手・持将棋検出（ネットワーク対局でも有効）
- シーズンレーティング・ランキング（SeasonScreen）

### 🎨 カスタマイズ（customize_screen.dart）
- アバターカラー 8色（amber/blue/green/purple/red/teal/orange/pink）
  - SharedPrefs: `avatar_color_idx`
- 表示称号（解除済み実績バッジから選択）
  - SharedPrefs: `display_title`
- キャラクターアイコン（ティア別12種）
  - SharedPrefs: `character_icon_id`
- すべてFirestoreの`users/{uid}`にも同期

### 🏠 UI・画面
- オンボーディング（初回起動時チュートリアル画面）
  - SharedPrefs: `has_launched`
- ホーム画面 タブ（対局 / 詰将棋 / 設定）
- ネットワーク対局ホーム（NetworkGameHomeScreen）
  - シーズンランキング・カスタマイズ・プレミアム・クラブ へのボタン
- プレミアム/ストア画面（PremiumScreen）
- カスタマイズ画面（CustomizeScreen）
- 統計画面（StatsScreen）
- 実績画面（AchievementScreen）
- デイリーチャレンジ（DailyChallengeScreen）
- 友達画面（FriendScreen）
- 通知設定（NotificationSettingsScreen）

### 🏆 クラブ機能（club_screen.dart / club_service.dart）
- 公開クラブ一覧・検索
- マイクラブ（参加中）
- クラブ作成・参加・退出
- クラブ詳細（メンバー一覧）
- **グローバル掲示板**（Firestoreコレクション: `club_bulletin`）
  - テキスト投稿・投稿者名・相対時間表示

### 📊 棋譜・分析
- 棋譜記録（KifuMove）
- 棋譜再生（前後ステップ）
- 局面メモ（手番単位）
- コーチモード（好手/悪手ラベル付き棋譜）

### 🎭 AIキャラクター棋風システム（NEW 2026-06-10）

ファイル: `lib/ai_personality.dart`

**設計思想**: キャラクターをコスメティック商品から「異なる強敵」コンテンツに昇格
- `AiPersonality` クラス（attackBias/defenceBias/greedBias/depthBonus + セリフ辞書）
- `AI.setPersonality(personality, aiIsP1)` で評価関数に重みを注入
- `AI.eval()` 内で各成分（位置ボーナス/持ち駒/玉盾/玉危険度）に係数乗算
- 深さ補正: `effectiveDepth = (aiDepth + depthBonus).clamp(1, 6)`
- 対局前キャラ選択UI（game_setup_screen.dart）
- AIプレイヤーバーにキャラアイコン+名前表示
- セリフバブル: 対局開始/好手反応/悪手反応/勝敗時（3秒表示）

| キャラ | 攻め | 守り | 駒得 | 深さ | 棋風 |
|-------|------|------|------|------|------|
| 武士⚔️ | 1.0 | 1.0 | 1.0 | ±0 | バランス |
| 忍者🥷 | 1.5 | 0.5 | 0.7 | -1 | 奇襲速攻 |
| 剣士🗡️ | 1.3 | 0.8 | 1.0 | ±0 | 攻め型 |
| 将軍👑 | 0.8 | 1.5 | 1.1 | +1 | 堅陣深読み |
| 天狗👺 | 2.0 | 0.3 | 0.6 | ±0 | 超攻撃 |
| 龍王🐉 | 1.0 | 1.2 | 1.3 | +1 | 駒得深読み |
| 狐火🦊 | 1.4 | 0.7 | 0.8 | ±0 | トリッキー |
| 鷹🦅 | 1.2 | 0.9 | 1.0 | ±0 | 機動力 |
| 虎🐯 | 1.6 | 0.6 | 1.4 | ±0 | 攻め+駒得 |
| 狼🐺 | 0.7 | 1.4 | 1.0 | ±0 | 守り粘り |
| 鬼👹 | 2.5 | 0.1 | 0.5 | -1 | 超攻撃自殺 |
| 仙人🧙 | 0.5 | 2.0 | 0.8 | +2 | 超受け深読み |

### ✨ アニメーション・エフェクト（F4）
- 最終着手マス: 黄色フェードアウト（from/to両方）
- 着手駒: スケールバウンス 1.22 → 1.0（`Curves.elasticOut` 600ms）

### 🔧 技術基盤
- Firebase Crashlytics（FlutterError.onError 統合）
- SharedPreferences 永続化
- in_app_purchase（iOS/Android）
- Riverpod 2.6.x 状態管理
- デスギャリング対応（minSdk 21, coreLibraryDesugaring）

---

## Firestore データ構造

```
users/{uid}
  - username: string
  - rating: int
  - season_rating: int
  - season_wins: int
  - season_losses: int
  - avatar_color_idx: int         ← カスタマイズ
  - display_title: string?        ← カスタマイズ
  - character_icon_id: string?    ← キャラアイコン
  - achievements: string[]        ← 解除済みバッジID
  - club_ids: string[]
  - report_count: int
  - is_banned: bool

matches/{matchId}
  - player1_id, player2_id
  - board: string (盤面シリアライズ)
  - player1_time, player2_time: int
  - current_turn: int (1=先手, 2=後手)
  - winner: string?
  - created_at: timestamp

reports/{reportId}
  - reporter_id, reported_user_id, match_id, reason, status, created_at

clubs/{clubId}
  - name: string
  - description: string
  - is_public: bool
  - member_ids: string[]
  - clubs/{clubId}/members/{uid}  ← サブコレクション

club_bulletin/{docId}            ← グローバル掲示板
  - author: string
  - uid: string
  - body: string
  - ts: timestamp
```

---

## SharedPreferences キー一覧

| キー | 型 | 用途 |
|------|----|------|
| `has_launched` | bool | 初回起動フラグ（オンボーディング） |
| `avatar_color_idx` | int | アバターカラーIndex（0-7） |
| `display_title` | string | 表示称号 |
| `character_icon_id` | string | キャラアイコンID |
| `subscription_active` | bool | サブスクリプション状態 |
| `theme_pack_purchased` | bool | テーマパック購入状態 |
| `character_pack_purchased` | bool | キャラパック購入状態 |
| `tsume_best_time_{idx}` | int | 詰将棋ベストタイム（問題別） |
| `tsume_streak` | int | 詰将棋連続正解数 |

---

## PurchaseService API

```dart
// Getters
PurchaseService.hasSubscription  // bool
PurchaseService.hasThemePack     // bool
PurchaseService.hasCharPack      // bool
PurchaseService.isAvailable      // bool

// Methods
await PurchaseService.initialize()         // 起動時
await PurchaseService.purchase()           // サブスク購入
await PurchaseService.purchaseThemePack()  // テーマパック購入
await PurchaseService.purchaseCharPack()   // キャラパック購入
await PurchaseService.restore()            // 購入復元
PurchaseService.dispose()                  // クリーンアップ
```

---

## ファイル構成（主要）

```
lib/
├── main.dart                        ← ホーム・タブ・オンボーディング・Fischer設定
├── game_screen.dart                 ← ローカル対局全機能（コーチ/AI/タイマー/メモ/アニメ）
├── game_setup_screen.dart           ← 対局設定（ハンデ/時間/Fischer）
├── tsume_screen.dart                ← 詰将棋 + タイムアタック + デイリーWordle + ローグライト
├── playstyle_diagnosis_screen.dart  ← 棋風診断（対局データから攻め/守り/打ち駒傾向分析）（NEW）
├── piece.dart                       ← 駒定義・テーマ
├── logic.dart                       ← 将棋ロジック（合法手・評価）
├── theme_config.dart                ← 盤面テーマ設定
├── badge_service.dart               ← 実績バッジ定義
├── ai_personality.dart              ← AI棋風パーソナリティ（NEW）
├── character_icons.dart             ← キャラアイコン定義（NEW）
├── purchase_service.dart            ← 課金サービス（サブスク/テーマ/キャラ）
├── sound_service.dart               ← 効果音
├── screens/
│   ├── match_screen.dart            ← ネットワーク対局（千日手/持将棋/キャラアイコン）
│   ├── network_game_home.dart       ← ネットワークホーム
│   ├── network_board_widget.dart    ← 盤面Widget（ネットワーク用）
│   ├── customize_screen.dart        ← カスタマイズ（色/称号/キャラアイコン）
│   ├── premium_screen.dart          ← ストア（サブスク/テーマパック/キャラパック）
│   ├── club_screen.dart             ← クラブ（一覧/詳細/掲示板）
│   ├── season_screen.dart           ← シーズンランキング
│   ├── ranking_screen.dart          ← レーティングランキング
│   ├── achievement_screen.dart      ← 実績
│   ├── match_history_screen.dart    ← 対局履歴
│   ├── player_profile_screen.dart   ← プレイヤープロフィール
│   ├── report_user_screen.dart      ← 不正報告
│   └── match_chat_widget.dart       ← 対局中チャット
└── services/
    ├── network_service.dart         ← Firebase通信（認証・ユーザー管理）
    ├── matching_service.dart        ← マッチメイキング
    ├── board_sync_service.dart      ← 盤面リアルタイム同期
    └── club_service.dart            ← クラブCRUD
```

---

## 実装済み革新機能（2026-06-10追加）

| ID | 機能 | 実装ファイル |
|----|------|-------------|
| I4 | デイリー詰将棋Wordle化 | tsume_screen.dart (DailyTsumeScreen) |
| I5 | ローグライトタイムアタック | tsume_screen.dart (TsumeRogueliteScreen) |
| I3 | 棋風診断 | playstyle_diagnosis_screen.dart |

### SharedPrefs キー（新規）
- `daily_wordle_{yyyymmdd}_attempts` → List\<String\> ['pending'/'solved'/'failed'] × 3
- `daily_wordle_{yyyymmdd}_solved` → bool
- `roguelite_best_score` → int (最高正解数)
- `playstyle_attack` / `playstyle_retreat` / `playstyle_drop` / `playstyle_total` → int (累計手数)
- `playstyle_games` → int (分析済み対局数)

---

## 未実装・残課題

| ID | 機能 | 優先度 | 備考 |
|----|------|--------|------|
| C1 | クラブ内対局マッチング | 中 | 同クラブのユーザーを優先マッチング |
| F2 | 盤面テーマ完全適用 | 低 | ネットワーク対局盤でもテーマ適用 |
| G1 | プッシュ通知（対局招待） | 中 | firebase_messaging 設定済み |
| H1 | AI週次振り返りレポート | 中 | サブスク特典・Claude API要 |
| I1 | クラウド棋譜バックアップ | 中 | サブスク特典 |
| J1 | スペクテーター（観戦） | 低 | SpectatorScreen 存在 |

---

## ビルド手順（APK）

```bash
# 1. ファイルをコピー（日本語パス回避）
cp -r "[REDACTED_LOCAL_PATH]/apps/shogi_app/lib" "/c/apk/shogi_app/"

# 2. Gradleデーモン停止（キャッシュ破損対策）
cd "/c/apk/shogi_app" && ./gradlew --stop

# 3. APKビルド
flutter build apk --release --no-tree-shake-icons

# 4. APKコピー
cp "/c/apk/shogi_app/build/app/outputs/flutter-apk/app-release.apk" \
   "[REDACTED_LOCAL_PATH]/apk/shogi_app-app-release.apk"
```

**注意**: `H:\` 日本語パスでは Gradle がクラッシュするため `C:\apk\` にコピーしてビルドすること。

---

## Google Play 申請チェックリスト

- [ ] スクリーンショット作成（電話: 2〜8枚、タブレット任意）
- [ ] ストア説明文（日本語）
- [ ] アイコン 512×512px
- [ ] フィーチャーグラフィック 1024×500px
- [ ] プライバシーポリシーURL
- [ ] コンテンツレーティング回答
- [ ] 課金商品をPlay Consoleに登録（3商品）
- [ ] 署名APK（keystore設定）
