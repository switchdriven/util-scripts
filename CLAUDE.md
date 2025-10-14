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

2. **MCP設定**: GitHub Enterprise（会社用）とGitHub.com（個人用）のMCPサーバー設定
   - 1Password CLIを使った安全なトークン管理
   - ラッパースクリプトによるMCPサーバーの起動

## 開発環境

### Python環境
- Python仮想環境は`uv`で管理
- デフォルトのPythonバージョン: 3.13
- 仮想環境の場所: `.venv_uv/`（カスタマイズ可能）
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
source .venv_uv/bin/activate
```

## MCP（Model Context Protocol）設定

### MCPサーバーの種類

1. **github-work**: 会社用GitHub Enterprise
   - 対象: `gh.iiji.jp`
   - トークン: `op://Personal/GitHubEnt For MCP/token`
   - ラッパー: `~/Scripts/Shell/run-github-mcp-work.sh`

2. **github-personal**: 個人用GitHub.com
   - 対象: `github.com`
   - トークン: `op://Personal/GitHub For MCP/token`
   - ラッパー: `~/Scripts/Shell/run-github-mcp-personal.sh`

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
├── setup-python-env.sh           # メインセットアップスクリプト
├── MCP_SETUP.md                  # MCP設定の詳細ドキュメント
├── CLAUDE.md                     # このファイル（プロジェクトガイド）
└── README.md                     # プロジェクトREADME

~/Scripts/Shell/
├── run-github-mcp-work.sh        # 会社用GitHubラッパー
└── run-github-mcp-personal.sh    # 個人用GitHubラッパー
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

1. 1Password CLIが認証されているか確認:
   ```bash
   op account list
   eval $(op signin)  # 必要に応じて
   ```

2. トークンが読み込めるか確認:
   ```bash
   op read "op://Personal/GitHubEnt For MCP/token"
   ```

3. ラッパースクリプトが実行可能か確認:
   ```bash
   ls -l ~/Scripts/Shell/run-github-mcp-*.sh
   ```

4. Claude Codeを再起動

詳細は[MCP_SETUP.md](MCP_SETUP.md)のトラブルシューティングセクションを参照してください。

## 参考資料

- [setup-python-env.sh使い方](./setup-python-env.sh) - `--help`オプションで詳細を確認
- [MCP設定ガイド](./MCP_SETUP.md) - MCPの詳細な設定とトラブルシューティング
- [uv公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
