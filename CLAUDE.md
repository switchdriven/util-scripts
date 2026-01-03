# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリ（`util-scripts`）は、各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

### 主な機能

1. **setup-env.rb**: 統合開発環境セットアップスクリプト（推奨）
   - Python、Ruby、None（言語なし）の3つに対応
   - 言語の自動検出または明示的指定が可能
   - `uv`（Python）または `Bundler`（Ruby）での仮想環境の作成
   - `direnv`による環境の自動アクティベーション
   - Claude Code MCP (Model Context Protocol) サーバーの設定
   - プロジェクト構造の初期化
   - **None 言語**: JXA（JavaScript for Automation）やシェルスクリプト専用プロジェクトに対応

2. **setup-python-env.rb**: Python開発環境の専用セットアップスクリプト
   - `uv`を使ったPython仮想環境の作成
   - `direnv`による環境の自動アクティベーション
   - Claude Code MCP (Model Context Protocol) サーバーの設定
   - プロジェクト構造の初期化（pyproject.toml、README.md、.gitignoreなど）

3. **setup-ruby-env.rb**: Ruby開発環境の専用セットアップスクリプト
   - Rubyの仮想環境を作成
   - Bundlerによる依存関係管理
   - `direnv`による環境の自動アクティベーション
   - プロジェクト構造の初期化（Gemfile、README.md、.gitignoreなど）

4. **check-python-env.sh**: Python仮想環境の検索・確認ツール
   - 指定ディレクトリ以下の全Python仮想環境を再帰的に検索
   - `uv`と`venv`/`virtualenv`の環境を自動判別
   - Pythonバージョンを表示
   - カラー出力で見やすく表示

5. **llm-evaluator.py**: LLM速度ベンチマークツール
   - OpenAI互換APIでアクセスできるLLMのトークン生成速度を評価
   - OpenAI、LiteLLM、Ollama APIに対応
   - 複数プロンプトでのベンチマーク実行
   - トークン/秒、レスポンス時間などの詳細統計
   - 結果のJSONエクスポート機能

6. **migrate-mcp-to-local.rb**: MCP設定をグローバルからプロジェクトローカルに移行するツール
   - 既存プロジェクトのグローバル MCP 設定を `.mcp.json` に変換
   - ドライランモードで変更をプレビュー可能
   - `.gitignore` を自動で更新

7. **MCP設定**: GitHub Enterprise（会社用）とGitHub.com（個人用）のMCPサーバー設定
   - 1Password CLIを使った安全なトークン管理
   - ラッパースクリプトによるMCPサーバーの起動
   - プロジェクトローカルの `.mcp.json` で管理（バージョン管理対象）

## 開発環境

### Python環境
- Python仮想環境は`uv`で管理
- デフォルトのPythonバージョン: 3.13
- 仮想環境の場所: `.venv/`（カスタマイズ可能）
- 環境のアクティベーションは`direnv`が`.envrc`経由で自動実行

### 必須ツール
- **uv**: Python仮想環境管理ツール
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- **direnv**: 環境変数の自動読み込みツール
  ```bash
  brew install direnv
  # シェル設定に追加
  eval "$(direnv hook bash)"  # または zsh
  ```
- **1Password CLI** (MCPを使う場合):
  ```bash
  brew install 1password-cli
  ```
- **Claude Code**: MCP機能を使う場合に必要

### 環境セットアップ

#### 統合セットアップスクリプト（推奨）

`setup-env.rb` は Python、Ruby、None の3つの言語に対応し、言語を自動検出できます。

```bash
# 言語を明示的に指定する場合
./setup-env.rb --lang python my-project
./setup-env.rb --lang ruby my-project
./setup-env.rb --lang none my-jxa-project        # JXA/シェルスクリプト専用

# 短縮形
./setup-env.rb -l python my-project
./setup-env.rb -l ruby my-project
./setup-env.rb -l none my-jxa-project

# バージョン指定
./setup-env.rb --lang python --version 3.12 my-project
./setup-env.rb --lang ruby --version 3.2 my-project

# MCP設定（work または personal）
./setup-env.rb --lang python --mcp work my-work-project
./setup-env.rb --lang ruby --mcp personal my-project
./setup-env.rb --lang none --mcp work my-jxa-work-project

# 既存プロジェクトに適用（言語自動検出）
cd existing-project
/path/to/setup-env.rb .

# MCP自動検出（ディレクトリベース）
./setup-env.rb -l python ~/Projects/work-project    # 自動的に --mcp work が適用
./setup-env.rb -l python ~/Dev/personal-project     # 自動的に --mcp personal が適用
./setup-env.rb -l none ~/Projects/jxa-project       # 自動的に --mcp work が適用
```

