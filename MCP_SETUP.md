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
- **ラッパースクリプト**: `util-scripts/mcp-github.sh work`
- **環境変数**: `GITHUB_USERNAME=juny-s`（`.envrc`で自動設定）
- **利用可能な機能**: repos, issues, pull_requests, actions

### 2. 個人用GitHub（`github-personal`）

- **対象**: GitHub.com (`https://github.com`)
- **ユーザー名**: `switchdriven`
- **1Password**: `op://Personal/GitHub For MCP/token`
- **Keychain**: `github-personal-token`（`mcp-github-setting.sh`で同期）
- **ラッパースクリプト**: `util-scripts/mcp-github.sh personal`
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
│    ~/Dev/util-scripts/mcp-github.sh personal                │
│                                                               │
│  $ claude mcp add --transport stdio github-work --          │
│    ~/Dev/util-scripts/mcp-github.sh work                    │
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
│  1. mcp-github.sh を実行（personal or work）                 │
│  2. Keychain からトークン取得                                │
│  3. ~/Dev/github-mcp-server/github-mcp-server を起動          │
│  4. Claude Code と通信開始                                   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### ラッパースクリプト（mcp-github.sh）の役割

Keychain からトークンを取得して、GitHub MCPサーバーに渡すための中間層です：

```bash
#!/bin/sh
# GitHub MCP Server のラッパースクリプト
# Keychain からトークンを取得して MCPサーバーを起動

GITHUB_MCP_SERVER_PATH="/Users/junya/Dev/github-mcp-server/github-mcp-server"
PERSONAL_KEYCHAIN_NAME="github-personal-token"
WORK_KEYCHAIN_NAME="github-work-token"
WORK_GITHUB_HOST="https://gh.iiji.jp"

MODE=$1  # personal または work

# Keychain からトークン取得
TOKEN=$(security find-generic-password -w -s "$KEYCHAIN_NAME" 2>/dev/null)

# 環境変数をセットして MCPサーバーを起動
export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
[ -n "$GITHUB_HOST" ] && export GITHUB_HOST="$GITHUB_HOST"

exec $GITHUB_MCP_SERVER_PATH stdio
```

**重要**: Keychain に直接アクセスしているため、APIトークンをファイルに保存する必要がありません。

## セットアップ手順

### 前提条件：初回セットアップ（1回だけ実行）

MCPを使う前に、APIトークンを Keychain に登録する必要があります：

```bash
# 1. ~/Dev/util-scripts に移動
cd ~/Dev/util-scripts

# 2. mcp-github-setting.sh を実行
./mcp-github-setting.sh
```

このスクリプトが以下を自動的に行います：
1. 1Password から API トークン取得
   - 個人用: `op://Personal/GitHub For MCP/token`
   - 会社用: `op://Personal/GitHubEnt For MCP/token`
2. Keychain に登録
   - 個人用: `github-personal-token`
   - 会社用: `github-work-token`
3. 同期確認（OK/NG を表示）

**注意**: トークン更新時も再度このスクリプトを実行してください。

### MCPサーバーの登録（1回だけ実行）

MCPサーバーを Claude Code に登録します：

```bash
# 個人用GitHub
claude mcp add --transport stdio github-personal -- \
  ~/Dev/util-scripts/mcp-github.sh personal

# 会社用GitHub
claude mcp add --transport stdio github-work -- \
  ~/Dev/util-scripts/mcp-github.sh work

# 確認
claude mcp list
```

出力例：
```
github-personal: ~/Dev/util-scripts/mcp-github.sh personal  - ✓ Connected
github-work: ~/Dev/util-scripts/mcp-github.sh work  - ✓ Connected
```

### 新規プロジェクトのセットアップ

#### 会社用GitHubと連携する場合

```bash
./setup-python-env.sh --mcp work my-work-project
```

これにより以下が自動的に行われます:
1. Python仮想環境の作成（`.venv/`）
2. direnv設定ファイル（`.envrc`）の作成
   - `GITHUB_USERNAME`: `juny-s`を設定
3. MCPサーバー `github-work` がプロジェクトで使用可能に

#### 個人用GitHubと連携する場合

```bash
./setup-python-env.sh --mcp personal my-personal-project
```

これにより以下が自動的に行われます:
1. Python仮想環境の作成（`.venv/`）
2. direnv設定ファイル（`.envrc`）の作成
   - `GITHUB_USERNAME`: `switchdriven`を設定
3. MCPサーバー `github-personal` がプロジェクトで使用可能に

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
github-personal: ~/Dev/util-scripts/mcp-github.sh personal  - ✓ Connected
github-work: ~/Dev/util-scripts/mcp-github.sh work  - ✓ Connected
```

### Keychain のトークン確認

```bash
# 個人用
security find-generic-password -s "github-personal-token" -a "$(whoami)" | grep "acct"

# 会社用
security find-generic-password -s "github-work-token" -a "$(whoami)" | grep "acct"
```

### Keychain のトークン更新

APIトークンを1Passwordで更新した場合、Keychain に同期してください：

```bash
./mcp-github-setting.sh
```

### MCPサーバーの削除

```bash
# 個人用を削除
claude mcp remove github-personal -s local

