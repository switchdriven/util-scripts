# util-scripts

各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

## 主な機能

### 🌟 setup-env.rb（推奨）

統合開発環境セットアップスクリプストです。Python と Ruby の両方に対応し、言語を自動検出します。

- **Python と Ruby の両方に対応**
- **言語の自動検出機能**（pyproject.toml や Gemfile から自動判別）
- `uv`（Python）または `Bundler`（Ruby）での仮想環境管理
- `direnv`による環境の自動アクティベーション
- Claude Code MCP (Model Context Protocol) サーバーの設定
- 言語固有のプロジェクト構造を自動初期化

#### 使い方

```bash
# 言語を明示的に指定
./setup-env.rb --lang python my-project
./setup-env.rb --lang ruby my-project

# 短縮形
./setup-env.rb -l python my-project
./setup-env.rb -l ruby my-project

# バージョン指定
./setup-env.rb -l python -v 3.12 my-project
./setup-env.rb -l ruby -v 3.2 my-project

# MCP設定（明示的に指定）
./setup-env.rb -l python --mcp work my-work-project
./setup-env.rb -l ruby --mcp personal my-project

# 既存プロジェクト（言語自動検出）
cd existing-project
/path/to/setup-env.rb .

# MCP自動検出（ディレクトリベース）
./setup-env.rb -l python ~/Projects/work-project    # 自動的に --mcp work が適用
./setup-env.rb -l python ~/Dev/personal-project     # 自動的に --mcp personal が適用

# ヘルプの表示
./setup-env.rb --help
```

**機能**:
- **言語の自動検出**: `pyproject.toml` で Python、`Gemfile` で Ruby を自動検出
- **MCP の自動検出**: `~/Projects/*` で work、`~/Dev/*` で personal を自動検出
- **非対話モード対応**: CI/自動化環境で言語選択をスキップ（デフォルトは Python）

### setup-python-env.rb（Python専用）

Python開発環境を自動でセットアップするスクリプトです。

- `uv`を使ったPython仮想環境の作成
- `direnv`による環境の自動アクティベーション
- Claude Code MCP (Model Context Protocol) サーバーの設定
- プロジェクト構造の初期化（pyproject.toml、README.md、.gitignoreなど）

#### 使い方

```bash
# 基本的な使い方
./setup-python-env.rb my-project

# Pythonバージョンを指定
./setup-python-env.rb --python-version 3.12 my-project

# MCP設定
./setup-python-env.rb --mcp work my-work-project

# ヘルプの表示
./setup-python-env.rb --help
```

### setup-ruby-env.rb（Ruby専用）

Ruby開発環境を自動でセットアップするスクリプトです。

- Bundlerを使ったRubyプロジェクト管理
- `direnv`による環境の自動アクティベーション
- Claude Code MCP (Model Context Protocol) サーバーの設定
- プロジェクト構造の初期化（Gemfile、README.md、.gitignoreなど）

#### 使い方

```bash
# 基本的な使い方
./setup-ruby-env.rb my-project

# Ruby バージョンを指定
./setup-ruby-env.rb --ruby-version 3.2 my-project

# MCP設定
./setup-ruby-env.rb --mcp work my-work-project

# ヘルプの表示
./setup-ruby-env.rb --help
```

### setup-python-env.sh（レガシー版）

Bash実装の旧版です。Ruby版の `setup-python-env.rb` の使用を推奨します。

```bash
# 基本的な使い方（MCPなし）
./setup-python-env.sh my-project

# 会社用GitHub MCPを設定
./setup-python-env.sh --mcp work my-work-project

# 個人用GitHub MCPを設定
./setup-python-env.sh --mcp personal my-personal-project

# ヘルプの表示
./setup-python-env.sh --help
```

### check-python-env.sh

Python仮想環境を検索・確認するツールです。

- 指定ディレクトリ以下の全Python仮想環境を再帰的に検索
- `uv`と`venv`/`virtualenv`の環境を自動判別
- Pythonバージョンを表示
- カラー出力で見やすく表示

#### 使い方

```bash
# 基本的な使い方
./check-python-env.sh ~/Dev

# 深さを制限（最大3階層まで）
./check-python-env.sh -d 3 ~/Dev

# カレントディレクトリを検索
./check-python-env.sh .

# カラー出力を無効化
./check-python-env.sh --no-color ~/Dev

# ヘルプの表示
./check-python-env.sh --help
```

#### 出力例

```
Searching for Python virtual environments in: /Users/junya/Dev
  [venv] /Users/junya/Dev/iij-cf/.venv (Python 3.12.5)
  [uv]   /Users/junya/Dev/util-scripts/.venv (Python 3.13.8)
Found 2 environments: 1 uv, 1 venv
```

### llm-evaluator.py

OpenAI互換APIでアクセスできるLLMのトークン生成速度を評価するPythonスクリプトです。

- OpenAI、LiteLLM、Ollama APIに対応
- 複数プロンプトでのベンチマーク実行
- トークン/秒、レスポンス時間などの統計情報を表示
- 結果をJSONファイルにエクスポート可能

#### 使い方

```bash
# 基本的な使い方（OpenAI API）
./llm-evaluator.py --api-key YOUR_API_KEY --model gpt-3.5-turbo

# LiteLLMを使用
./llm-evaluator.py --api-key YOUR_KEY --base-url http://localhost:4000 --api-type litellm --model gpt-4

# Ollamaを使用
./llm-evaluator.py --api-key dummy --base-url http://localhost:11434 --api-type ollama --model llama2

# カスタム設定
./llm-evaluator.py --api-key YOUR_KEY --model gpt-4 --max-tokens 1000 --iterations 3 --output results.json

# カスタムプロンプトファイルを使用
./llm-evaluator.py --api-key YOUR_KEY --model gpt-4 --prompts-file my_prompts.json

# ヘルプの表示
./llm-evaluator.py --help
```

#### 必要な依存関係

```bash
# 依存パッケージのインストール
uv pip install -r requirements.txt
```

## 必須ツール

### Ruby環境（setup-ruby-env.rb使用時）

- **Ruby 3.0+**: スクリプト実行環境
  ```bash
  # macOS (Homebrew)
  brew install ruby@3.3
  ```
- **Bundler**: Ruby依存関係管理ツール
  ```bash
  gem install bundler
  ```
- **direnv**: 環境変数の自動読み込みツール
  ```bash
  brew install direnv
  # シェル設定に追加
  eval "$(direnv hook bash)"  # または zsh
  ```

### Python環境（setup-python-env.rb使用時）

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

### オプション

- **1Password CLI** (MCPを使う場合):
  ```bash
  brew install 1password-cli
  ```
- **Claude Code**: MCP機能を使う場合に必要

## ドキュメント

- [CLAUDE.md](CLAUDE.md) - プロジェクト全体のガイド（Claude Code用）
- [MCP_SETUP.md](MCP_SETUP.md) - MCP設定の詳細ガイド

## ライセンス

個人利用のためのユーティリティスクリプト集です。
