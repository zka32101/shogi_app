# ストア提出 ユーザー実行手順（Web UI）

**概要**: GitHub Actions で自動ビルドされた AAB・IPA ファイルを、Google Play Console・App Store Connect に提出する手順

**対象**: ユーザー（zkaz83@gmail.com）  
**所要時間**: 1-2 時間（初回）  
**必要な環境**: Web ブラウザ

---

## 📋 事前準備

| 項目 | 確認 |
|---|---|
| Google Play Console アカウント | ✅ 既存・新規アカウント作成 |
| App Store Connect アカウント | ✅ Apple ID でログイン可能 |
| メタデータファイル | ✅ `GOOGLE_PLAY_METADATA.md`・`APP_STORE_METADATA.md` を用意 |
| AAB ファイル | ⏳ GitHub Actions からダウンロード（タグ push 後） |
| iOS IPA ファイル | ⏳ TestFlight にアップロード済み |
| スクリーンショット | ⏳ 別途撮影・編集（Google Play: 1440×900, App Store: 1125×2436） |
| アプリアイコン | ⏳ 512×512 px PNG 用意 |

---

## 🟢 Google Play Console 提出（1-2 時間 + 1-3h 審査）

### Phase 1: Google Play Console アカウント準備

#### Step 1.1: アカウント作成またはログイン