# 会社用を削除
claude mcp remove github-work -s local
```

**注意**: MCPサーバーを削除してもKeychain のトークンは残ります。必要に応じて別途削除してください。

## Claude Code 内での使い方

両方のMCPサーバーを登録した場合、Claude Code内で使い分けることができます：

```
# 会社用GitHubを使う
@github-work を有効にして、リポジトリ一覧を取得して

# 個人用GitHubを使う
@github-personal を有効にして、リポジトリ一覧を取得して
```

### MCPが動作しない場合

MCPツールがエラーになった場合は、`gh` CLI を使用することを推奨します：

```bash
# リポジトリ作成
gh repo create <name> --public/--private

# リポジトリ操作
gh repo view <owner>/<repo>
gh issue list
gh pr list
```

`gh` CLI は独自の認証情報を使用するため、MCPに依存せず確実に動作します。

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
~/Dev/github-mcp-server/
└── github-mcp-server                      # GitHub公式MCPサーバー（Go実装）

~/Dev/util-scripts/
├── mcp-github.sh                          # MCPサーバーのラッパースクリプト
├── mcp-github-setting.sh                  # トークン同期スクリプト（1Password → Keychain）
├── setup-python-env.sh                    # Pythonプロジェクトセットアップ（Bash版）
├── setup-python-env.rb                    # Pythonプロジェクトセットアップ（Ruby版）
├── setup-ruby-env.rb                      # Rubyプロジェクトセットアップ
├── MCP_SETUP.md                           # このドキュメント
└── CLAUDE.md                              # プロジェクトガイド

~/.claude.json                             # ✅ Claude Code の MCP設定（自動生成）

macOS Keychain
├── github-personal-token                  # 個人用APIトークン
└── github-work-token                      # 会社用APIトークン
```

## セキュリティと運用のベストプラクティス

### トークン管理

**✅ 推奨方法**:
- **1Password**: APIトークンの原本を管理
- **Keychain**: 実行時にトークンを取得（`security` コマンド経由）
- **ファイルには保存しない**: `.envrc` や設定ファイルにトークンを直接記述しない

**❌ やってはいけないこと**:
- APIトークンをスクリプトにハードコードする
- トークンを Git で管理する（`.gitignore` に含める）
- トークンを環境ファイル（`.env`など）に直接記述する

### MCPサーバーの実行権限

`mcp-github.sh` が実行可能であることを確認：

```bash
ls -l ~/Dev/util-scripts/mcp-github.sh
# -rwxr-xr-x が表示されることを確認
```

実行権限がない場合：

```bash
chmod +x ~/Dev/util-scripts/mcp-github.sh
chmod +x ~/Dev/util-scripts/mcp-github-setting.sh
```

### 1Password CLI の認証

MCPセットアップを行う前に、1Password CLI が認証されていることを確認：

```bash
op account list
```

サインインが必要な場合：

```bash
eval $(op signin)
```

## セキュリティ考慮事項

1. **トークンはファイルに保存しない**: Keychain から実行時に取得
2. **`.envrc` はgitignoreに追加**: 環境変数が含まれる可能性があるため
3. **ラッパースクリプトは共有可能**: トークンは含まれていないため安全
4. **Keychain のトークンは自動保護**: macOS のセキュリティモデルで保護される

## トラブルシューティング

### MCPサーバーが接続できない

1. **Keychain にトークンが登録されているか確認**:
   ```bash
   security find-generic-password -s "github-personal-token"
   ```

2. **1Password CLI が認証されているか確認**:
   ```bash
   op account list
   ```

3. **mcp-github.sh が実行可能か確認**:
   ```bash
   ls -l ~/Dev/util-scripts/mcp-github.sh
   ```

4. **github-mcp-server バイナリが存在するか確認**:
   ```bash
   ls -l ~/Dev/github-mcp-server/github-mcp-server
   ```

5. **Claude Code を再起動**: 設定変更後は必ず再起動してください

### トークン同期エラー

```bash
./mcp-github-setting.sh
```

実行時にエラーが出た場合：

1. 1Password CLI で認証されているか確認
2. 1Password 内のトークンパスが正しいか確認
3. Keychain が満杯でないか確認（`Keychain Access.app` で確認可能）

## 参考資料

- [Claude Code公式ドキュメント - MCP](https://docs.claude.com/en/docs/claude-code/mcp)
- [GitHub MCP Server（公式）](https://github.com/github/github-mcp-server)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [macOS Keychain](https://support.apple.com/en-us/HT204030)

## 更新履歴

- 2025-11-12: 全面改定
  - `~/Dev/github-mcp-server`（公式サーバー）の使用に統一
  - Keychain ベースのトークン管理に変更
  - `mcp-github.sh` と `mcp-github-setting.sh` を説明
  - 仮想環境フォルダを `.venv_uv/` から `.venv/` に更新
  - 複雑な切り替え方法を削除し、シンプルに

- 2025-10-14: 初版作成
