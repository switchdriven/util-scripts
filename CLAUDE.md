# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリ（`util-scripts`）は、各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

### 主な機能

1. **setup-env.rb**: 統合開発環境セットアップスクリプト（推奨）
   - Python、Ruby、None（言語なし）の3つの言語に対応
   - 言語の自動検出と `direnv`、MCP サーバーの自動セットアップ
   - **None 言語**: JXA や シェルスクリプト専用プロジェクト向け

2. **check-python-env.sh**: Python仮想環境の検索・確認ツール
   - 指定ディレクトリ以下の全仮想環境を再帰的に検索・判別

3. **llm-evaluator.py**: LLM速度ベンチマークツール
   - OpenAI、LiteLLM、Ollama API の トークン生成速度を評価

4. **MCP設定**: GitHub（個人用・会社用）と Perplexity AI の統合
   - 1Password で管理したトークンを Keychain 経由で MCP サーバーに提供
   - プロジェクトローカルの `.mcp.json` で MCP サーバー設定

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

`setup-env.rb` で MCP 設定を指定すると、`.envrc` に自動的に GitHub ユーザー名が設定されます。
Claude Code はこのユーザー名を使ってMCP検索を行います。

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

1Password のトークンを Keychain に同期：

```bash
./mcp-keychain-setting.sh
```

GitHub（personal・work）と Perplexity のトークンを一括で Keychain に格納・検証します。

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

`setup-env.rb` で MCP を設定すると、プロジェクトルートに `.mcp.json` が自動生成されます。

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

**重要**:
- `.mcp.json` はプロジェクトルートに配置（git コミット対象）
- `.claude/` は `.gitignore` に含める

### MCP 設定フロー

#### GitHub MCP の自動検出

ディレクトリ位置に基づいて自動検出・確認します：

```bash
# ~/Dev/* → personal が推測される（確認あり）
./setup-env.rb -l python ~/Dev/my-project

# ~/Projects/* → work が推測される（確認あり）
./setup-env.rb -l python ~/Projects/my-project

# 上記以外 → MCP選択肢が提示される
./setup-env.rb -l python ~/other/my-project
```

**挙動：**

1. **自動検出段階**: ディレクトリ位置から GitHub MCP を推測
2. **ユーザー確認**: 推測結果に対して「この設定を使う？」と確認
   - 「yes」: その MCP が設定される
   - 「no」: 選択肢メニューが表示される
3. **選択肢メニュー**（確認なし or 推測失敗時）:
   ```
   Do you want to configure an MCP server?
     1) GitHub Enterprise (work) - gh.iiji.jp
     2) GitHub Personal (personal) - github.com
     3) Perplexity AI (perplexity)
     4) None (skip MCP setup)
   ```

#### 明示的指定

```bash
./setup-env.rb --lang python --mcp work my-project        # GitHub work
./setup-env.rb --lang python --mcp personal my-project    # GitHub personal
./setup-env.rb --lang python --mcp perplexity my-project  # Perplexity
./setup-env.rb --lang python my-project                   # MCP設定なし
```

#### 非対話モード

対話入力がない場合（CI環境など）:
- 自動検出後の確認で入力がない → MCP設定なし
- 選択肢メニューで入力がない → MCP設定なし

#### Perplexity の使用方法

**MCP 経由でPerplexity を使う場合**:

```bash
./setup-env.rb --lang python --mcp perplexity my-project
# → .mcp.json に perplexity サーバーが自動追加される
```

**MCP 経由しない場合**（直接 API 使用など）:
- 手動設定は不要
- プロジェクトコードから直接 Perplexity API を呼び出し

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

- [setup-env.rb](./setup-env.rb) - `--help` で詳細を確認
- [check-python-env.sh](./check-python-env.sh) - `--help` で詳細を確認
- [llm-evaluator.py](./llm-evaluator.py) - `--help` で詳細を確認
- [MCP_SETUP.md](./MCP_SETUP.md) - MCP の詳細設定とトラブルシューティング
- [uv 公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv 公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
