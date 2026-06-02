# プライバシーポリシー / Privacy Policy

**アプリ名 / App Name**: 将棋 - Shogi Board  
**開発者 / Developer**: Petit Studio  
**最終更新 / Last Updated**: 2026-05-23  
**パッケージ / Package ID**: com.petitStudio.shogiApp

---

## 日本語

### 1. 収集する情報

本アプリが収集・利用する情報は以下のとおりです。

#### 1.1 デバイス上にのみ保存される情報（クラウド送信なし）
- **棋譜データ** — 対局記録（SharedPreferences に暗号化して保存）
- **レーティング・勝敗履歴** — 端末内にのみ保存
- **設定情報** — テーマ、音声設定など（端末内のみ）
- **購入状態** — サブスクリプション有無（端末キャッシュ）

#### 1.2 外部サービスに送信される情報

| サービス | 目的 | 送信データ | プライバシーポリシー |
|---------|------|-----------|------------------|
| **Firebase Realtime Database** | ネットワーク対局のリアルタイム同期、グローバルランキング | 匿名ユーザーID・指し手・レーティング | [Firebase Privacy](https://firebase.google.com/support/privacy) |
| **Google AdMob** | 広告表示（サブスク未加入の場合） | 広告ID・デバイス情報 | [Google Privacy](https://policies.google.com/privacy) |
| **Google Play In-App Purchase** | サブスクリプション・テーマパック購入 | 購入情報（Google Play 経由） | [Google Play Privacy](https://play.google.com/intl/ja/about/play-terms/) |
| **Sentry** | クラッシュレポート・エラートラッキング | エラーログ・スタックトレース（個人情報なし） | [Sentry Privacy](https://sentry.io/privacy/) |

### 2. 収集しない情報

本アプリは以下の情報を**一切収集しません**：
- 氏名・メールアドレス・電話番号などの個人識別情報
- 位置情報（GPS）
- 連絡先・カメラ・マイクへのアクセス
- 他のアプリのデータ

### 3. ネットワーク対局について

ネットワーク対局機能をご利用の場合、対局中の指し手データが Firebase Realtime Database に一時的に保存されます。保存データは対局終了後も一定期間 Firebase サーバーに残りますが、個人を特定する情報は含まれません（匿名ユーザーIDのみ）。

### 4. 広告について

本アプリはサブスクリプション未加入の場合、Google AdMob による広告を表示します。AdMob はデバイスの広告IDを使用してパーソナライズ広告を提供することがあります。広告設定はデバイスの「設定 > Google > 広告」から変更できます。

### 5. 子どもについて

本アプリは13歳未満の子どもを対象としておらず、意図的に未成年者の個人情報を収集しません。

### 6. ポリシーの変更

本ポリシーは予告なく変更される場合があります。重要な変更がある場合はアプリ内でお知らせします。

### 7. お問い合わせ

プライバシーに関するご質問は以下にお寄せください：  
**Email**: zkaz83@gmail.com  
**開発者**: Petit Studio

---

## English

### 1. Information We Collect

#### 1.1 Stored Locally Only (Not Transmitted to Cloud)
- **Game Records (Kifu)** — Match history stored encrypted in SharedPreferences
- **Rating & Win/Loss History** — Stored on device only
- **Preferences** — Theme, sound settings, etc.
- **Purchase Status** — Subscription cache on device

#### 1.2 Information Sent to External Services

| Service | Purpose | Data Sent | Privacy Policy |
|---------|---------|-----------|----------------|
| **Firebase Realtime Database** | Network game sync, global ranking | Anonymous user ID, moves, rating | [Firebase Privacy](https://firebase.google.com/support/privacy) |
| **Google AdMob** | Advertising (for non-subscribers) | Advertising ID, device info | [Google Privacy](https://policies.google.com/privacy) |
| **Google Play IAP** | Subscription & theme pack purchase | Purchase info via Google Play | [Google Play Privacy](https://play.google.com/intl/en/about/play-terms/) |
| **Sentry** | Crash reports & error tracking | Error logs, stack traces (no PII) | [Sentry Privacy](https://sentry.io/privacy/) |

### 2. Information We Do NOT Collect
- Personal identifiers (name, email, phone number)
- Location data (GPS)
- Access to contacts, camera, or microphone
- Data from other applications

### 3. Children's Privacy
This app is not directed at children under 13 and does not knowingly collect personal information from minors.

### 4. Contact
For privacy inquiries: **zkaz83@gmail.com** — Petit Studio
