# Firebase Authentication セットアップガイド

## 概要
このドキュメントは Firebase Authentication の設定手順を説明します。

---

## 1. Firebase コンソールでの設定

### 1.1 メール/パスワード認証を有効化

1. [Firebase コンソール](https://console.firebase.google.com) を開く
2. プロジェクトを選択 → **Authentication** → **Sign-in method**
3. **Email/Password** を有効化
   - "Enable" をクリック
   - "Email/Password" と "Email link (passwordless sign-in)" を選択可能
   - 推奨：Email/Password のみ有効化

### 1.2 匿名認証を有効化

1. **Anonymous** の行をクリック
2. **Enable** をオン
3. **Save**

### 1.3 Google Sign-In を設定（オプション）

1. **Google** の行をクリック
2. **Enable** をオン
3. プロジェクトサポートメールアドレスを指定
4. **Save**

---

## 2. Dart コードでの実装

### 2.1 AuthService の使用

```dart
import 'package:shogi_app/services/auth_service.dart';

// メール/パスワードでサインアップ
try {
  await AuthService.signUpWithEmail(
    email: 'user@example.com',
    password: 'password123',
  );
} catch (e) {
  print('エラー: $e');
}

// ログイン
try {
  await AuthService.signInWithEmail(
    email: 'user@example.com',
    password: 'password123',
  );
} catch (e) {
  print('エラー: $e');
}

// 匿名ログイン
try {
  await AuthService.signInAnonymously();
} catch (e) {
  print('エラー: $e');
}

// ログアウト
await AuthService.signOut();
```

### 2.2 認証状態の監視

```dart
// 認証状態の変化を監視
AuthService.authStateChanges.listen((user) {
  if (user == null) {
    print('ユーザーがログアウトしました');
  } else {
    print('ユーザーがログインしました: ${user.email}');
  }
});
```

### 2.3 ユーザー情報へのアクセス

```dart
// 現在のユーザーを取得
final user = AuthService.currentUser;
print('UID: ${user?.uid}');
print('Email: ${user?.email}');
print('匿名: ${user?.isAnonymous}');

// ユーザー情報を更新
await AuthService.updateUserProfile(
  displayName: '将棋太郎',
  photoURL: 'https://example.com/photo.jpg',
);
```

---

## 3. セキュリティのベストプラクティス

### 3.1 パスワード管理

- ✅ 最低8文字以上
- ✅ 大文字、小文字、数字を含む
- ✅ パスワードはクライアント側では保存しない

### 3.2 匿名認証

- ✅ オフラインでも操作可能にするため有効化
- ✅ ユーザーがログインする際、匿名アカウントをマージできる
- ⚠️ 重要なデータ（棋譜、統計）は認証後に保存

### 3.3 Firestore セキュリティルール

Firestore に保存するデータは、以下のルールで保護します：

```
- 個人データ（game_logs, user_stats）：本人のみアクセス可能
- プロフィール：認証ユーザーは読取、本人は読み書き可能
- 公開データ（openings）：全ユーザーが読取可能
```

詳細は `firestore.rules` を参照。

---

## 4. エラーハンドリング

AuthService は以下のエラーを処理します：

| エラーコード | 説明 | 対応 |
|------------|------|------|
| `weak-password` | パスワードが弱い | ユーザーに強いパスワードを要求 |
| `email-already-in-use` | メアドが使用中 | ログインを提案 |
| `user-not-found` | ユーザーが見つからない | サインアップを提案 |
| `wrong-password` | パスワード誤り | 入力をリトライ |
| `too-many-requests` | 試行回数超過 | 後で試すように案内 |

---

## 5. デプロイメント

### 5.1 本番環境チェックリスト

- [ ] Firebase コンソールで Email/Password 認証が有効化されている
- [ ] 匿名認証が有効化されている
- [ ] Firestore セキュリティルールがデプロイされている
- [ ] Google Sign-In が必要な場合は設定済み
- [ ] password reset メール テンプレートをカスタマイズ（オプション）

### 5.2 デプロイ手順

```bash
# Firestore ルールをデプロイ
firebase deploy --only firestore:rules

# Realtime Database ルールがある場合
firebase deploy --only database:rules
```

---

## 6. トラブルシューティング

### 認証がうまくいかない場合

1. Firebase コンソールで認証方法が有効になっているか確認
2. `AuthService.debugPrintAuthState()` で認証状態をログ出力
3. Firebase のエラーメッセージを確認

### Firestore へのアクセスが拒否される場合

1. `firestore.rules` がデプロイされているか確認
2. ユーザーが認証済みか確認
3. Firestore セキュリティルールのパスが正しいか確認

---

## 参考リンク

- [Firebase Authentication ドキュメント](https://firebase.google.com/docs/auth)
- [Firestore セキュリティルール](https://firebase.google.com/docs/firestore/security/start)
- [Firebase Console](https://console.firebase.google.com)
