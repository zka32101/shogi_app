# 自動ビルド実装ガイド

## 概要
GitHub Actions を使用した自動ビルドシステムの実装方法。API 経由でワークフローをトリガーでき、アーティファクト（APK/AAB）を自動生成します。

---

## 1️⃣ ワークフローファイルの作成

### ファイル位置
`.github/workflows/deploy.yml`

### 基本構成
```yaml
name: Build Signed Android App Bundle

on:
  push:
    tags:
      - 'v*'              # タグプッシュで自動トリガー
  workflow_dispatch: {}   # 手動トリガー対応

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # ビルドジョブ定義
```

### 重要な設定
- **workflow_dispatch**: API からのトリガーに必須
- **on.push.tags**: セマンティックバージョニング（v1.0.0 形式）

---

## 2️⃣ アーティファクト出力

### ビルドステップ例（Flutter）
```yaml
- name: Build signed App Bundle (AAB)
  run: flutter build appbundle --release

- name: Build signed APK
  run: flutter build apk --release
```

### アーティファクトアップロード
```yaml
- name: Upload AAB as workflow artifact
  uses: actions/upload-artifact@v4
  with:
    name: app-release-aab
    path: build/app/outputs/bundle/release/app-release.aab
    retention-days: 30

- name: Upload APK as workflow artifact
  uses: actions/upload-artifact@v4
  with:
    name: app-release-apk
    path: build/app/outputs/apk/release/app-release.apk
    retention-days: 30
```

---

## 3️⃣ API トリガー実装

### 方法1: GitHub CLI
```bash
gh workflow run deploy.yml --ref master
```

### 方法2: GitHub MCP Tools（Claude Code）
```javascript
mcp__github__actions_run_trigger
  method: "run_workflow"
  owner: "your-org"
  repo: "your-repo"
  workflow_id: "deploy.yml"
  ref: "master"
```

### 方法3: GitHub API（curl）
```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"master"}'
```

---

## 4️⃣ 自動マージ設定（オプション）

### Branch Protection Ruleset
Settings → Branches → Add rule
- Branch name pattern: `master`
- ✓ Require a pull request before merging
- ✓ Allow auto-merge

### auto-merge ワークフロー
`.github/workflows/auto-merge.yml` で CI 成功時に自動マージ

---

## 5️⃣ バージョン管理

### pubspec.yaml（Flutter例）
```yaml
version: 1.1.3+14
```

- `1.1.3`: アプリバージョン
- `14`: ビルド番号（連番で増加）

---

## 6️⃣ 展開チェックリスト

- [ ] `.github/workflows/deploy.yml` 作成
- [ ] `workflow_dispatch` 有効化
- [ ] アーティファクトアップロード設定
- [ ] Branch Protection 設定
- [ ] ローカルビルドテスト
- [ ] API トリガーテスト
- [ ] ドキュメント更新