**None 言語の用途**:
- JXA（JavaScript for Automation）プロジェクト
- シェルスクリプト専用プロジェクト
- 言語環境が不要で direnv と MCP のセットアップだけが必要な場合

#### 専用スクリプトを使用する場合

Python専用またはRuby専用のセットアップが必要な場合：

```bash
# Python専用
./setup-python-env.rb --version 3.12 my-project
./setup-python-env.rb --mcp work my-work-project

# Ruby専用
./setup-ruby-env.rb --version 3.2 my-project
./setup-ruby-env.rb --mcp personal my-project
```

#### 仮想環境のアクティベーション

ディレクトリに入ると、`direnv`が自動的に仮想環境をアクティベートします。

```bash
cd my-project
# 自動的に仮想環境がアクティベートされる

# 必要に応じて手動でアクティベート
source .venv/bin/activate          # Python
source .venv/bin/activate.sh       # Ruby
```

## MCP（Model Context Protocol）設定

### GitHubアカウント情報

- **会社用GitHub Enterprise**
  - ドメイン: `gh.iiji.jp`
  - ユーザー名: `juny-s`
  - MCPサーバー名: `github-work`
  - 環境変数: `GITHUB_USERNAME=juny-s`（`.envrc`で自動設定）

- **個人用GitHub.com**
  - ドメイン: `github.com`
  - ユーザー名: `switchdriven`
  - MCPサーバー名: `github-personal`
  - 環境変数: `GITHUB_USERNAME=switchdriven`（`.envrc`で自動設定）

`setup-python-env.sh`でMCP設定を指定すると、`.envrc`に自動的にGitHubユーザー名が設定されます。
Claude Codeはこのユーザー名を使ってMCP検索を行います。

### MCPサーバーの実装

- **MCPサーバー**: `~/Dev/github-mcp-server/github-mcp-server`（GitHub公式、Go実装）
- **トークン管理**: 1Password → macOS Keychain → MCPサーバー
- **ラッパースクリプト**: `~/Scripts/Shell/mcp-github-personal.sh` と `~/Scripts/Shell/mcp-github-work.sh`
- **設定管理**: プロジェクトローカルの `.mcp.json` ファイル（バージョン管理対象）

### MCPサーバーの種類

1. **github-work**: 会社用GitHub Enterprise
   - 対象: `gh.iiji.jp`
   - ユーザー名: `juny-s`
   - 1Password: `op://Personal/GitHubEnt For MCP/token`
   - Keychain: `github-work-token`
   - ラッパー: `~/Scripts/Shell/mcp-github-work.sh`

2. **github-personal**: 個人用GitHub.com
   - 対象: `github.com`
   - ユーザー名: `switchdriven`
   - 1Password: `op://Personal/GitHub For MCP/token`
   - Keychain: `github-personal-token`
   - ラッパー: `~/Scripts/Shell/mcp-github-personal.sh`

3. **perplexity**: Perplexity AI
   - サービス: Perplexity API
   - 1Password: `op://Personal/Perplexity API/credential`
   - Keychain: `perplexity-token`
   - ラッパー: `~/Scripts/Shell/mcp-perplexity.sh`

### Keychain トークン管理

API トークンは 1Password で管理し、`mcp-keychain-setting.sh` スクリプトで Keychain に同期しています。

#### トークンの初期化

以下のコマンドで 1Password のトークンを Keychain に同期します：

```bash
./mcp-keychain-setting.sh
```

実行内容：
- GitHub（personal・work）のトークンを Keychain に格納
- Perplexity API キーを Keychain に格納
- 各トークンを検証して正常に格納されたか確認

#### 手動でのトークン設定

Keychain に直接トークンを設定することも可能です：

