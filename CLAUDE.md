---
name: shogi_app
description: 将棋アプリ（ミニマル構成）
---

# shogi_app - 開発ガイド

## プロジェクト概要
シンプルな将棋盤UI + ルール実装。SharedPreferences で棋譜保存。

## 技術スタック
- **Flutter**: 3.11.5+
- **状態管理**: Riverpod 2.6.x
- **永続化**: SharedPreferences

## ファイル構成
```
lib/
├── main.dart
├── screens/          (画面)
├── logic/            (将棋ロジック・合法手判定)
├── models/           (盤面・駒モデル)
├── providers/        (Riverpod)
└── widgets/          (UI Widget)
```

## 重要ファイル
- `lib/logic/shogi_logic.dart` - 合法手判定・盤面管理
- `lib/models/board.dart` - 盤面表現

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
