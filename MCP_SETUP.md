# Claude Code MCP設定ガイド

## 概要

このドキュメントでは、GitHub MCPサーバー（公式）を使用して、Claude CodeからGitHub（会社用・個人用）を操作する方法を説明します。

MCPサーバーとしては、`~/Dev/github-mcp-server`にある公式のGitHub MCPサーバー（Go実装）を使用し、APIトークンはmacOSのKeychain経由で管理します。

## 前提条件

- **Claude Code**: インストール済みであること
- **1Password CLI (`op`)**: インストール済みで、認証が完了していること（トークン管理用）
- **macOS Keychain**: APIトークンの安全な保管（自動）
- **~/Dev/github-mcp-server**: GitHub公式MCPサーバーがクローン済み
- **uv**: Python仮想環境管理ツール
- **direnv**: 環境変数の自動読み込みツール

## MCPサーバーの種類と管理方法

### GitHub MCPサーバーの実装

**使用するMCPサーバー**: `~/Dev/github-mcp-server/github-mcp-server`（Go実装、GitHub公式）

このサーバーは、環境変数でGitHubのホストを切り替えることで、会社用と個人用の両方に対応します。

### 1. 会社用GitHub（`github-work`）

- **対象**: GitHub Enterprise (`https://gh.iiji.jp`)
- **ユーザー名**: `juny-s`
- **1Password**: `op://Personal/GitHubEnt For MCP/token`
- **Keychain**: `github-work-token`（`mcp-github-setting.sh`で同期）
- **ラッパースクリプト**: `~/Scripts/Shell/mcp-github-work.sh`
- **環境変数**: `GITHUB_USERNAME=juny-s`（`.envrc`で自動設定）
- **利用可能な機能**: repos, issues, pull_requests, actions

### 2. 個人用GitHub（`github-personal`）

- **対象**: GitHub.com (`https://github.com`)
- **ユーザー名**: `switchdriven`
- **1Password**: `op://Personal/GitHub For MCP/token`
- **Keychain**: `github-personal-token`（`mcp-github-setting.sh`で同期）
- **ラッパースクリプト**: `~/Scripts/Shell/mcp-github-personal.sh`
- **環境変数**: `GITHUB_USERNAME=switchdriven`（`.envrc`で自動設定）
- **利用可能な機能**: repos, issues, pull_requests, actions

## アーキテクチャ

### トークン管理フロー

```
┌──────────────────────────────────────────────────────────────┐
│ 初期セットアップ: mcp-github-setting.sh を実行                  │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  1. 1Password から API トークン取得                            │
│     - op://Personal/GitHub For MCP/token                     │
│     - op://Personal/GitHubEnt For MCP/token                  │
│                                                               │
│  2. macOS Keychain に保存                                    │
│     - github-personal-token                                  │
│     - github-work-token                                      │
│                                                               │
│  3. トークン更新時は再実行                                      │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ claude mcp add コマンド: MCPサーバーを登録                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  $ claude mcp add --transport stdio github-personal --      │
│    ~/Scripts/Shell/mcp-github-personal.sh                   │
│                                                               │
│  $ claude mcp add --transport stdio github-work --          │
│    ~/Scripts/Shell/mcp-github-work.sh                       │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ ~/.claude.json に自動保存                                     │
│ (Claude Code がプロジェクトごとに参照)                        │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│ Claude Code 起動時: MCPサーバー起動フロー                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  1. mcp-github-personal.sh または mcp-github-work.sh を実行   │
│  2. Keychain からトークン取得                                │
│  3. ~/Dev/github-mcp-server/github-mcp-server を起動          │
│  4. Claude Code と通信開始                                   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### ラッパースクリプト（mcp-github-personal.sh / mcp-github-work.sh）の役割

Keychain からトークンを取得して、GitHub MCPサーバーに渡すための中間層です：

```bash
# mcp-github-personal.sh (個人用)
#!/bin/sh
GITHUB_MCP_SERVER_PATH="/Users/junya/Dev/github-mcp-server/github-mcp-server"
TOKEN=$(security find-generic-password -w -s "github-personal-token")
export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
exec $GITHUB_MCP_SERVER_PATH stdio

