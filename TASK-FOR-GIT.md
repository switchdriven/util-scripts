# GitHub MCP サーバー & Git マルチアカウント対応

## 背景

- GitHub MCP サーバが "Package no longer supported" になった
- 公式の Go 実装（`~/Dev/github-mcp-server`）を使用することに決定
- Keychain ベースのトークン管理を採用
- Git コマンド運用も充実させたい

## 最終方針

- **GitHub MCP**: `~/Dev/github-mcp-server`（公式、Go実装）を両方で使用
  - プライベート (GitHub.com)：`github-personal` として登録
  - 会社用 (GitHub Enterprise)：`github-work` として登録
  - Keychain経由でトークン管理（1Password → Keychain）

- **Git コマンド**: マルチアカウント対応
  - ディレクトリベースでアカウントを自動切り替え
  - `~/Dev/iij-cf/` → 会社用アカウント（`juny-s`）
  - `~/Dev/` その他 → 個人用アカウント（`switchdriven`）

## 実装済みタスク

### ✅ 1. MCP設定（実装完了）
- [x] MCP_SETUP.md を新規作成・修正
- [x] CLAUDE.md の MCP設定セクションを更新
- [x] mcp-github.sh（ラッパースクリプト）を使用
- [x] mcp-github-setting.sh（トークン同期スクリプト）で Keychain 管理
- [x] setup-python-env.sh で `--mcp work` と `--mcp personal` に対応

### ✅ 2. ドキュメント更新（実装完了）
- [x] MCP_SETUP.md：新規作成、詳細な設定ガイド
- [x] CLAUDE.md：MCP設定情報を最新化
- [x] README.md：`.venv_uv/` → `.venv/` に修正

## 実装予定タスク

### 3. Git マルチアカウント設定

#### 3-1. ~/.gitconfig-work を作成（予定）
```bash
[user]
    name = juny-s
    email = <会社用メールアドレス>
[http]
    proxy = http://proxy.iiji.jp:8080
[https]
    proxy = http://proxy.iiji.jp:8080
```

#### 3-2. ~/.gitconfig-personal を作成（予定）
```bash
[user]
    name = switchdriven
    email = junya.satoh@gmail.com
```

#### 3-3. ~/.gitconfig を更新（予定）
- `includeIf` ディレクティブを追加
- ディレクトリベースでアカウントを自動切り替え：
  - `~/Dev/iij-cf/` → work アカウント（`~/.gitconfig-work`）
  - その他 → personal アカウント（`~/.gitconfig-personal`）

**実装例**:
```bash
[includeIf "gitdir:~/Dev/iij-cf/"]
    path = ~/.gitconfig-work
[include]
    path = ~/.gitconfig-personal
```

### 4. Git マルチアカウント設定のテスト（予定）

#### 4-1. 会社用リポジトリでのテスト
```bash
cd ~/Dev/iij-cf/some-repo
git config user.name
# → "juny-s" であることを確認
git config --get http.proxy
# → "http://proxy.iiji.jp:8080" であることを確認
```

#### 4-2. 個人用リポジトリでのテスト
```bash
cd ~/Dev/util-scripts
git config user.name
# → "switchdriven" であることを確認
```

#### 4-3. 実際のコミットでの検証
```bash
cd ~/Dev/util-scripts
git log --format='%an <%ae>' -1
# → "switchdriven <junya.satoh@gmail.com>" であることを確認

cd ~/Dev/iij-cf/some-repo
git log --format='%an <%ae>' -1
# → "juny-s <会社用メール>" であることを確認
```

## 補足

### 現在の状態
- setup-python-env.sh: 既に `--mcp work` と `--mcp personal` に対応
- mcp-github.sh: 会社用・個人用の両方に対応
- ~/.gitconfig: switchdriven（個人）で固定（変更予定）
- プロキシ設定: 既に設定されている（会社側）

### 保持すべき設定
- プロキシ設定（会社側インフラ対応）
- SSH/HTTPS 認証設定（git-lfs 関連）

## 参考資料

- GitHub 公式 MCP サーバー: https://github.com/github/github-mcp-server
- git 設定: `man gitconfig` の `includeIf` セクション
