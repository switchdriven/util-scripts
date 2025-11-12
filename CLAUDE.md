# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリ（`util-scripts`）は、各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

### 主な機能

1. **setup-python-env.sh**: Python開発環境の自動セットアップ
   - `uv`を使ったPython仮想環境の作成
   - `direnv`による環境の自動アクティベーション
   - Claude Code MCP (Model Context Protocol) サーバーの設定
   - プロジェクト構造の初期化（pyproject.toml、README.md、.gitignoreなど）

2. **check-python-env.sh**: Python仮想環境の検索・確認ツール
   - 指定ディレクトリ以下の全Python仮想環境を再帰的に検索
   - `uv`と`venv`/`virtualenv`の環境を自動判別
   - Pythonバージョンを表示
   - カラー出力で見やすく表示

3. **llm-evaluator.py**: LLM速度ベンチマークツール
   - OpenAI互換APIでアクセスできるLLMのトークン生成速度を評価
   - OpenAI、LiteLLM、Ollama APIに対応
   - 複数プロンプトでのベンチマーク実行
   - トークン/秒、レスポンス時間などの詳細統計
   - 結果のJSONエクスポート機能

4. **MCP設定**: GitHub Enterprise（会社用）とGitHub.com（個人用）のMCPサーバー設定
   - 1Password CLIを使った安全なトークン管理
   - ラッパースクリプトによるMCPサーバーの起動

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

#### 新規プロジェクトの作成

```bash
# 基本的な使い方（MCPなし）
./setup-python-env.sh my-project

# 会社用GitHub MCPを設定
./setup-python-env.sh --mcp work my-work-project

# 個人用GitHub MCPを設定
./setup-python-env.sh --mcp personal my-personal-project

# カスタムPythonバージョン
./setup-python-env.sh --python-version 3.12 my-project

# カスタム仮想環境ディレクトリ
./setup-python-env.sh --venv-dir .venv my-project
```

#### 既存プロジェクトへのセットアップ

```bash
cd existing-project
/path/to/setup-python-env.sh --mcp work .
```

#### 仮想環境のアクティベーション

ディレクトリに入ると、`direnv`が自動的にPython仮想環境をアクティベートします。

```bash
cd my-project
# 自動的に仮想環境がアクティベートされる

# 必要に応じて手動でアクティベート
source .venv/bin/activate
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
- **ラッパースクリプト**: `util-scripts/mcp-github.sh`（personal/work）

### MCPサーバーの種類

1. **github-work**: 会社用GitHub Enterprise
   - 対象: `gh.iiji.jp`
   - ユーザー名: `juny-s`
   - 1Password: `op://Personal/GitHubEnt For MCP/token`
   - Keychain: `github-work-token`
   - ラッパー: `util-scripts/mcp-github.sh work`

2. **github-personal**: 個人用GitHub.com
   - 対象: `github.com`
   - ユーザー名: `switchdriven`
   - 1Password: `op://Personal/GitHub For MCP/token`
   - Keychain: `github-personal-token`
   - ラッパー: `util-scripts/mcp-github.sh personal`

### MCP管理コマンド

```bash
# MCPサーバー一覧の確認
claude mcp list

# 特定のMCPサーバーの詳細確認
claude mcp get github-work

# MCPサーバーの削除
claude mcp remove github-work -s local
```

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
├── mcp-github.sh                 # MCPサーバーラッパースクリプト
├── mcp-github-setting.sh         # トークン同期スクリプト（1Password → Keychain）
├── setup-python-env.sh           # Python開発環境セットアップスクリプト（Bash版）
├── setup-python-env.rb           # Python開発環境セットアップスクリプト（Ruby版）
├── setup-ruby-env.rb             # Ruby開発環境セットアップスクリプト
├── check-python-env.sh           # Python仮想環境検索ツール
├── MCP_SETUP.md                  # MCP設定の詳細ドキュメント
├── CLAUDE.md                     # このファイル（プロジェクトガイド）
└── README.md                     # プロジェクトREADME

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

- [setup-python-env.sh使い方](./setup-python-env.sh) - `--help`オプションで詳細を確認
- [check-python-env.sh使い方](./check-python-env.sh) - `--help`オプションで詳細を確認
- [llm-evaluator.py使い方](./llm-evaluator.py) - `--help`オプションで詳細を確認
- [MCP設定ガイド](./MCP_SETUP.md) - MCPの詳細な設定とトラブルシューティング
- [uv公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
