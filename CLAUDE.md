---
name: shogi_app
description: 将棋アプリ（ミニマル構成）
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

## ファイル構成
```
lib/
├── main.dart
├── screens/
│   ├── tsume_screen.dart          ← 詰将棋
│   ├── network_game_home.dart     ← ネットワーク対局ホーム
│   └── report_user_screen.dart    ← 不正報告画面
├── services/
│   ├── tsume_service.dart
│   └── network_service.dart       ← Firebase通信（認証・対局・報告）
├── models/
│   ├── user_profile.dart          ← ユーザー情報
│   ├── match.dart                 ← 対局情報
│   ├── report.dart                ← 報告情報
│   └── ...（既存モデル）
├── logic/                         ← 将棋ロジック
├── providers/                     ← Riverpod
└── widgets/
```

## 重要ファイル
- `lib/logic/shogi_logic.dart` - 合法手判定・盤面管理
- `lib/models/board.dart` - 盤面表現
- `lib/services/network_service.dart` - Firebase通信（**新機能**）
- `lib/screens/report_user_screen.dart` - 不正報告UI（**新機能**）

## Firebase セットアップ（ネットワーク対局）

### Firestore コレクション
```
users/{uid}/
  - username: string
  - rating: int
  - report_count: int
  - is_banned: bool
  - banned_at: timestamp
  
matches/{matchId}/
  - player1_id, player2_id, board_state, winner, created_at
  
reports/{reportId}/
  - reporter_id, reported_user_id, match_id, reason, status, created_at
```

### 報告ロジック
- ソフト指し・タイムチート等を報告
- 10件の報告 → 自動的にアカウント停止（is_banned=true）

## よく使うコマンド

```bash
rtk flutter pub get
rtk flutter run
rtk flutter test
```

---

**リリース準備**:
```bash
cd ../..
python .claude/skills/flutter-release-complete/scripts/orchestrator.py apps/shogi_app both 10
```
