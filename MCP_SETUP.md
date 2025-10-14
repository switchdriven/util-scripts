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

## MCPサーバーの切り替え

プロジェクトで使用するGitHubを切り替えたい場合、以下の方法があります。

### ⚠️ 重要な注意事項

MCPサーバーを切り替える際は、以下の点に注意してください：

1. **MCPサーバー名とツール名は別物**
   - 設定ファイルのサーバー名: `github-work` または `github-personal`
   - Claude Code内で使えるMCPツール名: サーバー名に関係なく固定
   - 実際の接続先: ラッパースクリプトで決定

2. **Claude Codeの再起動が必要**
   - MCPサーバーを切り替えた後は、**Claude Codeを完全に再起動**してください
   - 再起動しないと、古い設定のまま動作する可能性があります

3. **`gh` CLIとの使い分け**
   - MCPツールが正しく動作しない場合は、`gh`コマンドを使用することを推奨
   - `gh`コマンドは独自の認証情報を使用するため、より確実に動作します

### 方法1: 両方を登録して使い分ける（推奨）

会社用と個人用の両方を登録しておき、Claude Code内で切り替える方法です。

```bash
# 会社用を追加
./setup-python-env.sh --mcp work .

# 個人用を追加
./setup-python-env.sh --mcp personal .

# 確認
claude mcp list
# 出力:
# github-work: ... ✓ Connected
# github-personal: ... ✓ Connected

# Claude Codeを再起動
```

**Claude Code内での使い分け:**
```
# 会社用GitHubを使う
@github-work を有効にして、リポジトリ一覧を取得して

# 個人用GitHubを使う
@github-personal を有効にして、リポジトリ一覧を取得して
```

**メリット:**
- 削除不要で柔軟に使い分けられる
- プロジェクトごとに異なるGitHubを使える
- Claude Code内で簡単に切り替え可能

**この方法が最も推奨される理由:**
- 両方のGitHubアカウントを同時に使える
- 切り替えの手間が少ない
- MCPツールの動作が予測しやすい

### 方法2: 完全に置き換える

現在のMCPサーバーを削除して、別のものに置き換える方法です。

**⚠️ 注意: この方法には制限があります**
- MCPツールはClaude Code起動時に読み込まれるため、切り替え後に**Claude Codeの再起動が必須**です
- 再起動を忘れると、古い設定のまま動作する可能性があります
- **方法1（両方登録）の方が安全で推奨されます**

#### 会社用 → 個人用に切り替え

```bash
# 1. 会社用を削除
claude mcp remove github-work -s local

# 2. 個人用を追加
./setup-python-env.sh --mcp personal .
# スクリプト実行中に.envrcの更新を聞かれたら "Y" を選択

# 3. 確認
claude mcp list
# 出力: github-personal のみが表示される

# 4. Claude Codeを完全に再起動（重要！）
```

#### 個人用 → 会社用に切り替え

```bash
# 1. 個人用を削除
claude mcp remove github-personal -s local

# 2. 会社用を追加
./setup-python-env.sh --mcp work .
# スクリプト実行中に.envrcの更新を聞かれたら "Y" を選択

# 3. 確認
claude mcp list
# 出力: github-work のみが表示される

# 4. Claude Codeを完全に再起動（重要！）
```

**注意事項:**
- スクリプト実行時に`.envrc`の更新を確認されます → "Y"を選択
- 環境変数が新しいMCP設定に合わせて更新されます
- `direnv allow`で設定を再読み込み（スクリプトが自動実行）
- **必ずClaude Codeを再起動**してください
- 再起動しないと、MCPツールが正しく動作しない可能性があります

**代替手段:**
MCPツールが正しく動作しない場合は、以下のコマンドを直接使用することを推奨：
```bash
# リポジトリ作成
gh repo create <name> --public/--private

# リポジトリ操作
gh repo view <owner>/<repo>
gh issue list
gh pr list
```

### 方法3: 手動で追加・削除

スクリプトを使わずに直接操作する方法です。上級者向けです。

```bash
# MCPサーバーを追加
claude mcp add --transport stdio github-personal -- ~/Scripts/Shell/run-github-mcp-personal.sh

# MCPサーバーを削除
claude mcp remove github-work -s local

# 確認
claude mcp list

# Claude Codeを再起動（重要！）
```

手動で追加した場合は、`.envrc`も手動で編集する必要があります:

```bash
# .envrcを編集
vi .envrc

# 個人用の場合
export GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHub For MCP/token")

# 会社用の場合
export GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")

# direnvに変更を反映
direnv allow
```

### まとめ: おすすめの方法

以下の理由から、**方法1（両方登録）**を強く推奨します：

**方法1のメリット:**
- 最も柔軟で使いやすい
- プロジェクトごとに適切なGitHubを選択できる
- 削除の手間がない
- Claude Codeの再起動が不要（両方とも起動時に読み込まれる）
- MCPツールの動作が予測しやすい

**方法2・3の問題点:**
- Claude Codeの再起動が必須
- MCPツール名とサーバー名の不一致による混乱
- 切り替えの手間がかかる
- エラーが発生しやすい

**実際の運用では:**
- 両方のMCPサーバーを登録しておき、Claude Code内で`@github-work`または`@github-personal`を使い分ける
- MCPツールが動作しない場合は、`gh` CLIを使う
- この2つの方法を組み合わせることで、確実にGitHub操作ができます

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
