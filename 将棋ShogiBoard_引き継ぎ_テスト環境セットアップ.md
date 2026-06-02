# 将棋 ShogiBoard — テスト環境引き継ぎ文書

**作成日**: 2026-05-25  
**対象**: Android USB接続可能な Windows 環境  
**目的**: クラッシュ原因の特定・ログ取得・動作確認

---

## 1. アプリ概要

| 項目 | 内容 |
|------|------|
| アプリ名 | 将棋 - Shogi Board |
| パッケージ名 | com.petitStudio.shogiApp |
| バージョン | 1.0.0 (build 1) |
| Flutter | 最新安定版 |
| APK場所 | `G:\マイドライブ\将棋ShogiBoard-v1.0.0-release.apk` |

---

## 2. 現在の状況・既知の問題

### ✅ 修正済み（最新APKに適用済み）
- Firebase ContentProvider の自動初期化を無効化（`google-services.json` なし環境でクラッシュしていた）
- sentry_flutter を依存関係から削除（未使用だが起動時に干渉していた）
- JVM メモリ設定最適化（SerialGC、-Xmx1536m）
- R8 最適化を無効化（OOM ビルドクラッシュ対策）

### ❓ 未確認（今回テストしてほしいこと）
- 最新APKで起動クラッシュが解消されているか
- 各画面が正常に動作するか（下記チェックリスト参照）

---

## 3. テスト手順

### Step 1: ADB 環境確認
```cmd
adb version
adb devices
```
デバイスが `device` と表示されればOK。  
表示されない場合：
- スマホ：設定 → 開発者向けオプション → USBデバッグ ON
- USBケーブルで接続
- スマホのポップアップ「このパソコンを常に許可」→ OK

### Step 2: APK インストール
```cmd
adb install -r "G:\マイドライブ\将棋ShogiBoard-v1.0.0-release.apk"
```

### Step 3: ログ取得しながら起動
**コマンドプロンプト（管理者）で：**
```cmd
adb logcat -c
adb logcat -v time > C:\将棋_crash_log.txt
```
別ウィンドウでアプリ起動 → クラッシュしたら Ctrl+C でログ停止。

### Step 4: Flutter セッションで開く場合（推奨）
プロジェクトを Claude Code で開いて以下を実行：
```cmd
cd C:\path\to\shogi_app
flutter run
```
コンソールにスタックトレースがリアルタイム表示される。

---

## 4. 動作確認チェックリスト

### 基本動作
- [ ] アプリ起動（クラッシュしないか）
- [ ] ホーム画面表示（4タブ：対局・棋譜・学習・設定）
- [ ] AI対局（先手・後手どちらでも）
- [ ] 対局中に駒を動かせるか

### 修正箇所の確認
- [ ] **定跡ガイド** → 飛車・角の初期位置が正しいか（飛車=2八/8二、角=7七/3三付近）
- [ ] **棋力判断** → 自分の番で自分の駒を操作できるか（上側の駒で操作させられるバグが修正済み）
- [ ] **棋力判断** → 自分の駒（青）と相手の駒（赤）が色で区別できるか
- [ ] **棋力判断** → いろいろな局面が出てくるか（ほぼ同じ盤面が続くバグが修正済み）
- [ ] **オンライン対局** → 部屋作成時に先後がランダムで決まるか
- [ ] **観戦** → ルームコード入力ではなく対局一覧が表示されるか

### ログで確認してほしいエラー
```
adb logcat flutter:V AndroidRuntime:E *:S
```
`FATAL EXCEPTION` や `FlutterError` が出た場合はテキストを保存して共有。

---

## 5. プロジェクト構成（Claude Code で開く場合）

```
プロジェクトルート:
C:\Users\Administrator\OneDrive\subwork\smartphone\smart-claude-code\shogi_app\

主要ファイル:
lib/main.dart                    — エントリポイント
lib/game_screen.dart             — 対局画面
lib/joseki_screen.dart           — 定跡ガイド（飛車角修正済み）
lib/strength_test_screen.dart    — 棋力判断（盤反転・色区別修正済み）
lib/network_lobby_screen.dart    — オンラインロビー（観戦一覧修正済み）
lib/network_game_service.dart    — Firebase対局サービス（先後ランダム修正済み）
android/app/src/main/AndroidManifest.xml — Firebase ContentProvider無効化済み
pubspec.yaml                     — sentry_flutter削除済み
```

---

## 6. Firebase・AdMob について

現在はダミー設定のため以下の機能は動作しない（クラッシュはしない）：
- オンライン対局（Firebase未設定）
- 広告（テストIDのため実際の広告は非表示の場合あり）

本番リリース前に必要な作業：
1. Firebase プロジェクト作成 → `google-services.json` を `android/app/` に配置
2. `lib/firebase_options.dart` を実際の値に更新
3. AdMob 本番 App ID に変更（`AndroidManifest.xml`）

---

## 7. 再ビルドが必要な場合

```cmd
cd shogi_app
flutter clean
flutter pub get
flutter build apk --release
```

ビルド所要時間：約2〜3分（キャッシュあり）

JVMクラッシュが発生する場合は `android/gradle.properties` を確認：
```
org.gradle.jvmargs=-Xmx1536m -Xms256m -XX:MaxMetaspaceSize=384m -XX:ReservedCodeCacheSize=128m -XX:+UseSerialGC
```

---

## 8. 連絡先・補足

- ログファイルは `C:\将棋_crash_log.txt` に保存して共有
- Flutter バージョン確認: `flutter --version`
- ADB が認識されない場合: Google USB Driver をインストール  
  https://developer.android.com/studio/run/win-usb
