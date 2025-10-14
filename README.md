# util-scripts

各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

## 主な機能

### setup-python-env.sh

Python開発環境を自動でセットアップするスクリプトです。

- `uv`を使ったPython仮想環境の作成
- `direnv`による環境の自動アクティベーション
- Claude Code MCP (Model Context Protocol) サーバーの設定
- プロジェクト構造の初期化（pyproject.toml、README.md、.gitignoreなど）

#### 使い方

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

## 必須ツール

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

## ドキュメント

- [CLAUDE.md](CLAUDE.md) - プロジェクト全体のガイド（Claude Code用）
- [MCP_SETUP.md](MCP_SETUP.md) - MCP設定の詳細ガイド

## ライセンス

個人利用のためのユーティリティスクリプト集です。