1. **[Google Play Console](https://play.google.com/console)** にアクセス
2. Google アカウントでログイン（既存アカウントがあればそれを使用）
3. 初回の場合：**開発者アカウント登録**
   - 開発者名: Your Wish Dev
   - メールアドレス: yourwishdev@gmail.com
   - 国: Japan
   - サイト: [任意]
   - 登録料: ¥4,600（1 回限り）

#### Step 1.2: 初回アプリ登録

1. **Create app** ボタン
2. **App name**: 「将棋 - 詰将棋・対局」
3. **Default language**: 日本語
4. **App or game**: ゲーム を選択
5. **Free or paid**: Free
6. **Create** ボタン

**結果**: アプリページが生成される

---

### Phase 2: 基本情報（メタデータ）入力

#### Step 2.1: アプリ概要タブ

1. 左メニュー → **App content**
2. **App details** セクション
   - **Short description**: 
     ```
     詰将棋・オンライン対局・AI対戦を楽しめる本格将棋アプリ
     ```
   - **Full description**: 
     ```
     GOOGLE_PLAY_METADATA.md の「詳細説明」セクションから全文コピー
     ```
   - **App category**: ゲーム
   - **App type**: ゲーム
   - **Save**

#### Step 2.2: アプリのカテゴリ設定

1. 左メニュー → **Store listing**
2. **Category**: Games > Board games
3. **Content rating**: 
   - **Set content rating** をクリック
   - 調査票に回答（詳細は下記参照）
   - **Save & continue**
4. **Target audience**: 
   - **Yes** (Everyone)
   - **Save**

#### Step 2.3: コンテンツレーティング（詳細）

1. **Set content rating** フォーム入力:

| 質問 | 回答 |
|---|---|
| 暴力的なコンテンツを含みますか？ | いいえ |
| 性的なコンテンツを含みますか？ | いいえ |
| 下品な言葉を含みますか？ | いいえ |
| アルコール・タバコ・ドラッグを含みますか？ | いいえ |
| 危険な行為をシミュレートしますか？ | いいえ |
| 差別的なコンテンツを含みますか？ | いいえ |

2. **Save**

**結果**: 「一般向け」レーティング

---

### Phase 3: スクリーンショット・アイコン・プロモ画像

#### Step 3.1: スクリーンショット追加

1. 左メニュー → **Store listing**
2. **Screenshots** セクション
3. **Add screenshots** ボタン
4. 5 枚以上のスクリーンショットアップロード（1440×900 px PNG/JPG）:
   ```
   screenshot_1_puzzle.png    - 詰将棋モード
   screenshot_2_ai.png        - AI対戦
   screenshot_3_match.png     - ネットワーク対局
   screenshot_4_chat.png      - 対局チャット
   screenshot_5_profile.png   - ユーザープロフィール
   ```

#### Step 3.2: アイコン・プロモ画像追加

1. **App icon**: 512×512 px PNG アップロード
2. **Feature graphic**: 1024×500 px PNG アップロード

---

### Phase 4: プライバシーポリシー・連絡先

#### Step 4.1: プライバシーポリシー URL 設定

1. 左メニュー → **App content**
2. **Target audience & content** セクション
3. **Privacy policy**:
   ```
   https://[yourwishdev.com]/privacy-policy.html
   ```
   （公開 URL である必要があります）

#### Step 4.2: 連絡先メール設定

1. 左メニュー → **App content**
2. **Contact details**:
   - **Email address**: yourwishdev@gmail.com

---

### Phase 5: ビルドファイル（AAB）アップロード

#### Step 5.1: リリース設定

1. 左メニュー → **Testing** → **Internal testing** 
   （テスト用リリース先）
   **または**
   左メニュー → **Releases** → **Production**
   （本番リリース）

2. **Create new release** ボタン

#### Step 5.2: AAB ファイルアップロード

1. **Add files** セクション
2. AAB ファイルをドラッグ&ドロップ
   ```
   build/app/outputs/bundle/release/app-release.aab
   ```
   （GitHub Actions からダウンロードしたファイル）

#### Step 5.3: リリース名・説明

1. **Release name**: 「1.0.0」
2. **Release notes**:
   ```
   🎮 本格将棋アプリ v1.0.0 リリース
   
   ✨ 新機能:
   - 詰将棋モード
   - AI対戦（7段階難易度）
   - ネットワーク対局
   - リアルタイムチャット
   
   🔒 セキュリティ改善:
   - チート検出システム
   - ユーザー保護機能
   ```

#### Step 5.4: リリース タイプ選択

1. **Release type**: 
   - **Internal testing** (初回テスト用)
   - **Staged rollout** (段階的リリース)
   - **Full release** (全員に公開)

2. 初回は **Internal testing** 推奨

---

### Phase 6: レビュー申請（本番リリース時）

#### Step 6.1: 本番リリースレーン作成

1. 左メニュー → **Releases** → **Production**
2. **Create new release**
3. 上記 Phase 5 と同じ手順で AAB アップロード

#### Step 6.2: 最終チェック

以下が完備されていることを確認:
- [ ] アプリ名
- [ ] 短説明
- [ ] 詳細説明
- [ ] スクリーンショット 5 枚以上
- [ ] アプリアイコン
- [ ] コンテンツレーティング
- [ ] プライバシーポリシー URL
- [ ] 連絡先メール
- [ ] AAB ファイル

#### Step 6.3: サブミット

1. **Review release** ボタン
2. 内容確認
3. **Release** ボタン

**結果**: Google へ送信・審査待機

---

## 🍎 App Store Connect 提出（1-2 時間 + 1-3 日審査）

### Phase 1: App Store Connect アカウント準備

#### Step 1.1: ログイン

1. **[App Store Connect](https://appstoreconnect.apple.com)** にアクセス
2. Apple ID でログイン

#### Step 1.2: 初回アプリ登録

1. **My Apps** → **+** ボタン
2. **New App**
3. **App information**:
   - **Platforms**: iOS
   - **App Name**: 「将棋 - 詰将棋・対局」
   - **Primary Language**: 日本語
   - **Bundle ID**: com.petitworksapps.kouki
   - **SKU**: shogi-app-001

4. **Create** ボタン

**結果**: アプリページ生成

---

### Phase 2: 基本情報（メタデータ）入力

#### Step 2.1: アプリ情報タブ

1. **App Information** タブ
2. **App Description**:
   ```
   APP_STORE_METADATA.md の「説明」セクションから全文コピー
   ```
3. **Subtitle** (30文字以内):
   ```
   オンライン対局・AI・詰将棋
   ```
4. **Keywords**:
   ```
   将棋,詰将棋,オンライン対局,AI対戦,ボードゲーム
   ```
5. **Support URL**:
   ```
   https://[yourwishdev.com]/support
   ```
6. **Privacy Policy URL**:
   ```
   https://[yourwishdev.com]/privacy-policy.html
   ```
7. **Save**

#### Step 2.2: カテゴリ・年齢制限

1. **App Information** タブ
2. **Category**: ゲーム > ボードゲーム
3. **Age Rating**:
   - 4+
4. **Save**

#### Step 2.3: プロモテキスト

1. **App Information** タブ
2. **Promotional Text** (170文字以内):
   ```
   本格将棋アプリ登場！詰将棋・AI対戦・オンライン対局を楽しめます。
   世界中のプレイヤーとリアルタイム対局。レーティングで成績を記録。
   ```
3. **Save**

---

### Phase 3: スクリーンショット・プレビュー

#### Step 3.1: スクリーンショット追加

1. **App Store** タブ → **Screenshots** セクション
2. 対応デバイス選択: **iPhone 14 Pro Max** (1125×2436 px)
3. **Add Screenshots** ボタン
4. 5 枚のスクリーンショットアップロード:
   ```
   ios_screenshot_1_puzzle.png       (1125×2436)
   ios_screenshot_2_ai.png           (1125×2436)
   ios_screenshot_3_match.png        (1125×2436)
   ios_screenshot_4_gameplay.png     (1125×2436)
   ios_screenshot_5_profile.png      (1125×2436)
   ```

#### Step 3.2: プレビュー画像（オプション）

1. **Preview** セクション（オプション）
2. プレビュー動画：最大 30 秒の MP4
3. **Save**

---

### Phase 4: 価格・配信設定

#### Step 4.1: 価格

1. **Pricing and Availability** タブ
2. **Price**: FREE （無料）
3. **Save**

#### Step 4.2: 配信地域

1. **Availability**:
   - 全地域で配信（デフォルト）
   - または特定地域のみ指定
2. **Save**

---

### Phase 5: iOS ビルド配置

#### Step 5.1: ビルド設定

1. **Build** タブ
2. **Add Build** ボタン
3. TestFlight でのビルド選択
   ```
   最新のビルド（GitHub Actions で自動アップロード済み）
   ```

#### Step 5.2: ビルド選択

1. iOS ビルド一覧から最新版を選択
2. **Save**

---

### Phase 6: ユーザーフライバリティ・プライバシー

#### Step 6.1: アプリのプライバシー情報

1. **App Privacy** タブ
2. **Data Collection & Sharing** セクション:

| データ種別 | 収集 | 共有 | 理由 |
|---|---|---|---|
| User ID | ✓ | ✓ | アカウント管理 |
| Game Play Data | ✓ | ✓ | ELO 計算 |
| Communications | ✓ | × | チャット |
| Device ID | ✓ | × | アプリ内機能 |

3. **Save**

#### Step 6.2: IDFA・追跡

1. **App Tracking Transparency**:
   - **Does your app use the Advertising Identifier (IDFA)?**
   - No （広告 ID なし）

---

### Phase 7: TestFlight ベータテスト（オプション）

#### Step 7.1: テスター招待

1. **TestFlight** タブ
2. **Internal Testers** セクション
3. テスター追加:
   - Email: テスターのメールアドレス
   - **Add**

#### Step 7.2: ビルド配置

1. 最新ビルドを確認
2. テスターは TestFlight アプリでインストール可能

**注**: 初回アップロード後、Apple による処理待機（数分～1時間）

---

### Phase 8: レビュー申請（本番リリース）

#### Step 8.1: 最終チェック

以下が完備されていることを確認:
- [ ] アプリ説明
- [ ] サブタイトル
- [ ] キーワード
- [ ] スクリーンショット 5 枚以上
- [ ] カテゴリ（ゲーム > ボードゲーム）
- [ ] 年齢制限（4+）
- [ ] プライバシーポリシー URL
- [ ] iOS ビルド配置

#### Step 8.2: サブミット

1. **App Store** タブ
2. **Version Release** セクション
3. **Add for Review** ボタン
4. **App Review Information**:
   - **Notes for App Review**:
     ```
     本格将棋アプリです。詰将棋、AI対戦、ネットワーク対局機能を含みます。
     すべての暴力・差別表現はありません。
     プライバシーポリシー: [URL]
     ```
   - **Save**

5. **Add for Review** ボタン

**結果**: Apple へ送信・審査待機（1-3 日）

---

## ⏱️ タイムライン

| フェーズ | 所要時間 | 対応 |
|---|---|---|
| 1. Secrets 登録（初回） | 15 分 | GitHub → Settings |
| 2. タグ push | 1 分 | git push |
| 3. GitHub Actions ビルド | 15-20 分 | 待機 |
| 4. Google Play 提出 | 30-45 分 | Web UI 入力 |
| 5. Google Play 審査 | 1-3 時間 | 待機 |
| 6. App Store 提出 | 30-45 分 | Web UI 入力 |
| 7. App Store 審査 | 1-3 日 | 待機 |

---

## 🔄 リリース後の作業

### リリース成功後

1. ✅ Google Play Console で本番リリース状態を確認
2. ✅ App Store Connect で配信状態を確認
3. ✅ Firebase Analytics でユーザー数・セッション数 監視
4. ✅ Firebase Crashlytics でエラー監視
5. ✅ ユーザーレビュー・評価 監視

### 次のバージョン

```bash
# 修正・更新後、タグをインクリメント
git tag v1.0.1
git push origin v1.0.1

# 同じ手順でビルド・提出
```

---

## ⚠️ よくある質問

### Q: スクリーンショットはどうやって撮影する？

**A**: 
1. 実機またはエミュレータでアプリを起動
2. 各画面でスクリーンショット撮影
3. Adobe XD・Figma・Canva で編集（テキスト追加等）
4. 所定サイズ（1440×900 px など）にエクスポート

### Q: 審査に落とされたら？

**A**: 
1. Apple・Google から指摘メール受信
2. 指摘内容に対応（例: プライバシーポリシー URL 修正）
3. ビルドを再度ビルド・アップロード
4. 再申請

### Q: 広告・課金の設定は？

**A**: 本バージョン 1.0.0 では広告なし（AdMob 実装済みだが、本番 ID 未設定）。課金なし。今後のアップデートで実装予定。

### Q: TestFlight を使わず直接 App Store へ提出できる？

**A**: 可能です。TestFlight スキップして直接 App Store へ提出できますが、初回はテストビルドから始めることをお勧めします。

---

## 📞 トラブルシューティング

### Google Play 提出エラー: 「コンテンツレーティングが不足」

**原因**: 調査票未入力

**対策**: 
1. App content → Target audience & content
2. 「Set content rating」をクリック
3. すべての質問に回答

### App Store 提出エラー: 「Missing App Privacy Information」

**原因**: プライバシー情報未設定

**対策**:
1. App Privacy タブ
2. すべてのデータ種別について回答

---

## 📋 最終チェックリスト

| 項目 | Google Play | App Store |
|---|---|---|
| メタデータ入力 | ✓ | ✓ |
| スクリーンショット | ✓ | ✓ |
| ビルドファイル | ✓ | ✓ |
| プライバシーポリシー | ✓ | ✓ |
| コンテンツレーティング | ✓ | ✓ |
| カテゴリ設定 | ✓ | ✓ |

---

**すべて完了したら、本番リリース状態になります！** 🎉
