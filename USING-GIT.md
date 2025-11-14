# Git マルチアカウント対応ガイド

## 概要

このプロジェクトは Git マルチアカウント対応を実装しており、ディレクトリベースでアカウントを自動的に切り替えます：

- **`~/Projects/` 以下**: 会社用アカウント（`juny-s` / `juny-s@iij.ad.jp`）を自動使用
- **`~/Dev/` 以下**: 個人用アカウント（`switchdriven` / `junya.satoh@gmail.com`）を自動使用

## 使い方ガイド

### 基本的な使用方法

#### 1. 会社用リポジトリで作業する場合
```bash
cd ~/Projects/my-repo
git add .
git commit -m "feat: add feature"
# → 自動的に juny-s <juny-s@iij.ad.jp> でコミット
# → プロキシも自動設定される
```

#### 2. 個人用リポジトリで作業する場合
```bash
cd ~/Dev/util-scripts
git add .
git commit -m "docs: update README"
# → 自動的に switchdriven <junya.satoh@gmail.com> でコミット
```

### トラブルシューティング

#### 設定が反映されない場合

**確認コマンド**:
```bash
# 現在のディレクトリで適用される設定を確認
git config --show-origin user.name
git config --show-origin user.email

# すべての設定を確認（デバッグ用）
git config --list --local --show-origin
```

**よくある原因**:

1. **リポジトリ内のローカル設定が優先される**
   ```bash
   # リポジトリ内に .git/config があると、グローバル設定より優先される
   # リポジトリのローカル設定を確認・削除
   git config --local --unset user.name
   git config --local --unset user.email
   ```

2. **ディレクトリ構造が異なる**
   - `includeIf` で指定しているパスは絶対パス：`/Users/junya/Projects/`
   - リポジトリがこのディレクトリ以下にあることを確認

3. **git バージョンが古い**
   ```bash
   git --version
   # Git 2.13+ が必要（macOS なら最新の Homebrew で OK）
   ```

### コミット後の確認

実際のコミットが正しいアカウントで作成されたか確認：

```bash
# 直近のコミット情報を確認
git log --format='%an <%ae>' -1

# より詳細な情報
git log -1 --format='Author: %an <%ae>%nDate: %aD%n%B'
```

### 新規リポジトリを作成する場合

```bash
# 会社用リポジトリを作成
mkdir -p ~/Projects/new-project
cd ~/Projects/new-project
git init
# → 自動的に juny-s アカウントが適用される

# 個人用リポジトリを作成
mkdir -p ~/Dev/new-project
cd ~/Dev/new-project
git init
# → 自動的に switchdriven アカウントが適用される
```

---

## 技術詳細

### 最終方針

- **GitHub MCP**: `~/Dev/github-mcp-server`（公式、Go実装）を両方で使用
  - プライベート (GitHub.com)：`github-personal` として登録
  - 会社用 (GitHub Enterprise)：`github-work` として登録
  - Keychain経由でトークン管理（1Password → Keychain）

- **Git コマンド**: マルチアカウント対応
  - ディレクトリベースでアカウントを自動切り替え
  - `~/Projects/` → 会社用アカウント（`juny-s`）
  - `~/Dev/` → 個人用アカウント（`switchdriven`）

### 実装済みタスク

#### ✅ 1. MCP設定（実装完了）
- [x] MCP_SETUP.md を新規作成・修正
- [x] CLAUDE.md の MCP設定セクションを更新
- [x] mcp-github.sh（ラッパースクリプト）を使用
- [x] mcp-github-setting.sh（トークン同期スクリプト）で Keychain 管理
- [x] setup-python-env.sh で `--mcp work` と `--mcp personal` に対応

#### ✅ 2. ドキュメント更新（実装完了）
- [x] MCP_SETUP.md：新規作成、詳細な設定ガイド
- [x] CLAUDE.md：MCP設定情報を最新化
- [x] README.md：`.venv_uv/` → `.venv/` に修正

#### ✅ 3. Git マルチアカウント設定（実装完了）

##### 3-1. ~/.gitconfig-work を作成 ✅
```ini
[user]
    name = juny-s
    email = juny-s@iij.ad.jp
[http]
    proxy = http://proxy.iiji.jp:8080
[https]
    proxy = http://proxy.iiji.jp:8080
```

##### 3-2. ~/.gitconfig-personal を作成 ✅
```ini
[user]
    name = switchdriven
    email = junya.satoh@gmail.com
```

##### 3-3. ~/.gitconfig を更新 ✅
`includeIf` ディレクティブを追加し、ディレクトリベースでアカウントを自動切り替え：

```ini
[filter "lfs"]
    clean = git-lfs clean -- %f
    smudge = git-lfs smudge -- %f
    process = git-lfs filter-process
    required = true
[include]
    path = ~/.gitconfig-personal
[includeIf "gitdir:/Users/junya/Projects/"]
    path = ~/.gitconfig-work
```

**設定ポイント**:
- `includeIf` は `include` より後に配置（後の設定が優先される）
- 絶対パスを使用（`~` は Git 2.13+ で展開可能だが確実性のため）

#### ✅ 4. Git マルチアカウント設定のテスト（実装完了）

##### テスト結果 ✅

**会社用ディレクトリ** (`~/Projects/` 以下):
```bash
$ cd ~/Projects/my-repo && git config user.name
juny-s
$ git config user.email
juny-s@iij.ad.jp
$ git config --get http.proxy
http://proxy.iiji.jp:8080
```

**個人用ディレクトリ** (`~/Dev/` 以下):
```bash
$ cd ~/Dev/util-scripts && git config user.name
switchdriven
$ git config user.email
junya.satoh@gmail.com
$ git config --get http.proxy
# (設定なし)
```

### 補足

#### 現在の状態 ✅
- setup-python-env.sh: 既に `--mcp work` と `--mcp personal` に対応
- mcp-github.sh: 会社用・個人用の両方に対応
- ~/.gitconfig: ディレクトリベースの自動切り替えに対応
- プロキシ設定: 会社用アカウントで自動設定

#### 保持すべき設定
- プロキシ設定（会社側インフラ対応）
- SSH/HTTPS 認証設定（git-lfs 関連）
- git-lfs フィルター設定

### 参考資料

- GitHub 公式 MCP サーバー: https://github.com/github/github-mcp-server
- git 設定: `man gitconfig` の `includeIf` セクション
