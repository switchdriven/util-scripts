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
- **ユーザー名**: `juny-s`
- **トークン**: `op://Personal/GitHubEnt For MCP/token`
- **ラッパースクリプト**: `~/Scripts/Shell/run-github-mcp-work.sh`
- **環境変数**: `GITHUB_USERNAME=juny-s`（`.envrc`で自動設定）
- **利用可能な機能**: repos, issues, pull_requests, actions

### 2. 個人用GitHub（`github-personal`）

- **対象**: GitHub.com (`https://github.com`)
- **ユーザー名**: `switchdriven`
- **トークン**: `op://Personal/GitHub For MCP/token`
- **ラッパースクリプト**: `~/Scripts/Shell/run-github-mcp-personal.sh`
- **環境変数**: `GITHUB_USERNAME=switchdriven`（`.envrc`で自動設定）
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
   - `GITHUB_WORK_TOKEN`: 1Passwordから取得
   - `GITHUB_USERNAME`: `juny-s`を設定
3. MCPサーバー `github-work` の登録（まだ登録されていない場合）

#### 個人用GitHubと連携する場合

```bash
./setup-python-env.sh --mcp personal my-personal-project
```

これにより以下が自動的に行われます:
1. Python仮想環境の作成（`.venv_uv/`）
2. direnv設定ファイル（`.envrc`）の作成
   - `GITHUB_PERSONAL_TOKEN`: 1Passwordから取得
   - `GITHUB_USERNAME`: `switchdriven`を設定
3. MCPサーバー `github-personal` の登録（まだ登録されていない場合）

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
export GITHUB_USERNAME="switchdriven"

# 会社用の場合
export GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")
export GITHUB_USERNAME="juny-s"

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

## MCPと`gh` CLIの使い分け

実際の運用では、MCPと`gh` CLIを使い分けることが重要です。

### MCPのメリット

1. **Claude Code内で完結**
   - GitHubの情報をシームレスに取得・分析
   - コンテキストを保持しながら複数の操作が可能
   ```
   例: 「リポジトリのissue一覧を取得して、最新のものを要約して」
   ```

2. **複雑な操作の自動化**
   - 複数リポジトリの横断検索
   - PRレビューコメントの自動分析
   - issueの内容から関連ファイルを特定

3. **構造化されたデータ**
   - MCPはJSON形式でデータを返す
   - Claude Codeが理解しやすい形式

### MCPのデメリット

1. **設定が複雑**
   - ラッパースクリプト、1Password CLI、トークン管理が必要
   - Claude Codeの再起動が必要な場合がある

2. **エラーが発生しやすい**
   - APIレート制限
   - 認証エラー
   - サーバー名とツール名の不一致による混乱

3. **デバッグが困難**
   - エラーメッセージが分かりにくい
   - どこで失敗しているか特定しづらい

### `gh` CLIのメリット

1. **安定性が高い**
   - GitHub公式CLI
   - 独自の認証管理（`~/.config/gh/hosts.yml`）
   - 明確なエラーメッセージ

2. **シンプルな設定**
   - インストール: `brew install gh`
   - 認証: `gh auth login`
   - 以上で完了

3. **柔軟性**
   - コマンドラインで直接実行可能
   - スクリプト化しやすい
   - MCP設定に依存しない

### 推奨: ハイブリッドアプローチ

**基本方針: `gh` CLIをメインに、MCPは補助的に使う**

| 操作 | 推奨ツール | 理由 |
|------|----------|------|
| **リポジトリ作成** | `gh` CLI | 確実に動作、設定不要 |
| リポジトリ一覧取得 | MCP | Claude Codeで分析しやすい |
| **PR作成・マージ** | `gh` CLI | 確実に動作 |
| PRレビュー・分析 | MCP | コンテキストを保持、複数PR比較 |
| **issue作成** | `gh` CLI | 確実に動作 |
| issue検索・分析 | MCP | 横断検索、パターン分析 |
| **ブランチ作成** | `gh` CLI | 確実に動作 |
| コード検索 | MCP | 複数リポジトリ横断検索 |

**太字は特に重要な操作（失敗できない操作）**

### 実践的なガイドライン

#### 1. 基本操作は`gh` CLIを使う

```bash
# リポジトリ作成
gh repo create my-project --public

# PR作成
gh pr create --title "feat: add new feature" --body "Description"

# issue作成
gh issue create --title "Bug report" --body "Details"
```

#### 2. 分析・検索作業はMCPを試す

```
# Claude Code内で
@github-work を有効にして、過去1週間のPRを全て取得して傾向を分析して

# エラーが出たら gh CLI にフォールバック
```

#### 3. エラー時のフォールバック戦略

```bash
# MCPでエラーが出た場合
1. Claude Codeを再起動してみる
2. それでもダメなら gh CLI を使う
3. gh CLI なら確実に動作する
```

### 結論

**現時点（2025年時点）では、`gh` CLIをメインツールとして使い、MCPはオプション程度に考えるのが現実的です。**

理由：
- MCPはまだ発展途上の技術
- 設定の複雑さに対してメリットが限定的
- `gh` CLIで十分カバーできる

ただし、以下のケースではMCPが有用：
- 複数のリポジトリを横断して情報を収集・分析
- issueやPRの内容をClaude Codeに理解させて、関連ファイルを編集
- GitHubのデータを使った自動化タスク

### 将来的な展望

MCPが成熟すれば：
- より複雑な自動化が可能になる
- Claude Codeとの統合がシームレスになる
- エラーハンドリングが改善される
- 設定が簡略化される

その時点で、MCPをメインツールとして使うことを再検討すべきでしょう。

## GitHubユーザー名の設定と使い方

### 環境変数 `GITHUB_USERNAME`

`setup-python-env.sh`でMCP設定を指定すると、`.envrc`に自動的にGitHubユーザー名が設定されます。
この環境変数は、Claude CodeがMCP経由でGitHub検索を行う際に使用されます。

### 設定内容

| MCPタイプ | ユーザー名 | 環境変数 |
|----------|-----------|---------|
| `--mcp work` | `juny-s` | `GITHUB_USERNAME=juny-s` |
| `--mcp personal` | `switchdriven` | `GITHUB_USERNAME=switchdriven` |

### 具体的な使用例

#### リポジトリ検索
```bash
# MCPがこのユーザー名を使って検索
user:switchdriven  # 個人用
user:juny-s        # 会社用
```

#### Claude Code内での使い方
```
# 個人用GitHubで検索
@github-personal を有効にして、私のリポジトリ一覧を取得して

# 会社用GitHubで検索
@github-work を有効にして、私のリポジトリ一覧を取得して
```

Claude Codeは自動的に`$GITHUB_USERNAME`環境変数を参照して、適切なユーザー名で検索を行います。

### 確認方法

環境変数が正しく設定されているか確認：
```bash
# ディレクトリに移動（direnvが自動的に環境変数を読み込む）
cd my-project

# 環境変数を確認
echo $GITHUB_USERNAME
# 出力例: switchdriven または juny-s
```

### トラブルシューティング

#### 環境変数が設定されていない場合

1. `.envrc`を確認：
   ```bash
   cat .envrc
   # GITHUB_USERNAME="switchdriven" が含まれているか確認
   ```

2. direnvを再適用：
   ```bash
   direnv allow
   ```

3. VS Codeを再起動（必要に応じて）

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