```bash
# GitHub personal
security add-generic-password \
  -s "github-personal-token" \
  -a "$(whoami)" \
  -w "YOUR_GITHUB_PERSONAL_TOKEN"

# GitHub work
security add-generic-password \
  -s "github-work-token" \
  -a "$(whoami)" \
  -w "YOUR_GITHUB_WORK_TOKEN"

# Perplexity
security add-generic-password \
  -s "perplexity-token" \
  -a "$(whoami)" \
  -w "YOUR_PERPLEXITY_API_KEY"
```

#### トークンの確認

Keychain に格納されたトークンを確認します：

```bash
security find-generic-password -w -s "github-personal-token"
security find-generic-password -w -s "github-work-token"
security find-generic-password -w -s "perplexity-token"
```

### プロジェクトローカルMCP設定

`setup-env.rb` で MCP を設定すると、プロジェクトルートに `.mcp.json` ファイルが自動生成されます。

#### `.mcp.json` の構造

```json
{
  "mcpServers": {
    "github-personal": {
      "command": "/Users/junya/Scripts/Shell/mcp-github-personal.sh",
      "args": [],
      "env": {}
    }
  }
}
```

**重要なポイント**:
- ファイルは **プロジェクトルート** に配置（`.claude/` 直下ではない）
- `.mcp.json` は **git にコミット** すべき（プロジェクト設定）
- `.claude/` ディレクトリ は **.gitignore に含める**（ユーザー固有の権限設定）

#### 新規プロジェクトでの自動設定

```bash
# MCP設定を明示的に指定
./setup-env.rb --lang python --mcp personal my-project

# またはディレクトリベースの自動検出
./setup-env.rb -l python ~/Dev/my-personal-project     # personal が自動選択
./setup-env.rb -l python ~/Projects/my-work-project    # work が自動選択
```

結果：プロジェクトルートに `.mcp.json` が生成されます。

#### 既存プロジェクトの移行

既に MCP が グローバルに設定されているプロジェクトをプロジェクトローカル設定に移行するには、`migrate-mcp-to-local.rb` を使用します。

```bash
# ドライランモード（変更をプレビュー）
./migrate-mcp-to-local.rb --mcp personal --dry-run ~/Dev/old-project

# 実際に移行を実行
./migrate-mcp-to-local.rb --mcp personal ~/Dev/old-project
```

**実行例**:
```bash
$ ./migrate-mcp-to-local.rb --mcp personal ~/Dev/apple-scripts
[INFO] Creating new .mcp.json
[INFO] Created .mcp.json with 'github-personal' server ✓
[INFO] .gitignore already up to date ✓

============================================================
Migration complete! ✓
============================================================

Project: /Users/junya/Dev/apple-scripts
MCP Type: personal

Next steps:
  1. Review .mcp.json in your project root:
     cat /Users/junya/Dev/apple-scripts/.mcp.json

  2. Commit .mcp.json to version control:
     cd /Users/junya/Dev/apple-scripts
     git add .mcp.json .gitignore
     git commit -m 'feat: add project-local MCP configuration'

  3. (Optional) Remove global MCP registration:
     claude mcp remove github-personal -s local

  4. Test Claude Code in this project to verify MCP works
```

### MCP管理コマンド

```bash
# MCPサーバー一覧の確認
claude mcp list

# 特定のMCPサーバーの詳細確認
claude mcp get github-work

# MCPサーバーの削除（グローバル登録の場合）
claude mcp remove github-work -s local
```

**注意**: `setup-env.rb` で生成される `.mcp.json` はプロジェクトローカルなため、`claude mcp` コマンドで削除する必要がありません。プロジェクトから削除する場合は単に `.mcp.json` をファイルから削除してください。

### 詳細なMCP設定

詳細な設定方法とトラブルシューティングについては[MCP_SETUP.md](MCP_SETUP.md)を参照してください。

### GitHub操作のポリシー

Claude Codeでは、MCPと`gh` CLIの両方を使ってGitHub操作ができますが、以下のポリシーに従ってください。

#### 基本方針: `gh` CLIを優先

**重要な操作（失敗できない操作）は必ず`gh` CLIを使用してください。**

| 操作カテゴリ | 推奨ツール | 理由 |
|------------|----------|------|
| **リポジトリ作成・削除** | `gh` CLI | 確実性が最重要 |
| **PR作成・マージ** | `gh` CLI | 確実性が最重要 |
| **issue作成** | `gh` CLI | 確実性が最重要 |
| **ブランチ作成** | `gh` CLI | 確実性が最重要 |
| リポジトリ一覧・検索 | MCP可 | 分析作業なのでエラー許容 |
| issue一覧・検索・分析 | MCP可 | 分析作業なのでエラー許容 |
| PR一覧・レビュー確認 | MCP可 | 分析作業なのでエラー許容 |
| コード検索 | MCP可 | 分析作業なのでエラー許容 |