# mcp-github-work.sh (会社用)
#!/bin/sh
GITHUB_MCP_SERVER_PATH="/Users/junya/Dev/github-mcp-server/github-mcp-server"
TOKEN=$(security find-generic-password -w -s "github-work-token")
export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
export GITHUB_HOST="https://gh.iiji.jp"
exec $GITHUB_MCP_SERVER_PATH stdio
```

## セットアップ手順

### ステップ 1: 1Password からトークンを Keychain に同期

```bash
# 実行
~/Scripts/Shell/mcp-github-setting.sh

# 出力例
[INFO] Syncing GitHub tokens from 1Password to Keychain...
[INFO] Personal token synced to Keychain ✓
[INFO] Work token synced to Keychain ✓
```

### ステップ 2: Keychain にトークンが保存されているか確認

```bash
# 個人用トークンの確認
security find-generic-password -s "github-personal-token"

# 会社用トークンの確認
security find-generic-password -s "github-work-token"
```

### ステップ 3: ラッパースクリプトが実行可能か確認

```bash
ls -la ~/Scripts/Shell/mcp-github-*.sh
# -rwxr-xr-x であることを確認
```

### ステップ 4: setup-env.rb で自動設定（推奨）

`setup-env.rb` は MCP 設定をプロジェクトディレクトリに基づいて自動検出します：

```bash
# ~/Projects/ 配下 → 自動的に --mcp work が適用（Python）
./setup-env.rb -l python ~/Projects/work-project

# ~/Dev/ 配下 → 自動的に --mcp personal が適用（Ruby）
./setup-env.rb -l ruby ~/Dev/personal-project

# 言語なし（direnv/MCP のみ）の場合も対応
./setup-env.rb -l none ~/Projects/jxa-project       # 自動的に --mcp work が適用

# 明示的に MCP を指定することも可能
./setup-env.rb -l python --mcp work ~/Projects/work-project
./setup-env.rb -l ruby --mcp personal ~/Dev/personal-project
./setup-env.rb -l none --mcp work ~/Projects/jxa-project
```

**None 言語での使用例** (`--lang none`):
- JXA（JavaScript for Automation）プロジェクト
- シェルスクリプト専用プロジェクト
- 言語環境が不要で direnv と MCP のセットアップだけが必要な場合
- このような場合でも MCP の自動検出が機能します

MCP 設定が自動検出され、MCPサーバーが自動登録されます。詳細は [CLAUDE.md](CLAUDE.md#setup-envrb) または `./setup-env.rb --help` を参照してください。

### ステップ 6: MCPサーバーを手動登録（必要な場合）

`setup-env.rb`、`setup-python-env.rb`、または `setup-ruby-env.rb` で `--mcp personal` または `--mcp work` オプションを使用すると自動登録されます。

手動で登録する場合：

```bash
# 個人用MCPサーバーの登録
claude mcp add --transport stdio github-personal -- ~/Scripts/Shell/mcp-github-personal.sh

# 会社用MCPサーバーの登録
claude mcp add --transport stdio github-work -- ~/Scripts/Shell/mcp-github-work.sh
```

### ステップ 7: MCPサーバーが登録されているか確認

```bash
claude mcp list

# 出力例
github-personal: ~/Scripts/Shell/mcp-github-personal.sh  - ✓ Connected
github-work: ~/Scripts/Shell/mcp-github-work.sh  - ✓ Connected
```

## Claude Desktop 設定

Claude Desktop でもMCPサーバーを使用する場合は、`~/Library/Application Support/Claude/claude.json` に設定を追加します。

設定ファイルのサンプルは [claude-desktop-config.json](claude-desktop-config.json) を参照してください。

基本的な手順：

1. `claude-desktop-config.json` の内容を確認
2. `~/Library/Application Support/Claude/claude.json` にコピー（既存ファイルがあれば `mcpServers` セクションをマージ）
3. Claude Desktop を再起動

**注意**: `~/Library/Application Support/Claude/` ディレクトリがない場合は、まず Claude Desktop を一度起動して作成してください。

## 動作確認

### Claude Code での使用

```
@github-personal を有効にして、過去1週間のPRを一覧表示して

or

