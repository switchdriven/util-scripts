# Claude Code MCP設定ガイド

## 概要

このドキュメントでは、`setup-python-env.sh`を使ってPythonプロジェクトを作成する際に、会社用と個人用のGitHub MCPサーバーを自動設定する方法を説明します。

## 前提条件

- **Claude Code**: インストール済みであること
- **1Password CLI (`op`)**: インストール済みで、認証が完了していること
- **uv**: Python仮想環境管理ツール
- **direnv**: 環境変数の自動読み込みツール

## MCPサーバーの種類

### 1. 会社用GitHub（`github-work`）

- **対象**: GitHub Enterprise (`gh.iiji.jp`)
- **トークン**: `op://Personal/GitHubEnt For MCP/token`
- **ラッパースクリプト**: `~/Scripts/Shell/run-github-mcp-work.sh`
- **利用可能な機能**: repos, issues, pull_requests, actions

### 2. 個人用GitHub（`github-personal`）

- **対象**: GitHub.com (`https://github.com`)
- **トークン**: `op://Personal/GitHub For MCP/token`
- **ラッパースクリプト**: `~/Scripts/Shell/run-github-mcp-personal.sh`
- **利用可能な機能**: repos, issues, pull_requests, actions

## アーキテクチャ

### 仕組み

```
┌─────────────────────────────────────┐
│ setup-python-env.sh --mcp work      │
└────────────────┬────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────┐
│ claude mcp add --transport stdio    │
│   github-work --                    │
│   ~/Scripts/Shell/                  │
│   run-github-mcp-work.sh            │
└────────────────┬────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────┐
│ ~/.claude.json (ローカル設定)        │
│ {                                   │
│   "projects": {                     │
│     "/path/to/project": {           │
│       "mcpServers": {               │
│         "github-work": {...}        │
│       }                             │
│     }                               │
│   }                                 │
│ }                                   │
└────────────────┬────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────┐
│ Claude Code起動時                    │
│ MCPサーバーを自動起動                │
└─────────────────────────────────────┘
```

### ラッパースクリプトの役割

MCPサーバーは直接1Passwordの参照（`op://...`）を解釈できないため、ラッパースクリプトが必要です:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1Passwordから実際のトークンを取得
export GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")
export GITHUB_HOST="https://gh.iiji.jp/"
export GITHUB_TOOLSETS="repos,issues,pull_requests,actions"

# 環境変数をセットした状態でMCPサーバーを起動
exec npx -y @modelcontextprotocol/server-github
```

## 使い方

### 新規プロジェクトのセットアップ

#### 会社用GitHubと連携する場合

```bash
./setup-python-env.sh --mcp work my-work-project
```

これにより以下が自動的に行われます:
1. Python仮想環境の作成（`.venv_uv/`）
2. direnv設定ファイル（`.envrc`）の作成
3. MCPサーバー `github-work` の登録（まだ登録されていない場合）

#### 個人用GitHubと連携する場合

```bash
./setup-python-env.sh --mcp personal my-personal-project
```

これにより `github-personal` MCPサーバーが登録されます。

#### MCP設定なしの場合

```bash
./setup-python-env.sh my-project
```

MCP設定をスキップします。

### 既存プロジェクトへのMCP追加

既存のプロジェクトにMCPを追加したい場合:

```bash
cd existing-project
/path/to/setup-python-env.sh --mcp work .
```

## MCP設定の確認と管理

### 設定済みMCPサーバーの確認

```bash
claude mcp list
```

出力例:
```
Checking MCP server health...

github-work: ~/Scripts/Shell/run-github-mcp-work.sh  - ✓ Connected
github-personal: ~/Scripts/Shell/run-github-mcp-personal.sh  - ✓ Connected
```

### MCPサーバーの詳細確認

```bash
claude mcp get github-work
```

### MCPサーバーの削除

```bash
claude mcp remove github-work -s local
```

## トラブルシューティング

### MCPサーバーが接続できない

1. **1Password CLIの認証を確認**:
   ```bash
   op read "op://Personal/GitHubEnt For MCP/token"
   ```

2. **ラッパースクリプトの実行権限を確認**:
   ```bash
   ls -l ~/Scripts/Shell/run-github-mcp-*.sh
   ```
   すべてのスクリプトが実行可能（`-rwxr-xr-x`）であることを確認

3. **MCPサーバーの状態を確認**:
   ```bash
   claude mcp list
   ```

4. **Claude Codeを再起動**: 設定変更後は必ず再起動が必要です

### トークンが読み込めない

1Password CLIが正しく認証されているか確認:
```bash
op account list
```

サインインが必要な場合:
```bash
eval $(op signin)
```

### MCPツールが使えない

Claude Code内でMCPサーバーを@メンションして有効/無効を切り替えられます:
```
@github-work を有効にして
```

## ファイル構成

```
~/Scripts/Shell/
├── run-github-mcp-work.sh                 # 会社用GitHubラッパー
└── run-github-mcp-personal.sh             # 個人用GitHubラッパー

util-scripts/
├── setup-python-env.sh                    # メインセットアップスクリプト
├── MCP_SETUP.md                           # このドキュメント
└── .mcp.json                              # ❌ 使用されない（参考用のみ）

~/.claude.json                             # ✅ 実際の設定ファイル（自動生成）
```

## 重要な注意事項

### ❌ 動作しない方法

以下の方法は**Claude Codeでは動作しません**:

1. **プロジェクトローカルの `.mcp.json`**:
   - プロジェクトルートに配置しても認識されない
   - チームで共有できない

2. **VSCodeの `settings.json` に直接記述**:
   - `claude-code.mcpServers` は認識されない

3. **環境変数の直接参照**:
   ```json
   {
     "env": {
       "GITHUB_PERSONAL_TOKEN": "$GITHUB_WORK_TOKEN"
     }
   }
   ```
   - 変数展開されない

### ✅ 正しい方法

- **`claude mcp add` コマンドを使用する**
- **ラッパースクリプトで1Passwordトークンを取得する**
- **`~/.claude.json` に自動的に保存される**

## セキュリティ考慮事項

1. **トークンはファイルに保存しない**: 1Password CLIを使って実行時に取得
2. **`.envrc` はgitignoreに追加**: 環境変数が含まれる可能性があるため
3. **ラッパースクリプトは共有可能**: トークンは含まれていないため安全

## 参考資料

- [Claude Code公式ドキュメント - MCP](https://docs.claude.com/en/docs/claude-code/mcp)
- [GitHub MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/github)
- [1Password CLI](https://developer.1password.com/docs/cli/)

## 更新履歴

- 2025-10-14: 初版作成
  - `claude mcp add` コマンドを使用する方式に変更
  - `.mcp.json` シンボリックリンク方式を廃止
  - ラッパースクリプトを `~/Scripts/Shell/` に配置
  - スクリプト名を `run-github-mcp-(work|personal).sh` に統一