#### 具体的な使い分け

```bash
# ✅ 推奨: gh CLIで確実に実行
gh repo create my-project --public
gh pr create --title "feat: add feature" --body "Description"
gh issue create --title "Bug" --body "Details"

# ⚠️ MCPは補助的に使用（エラーが出たらgh CLIにフォールバック）
# Claude Code内で: "@github-personal を有効にして、過去1週間のPRを分析して"
```

#### エラー時の対応

MCPツールでエラーが発生した場合：
1. Claude Codeを再起動してみる
2. それでもダメなら`gh` CLIを使う
3. **`gh` CLIなら確実に動作する**

#### 理由

- **MCPはまだ発展途上**: 設定が複雑、エラーが発生しやすい
- **gh CLIは安定**: GitHub公式、独自認証、明確なエラーメッセージ
- **役割分担**: 重要な操作は確実性、分析作業は利便性を優先

詳細は[MCP_SETUP.md - MCPとgh CLIの使い分け](MCP_SETUP.md#mcpとgh-cliの使い分け)を参照してください。

## プロジェクト構造

このリポジトリはユーティリティスクリプトを格納するように設計されています。スクリプトを追加する際は、以下の観点で整理してください:
- 言語別（Python、Shell など）
- 用途別（ファイル操作、システムユーティリティ、自動化 など）

### ファイル構成

```
util-scripts/
├── setup-env.rb                  # 統合開発環境セットアップスクリプト（推奨）
├── setup-python-env.rb           # Python開発環境セットアップスクリプト（専用）
├── setup-ruby-env.rb             # Ruby開発環境セットアップスクリプト（専用）
├── check-python-env.sh           # Python仮想環境検索ツール
├── llm-evaluator.py              # LLM速度ベンチマークツール
├── migrate-mcp-to-local.rb       # MCP設定移行ツール（グローバル → プロジェクトローカル）
├── mcp-github-personal.sh        # GitHub MCP ラッパー（個人用）
├── mcp-github-work.sh            # GitHub MCP ラッパー（会社用）
├── mcp-github-setting.sh         # トークン同期スクリプト（1Password → Keychain）
├── MCP_SETUP.md                  # MCP設定の詳細ドキュメント
├── CLAUDE.md                     # このファイル（プロジェクトガイド）
└── README.md                     # プロジェクトREADME

~/Scripts/Shell/
├── mcp-github-personal.sh        # GitHub MCP ラッパー（個人用、シンボリックリンクまたはコピー）
├── mcp-github-work.sh            # GitHub MCP ラッパー（会社用、シンボリックリンクまたはコピー）
└── mcp-github-setting.sh         # トークン同期スクリプト（シンボリックリンク）

~/Dev/github-mcp-server/
└── github-mcp-server             # GitHub公式MCPサーバー（Go実装）
```

## 開発ガイドライン

### 新規スクリプトの追加

#### Pythonスクリプト
- Python 3.13+ の機能を使用
- 型ヒントを含める
- 適切なshebangを追加: `#!/usr/bin/env python3`
- スクリプトを実行可能にする: `chmod +x script.py`

#### シェルスクリプト
- 移植性のためbashを使用
- 適切なshebangを追加: `#!/usr/bin/env bash`
- 安全性のため`set -euo pipefail`を使用
- スクリプトを実行可能にする: `chmod +x script.sh`
- カラーコードを使って見やすい出力にする（setup-python-env.shを参考）

### 依存関係
- Pythonの依存関係は`uv`で管理
  ```bash
  uv pip install <package>
  uv pip freeze > requirements.txt
  ```
- `pyproject.toml`を使ったモダンなパッケージ管理を推奨
- システムレベルの依存関係はREADMEに記載

### テスト
- 適宜、ユーティリティスクリプトと並べてテストファイルを追加
- Pythonスクリプトにはpytestを使用
- シェルスクリプトにはbatsまたはshellcheckを使用

### セキュリティ
- GitHubトークンなどの機密情報は1Password CLIを使って管理
- `.envrc`は`.gitignore`に含める（機密情報が含まれる可能性があるため）
- ラッパースクリプトには機密情報を直接記述しない

## トラブルシューティング

### 仮想環境が自動的にアクティベートされない

1. direnvが正しくインストールされているか確認:
   ```bash
   command -v direnv
   ```

2. シェル設定でdirenvフックが有効か確認:
   ```bash
   # .bashrc または .zshrc に以下が含まれているか確認
   eval "$(direnv hook bash)"  # または zsh
   ```

3. direnvを許可:
   ```bash
   cd my-project
   direnv allow
   ```

### MCPサーバーが接続できない

詳細な設定とトラブルシューティングについては[MCP_SETUP.md](MCP_SETUP.md)を参照してください。

簡易チェックリスト：

1. **Keychain にトークンが登録されているか確認**:
   ```bash
   security find-generic-password -s "github-personal-token"
   ```

2. **1Password CLI が認証されているか確認**:
   ```bash
   op account list
   ```

3. **ラッパースクリプトが実行可能か確認**:
   ```bash
   ls -l ~/Dev/util-scripts/mcp-github.sh
   # -rwxr-xr-x であることを確認
   ```

4. **MCPサーバーが登録されているか確認**:
   ```bash
   claude mcp list
   ```

5. **Claude Code を再起動**: 設定変更後は必ず再起動してください

## スクリプトの使い方

### setup-env.rb

統合開発環境セットアップスクリプトです。Python と Ruby の両方に対応し、言語を自動検出します。

```bash
# 基本的な使い方（言語を明示的に指定）
./setup-env.rb --lang python my-project
./setup-env.rb --lang ruby my-project

# 短縮形
./setup-env.rb -l python my-project
./setup-env.rb -l ruby my-project

# バージョン指定
./setup-env.rb -l python -v 3.12 my-project
./setup-env.rb -l ruby -v 3.2 my-project

# MCP設定（明示的に指定）
./setup-env.rb --lang python --mcp work my-work-project
./setup-env.rb --lang ruby --mcp personal my-project

# 既存プロジェクト（言語自動検出）
cd existing-project
/path/to/setup-env.rb .

# MCP自動検出（ディレクトリベース）
./setup-env.rb -l python ~/Projects/work-project    # 自動的に --mcp work が適用
./setup-env.rb -l python ~/Dev/personal-project     # 自動的に --mcp personal が適用

# カスタム仮想環境ディレクトリ
./setup-env.rb -l python --venv-dir .venv-custom my-project

# ヘルプを表示
./setup-env.rb --help
```

**機能**:
- **言語の自動検出**: `pyproject.toml` で Python、`Gemfile` で Ruby を自動検出
- **MCP の自動検出**: プロジェクトディレクトリに基づいて自動的に MCP 設定を推測
  - `~/Projects/*` → work（GitHub Enterprise）
  - `~/Dev/*` → personal（GitHub.com）
  - その他のディレクトリ → MCP 設定なし
- **MCP 衝突検出**: 明示的に指定した MCP がディレクトリ推測と異なる場合、警告を表示
- **非対話モード対応**: CI/自動化環境で言語選択をスキップ（デフォルトは Python）
- **言語固有のファイル構造を自動生成**: pyproject.toml、Gemfile、README.md、.gitignoreなど
- **direnv 設定と MCP 統合に対応**

### check-python-env.sh

Python仮想環境を検索・確認するツールです。

```bash
# 基本的な使い方
./check-python-env.sh ~/Dev

# 深さを制限（最大3階層まで）
./check-python-env.sh -d 3 ~/Dev

# カレントディレクトリを検索
./check-python-env.sh .

# カラー出力を無効化
./check-python-env.sh --no-color ~/Dev

# ヘルプを表示
./check-python-env.sh --help
```

**出力例**:
```
Searching for Python virtual environments in: /Users/junya/Dev
  [venv] /Users/junya/Dev/iij-cf/.venv (Python 3.12.5)
  [uv]   /Users/junya/Dev/util-scripts/.venv (Python 3.13.8)
Found 2 environments: 1 uv, 1 venv
```

**機能**:
- `uv`で作成された仮想環境は`[uv]`（シアン色）で表示
- `venv`/`virtualenv`で作成された仮想環境は`[venv]`（緑色）で表示
- Pythonバージョンを自動検出（`pyvenv.cfg`から読み取り）
- サマリーで環境タイプごとの数を表示

### migrate-mcp-to-local.rb

グローバル MCP 設定をプロジェクトローカルの `.mcp.json` に移行するツールです。既存プロジェクトを新しい設定方式に移行する際に使用します。

```bash
# 基本的な使い方（実行前にドライランで確認）
./migrate-mcp-to-local.rb --mcp personal --dry-run ~/Dev/old-project

# 実際に移行を実行
./migrate-mcp-to-local.rb --mcp personal ~/Dev/old-project

# 会社用プロジェクトを移行
./migrate-mcp-to-local.rb --mcp work ~/Projects/work-project

# ヘルプを表示
./migrate-mcp-to-local.rb --help
```

**機能**:
- プロジェクトディレクトリから既存 MCP 設定を自動検出
- `.mcp.json` をプロジェクトルートに自動生成
- `.gitignore` を自動で更新（`.claude/` を除外）
- ドライランモード（`--dry-run`）で変更をプレビュー可能
- わかりやすいサマリーと次のステップを表示
- エラーハンドリング機能（カラーコード付き）

**出力例**:
```bash
$ ./migrate-mcp-to-local.rb --mcp personal ~/Dev/apple-scripts
[INFO] Creating new .mcp.json
[INFO] Created .mcp.json with 'github-personal' server ✓
[INFO] .gitignore already up to date ✓

============================================================
Migration complete! ✓
============================================================

Project: /Users/junya/Dev/apple-scripts
MCP Type: personal

Next steps:
  1. Review .mcp.json in your project root:
     cat /Users/junya/Dev/apple-scripts/.mcp.json

  2. Commit .mcp.json to version control:
     cd /Users/junya/Dev/apple-scripts
     git add .mcp.json .gitignore
     git commit -m 'feat: add project-local MCP configuration'

  3. (Optional) Remove global MCP registration:
     claude mcp remove github-personal -s local

  4. Test Claude Code in this project to verify MCP works
```

### llm-evaluator.py

OpenAI互換APIでアクセスできるLLMのトークン生成速度を評価するツールです。

```bash
# 基本的な使い方（OpenAI API）
./llm-evaluator.py --api-key YOUR_API_KEY --model gpt-3.5-turbo

# LiteLLMを使用
./llm-evaluator.py --api-key YOUR_KEY --base-url http://localhost:4000 --api-type litellm --model gpt-4

# Ollamaを使用
./llm-evaluator.py --api-key dummy --base-url http://localhost:11434 --api-type ollama --model llama2

# カスタム設定（複数回実行、結果をJSON出力）
./llm-evaluator.py --api-key YOUR_KEY --model gpt-4 --max-tokens 1000 --iterations 3 --output results.json

# カスタムプロンプトファイルを使用
./llm-evaluator.py --api-key YOUR_KEY --model gpt-4 --prompts-file my_prompts.json

# ヘルプを表示
./llm-evaluator.py --help
```

**機能**:
- OpenAI、LiteLLM、Ollama APIに対応
- 複数のテストプロンプトで自動ベンチマーク
- トークン/秒、レスポンス時間の詳細統計（平均、中央値、標準偏差など）
- 結果をJSONファイルにエクスポート可能
- localhost自動変換（IPv4/IPv6問題の回避）

**依存関係**:
```bash
# 必要なパッケージをインストール
uv pip install -r requirements.txt
```

## 参考資料

- [setup-env.rb使い方](./setup-env.rb) - `--help`オプションで詳細を確認（推奨）
- [setup-python-env.rb使い方](./setup-python-env.rb) - `--help`オプションで詳細を確認
- [setup-ruby-env.rb使い方](./setup-ruby-env.rb) - `--help`オプションで詳細を確認
- [check-python-env.sh使い方](./check-python-env.sh) - `--help`オプションで詳細を確認
- [migrate-mcp-to-local.rb使い方](./migrate-mcp-to-local.rb) - `--help`オプションで詳細を確認
- [llm-evaluator.py使い方](./llm-evaluator.py) - `--help`オプションで詳細を確認
- [MCP設定ガイド](./MCP_SETUP.md) - MCPの詳細な設定とトラブルシューティング
- [uv公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