@github-work を有効にして、会社用リポジトリのissueを一覧表示して
```

### Claude Desktop での使用

同様に `@github-personal` または `@github-work` を使用します。

### トークン更新

1Passwordでトークンが更新されたときは、以下を実行してKeychainを更新します：

```bash
~/Scripts/Shell/mcp-github-setting.sh
```

## トラブルシューティング

### MCP接続エラー

**症状**: "Connection failed" などのエラーが表示される

**原因と対策**:

1. **Keychain にトークンが保存されていない**
   ```bash
   security find-generic-password -s "github-personal-token"
   # エラーが出た場合は、mcp-github-setting.sh を実行
   ```

2. **ラッパースクリプトが実行できない**
   ```bash
   ls -la ~/Scripts/Shell/mcp-github-*.sh
   # 実行権限がない場合：chmod +x ~/Scripts/Shell/mcp-github-*.sh
   ```

3. **1Password CLI が認証されていない**
   ```bash
   op account list
   eval $(op signin)  # 必要に応じて
   ```

4. **GitHub MCP サーバーが見つからない**
   ```bash
   ls ~/Dev/github-mcp-server/github-mcp-server
   # ファイルがない場合は、リポジトリをクローンしてビルド
   ```

5. **Claude Code を再起動**
   - MCPサーバーの登録直後は、必ずClaude Codeを再起動してください

### トークン取得失敗

**症状**: "Could not retrieve github-personal-token from keychain" などのエラー

**対策**:

```bash
# Keychainの内容を確認
security dump-keychain ~/Library/Keychains/login.keychain-db | grep github

# トークンを再同期
~/Scripts/Shell/mcp-github-setting.sh

# Keychainの詳細確認
security find-generic-password -s "github-personal-token" -v
```

### 複数アカウントの設定

統合セットアップスクリプト `setup-env.rb`（推奨）またはプロジェクト言語に応じた専用スクリプトで、プロジェクトごとにMCP設定を指定できます：

```bash
# 統合スクリプト（言語を自動検出または明示的に指定）
./setup-env.rb --lang python --mcp personal my-personal-project
./setup-env.rb --lang ruby --mcp work my-work-project
./setup-env.rb --lang none --mcp work my-jxa-work-project

# Python専用
./setup-python-env.rb --mcp personal my-personal-project
./setup-python-env.rb --mcp work my-work-project

# Ruby専用
./setup-ruby-env.rb --mcp personal my-personal-project
./setup-ruby-env.rb --mcp work my-work-project

# None言語（direnv/MCP のみ）
./setup-env.rb --lang none --mcp personal my-jxa-personal-project
./setup-env.rb --lang none --mcp work my-jxa-work-project
```

各プロジェクトの `.envrc` に `GITHUB_USERNAME` が自動設定されます。

## ファイル構成

```
util-scripts/
├── setup-env.rb                  # 統合開発環境セットアップ（推奨、MCP対応）
├── setup-python-env.rb           # Python環境セットアップ（MCP対応）
├── setup-ruby-env.rb             # Ruby環境セットアップ（MCP対応）
├── mcp-github-personal.sh        # GitHub MCP ラッパー（個人用）
├── mcp-github-work.sh            # GitHub MCP ラッパー（会社用）
├── mcp-github-setting.sh         # トークン同期スクリプト（1Password → Keychain）
├── MCP_SETUP.md                  # このファイル
└── CLAUDE.md                     # プロジェクトガイド

~/Scripts/Shell/
├── mcp-github-personal.sh        # GitHub MCP ラッパー（個人用、util-scriptsへのコピー）
├── mcp-github-work.sh            # GitHub MCP ラッパー（会社用、util-scriptsへのコピー）
└── mcp-github-setting.sh         # トークン同期スクリプト（util-scriptsへのコピー）

~/Dev/github-mcp-server/
├── github-mcp-server             # MCPサーバー本体
└── ...
```

## 参考資料

- [GitHub公式MCP](https://github.com/github/github-mcp-server)
- [Claude CodeのMCP](https://docs.claude.com/en/docs/claude-code/mcp)
- [macOS Keychain](https://support.apple.com/ja-jp/guide/keychain-access/welcome/mac)
- [1Password CLI](https://developer.1password.com/docs/cli/)
