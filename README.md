# util-scripts

各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

## 主な機能

### 🌟 setup-env.rb（推奨）

統合開発環境セットアップスクリプト。Python、Ruby、None（direnv/MCP のみ）に対応し、言語を自動検出します。

```bash
./setup-env.rb --help
```

### check-python-env.sh

指定ディレクトリ以下の Python 仮想環境を検索・確認するツール。

```bash
./check-python-env.sh --help
```

### llm-evaluator.py

OpenAI 互換 API の LLM トークン生成速度を評価するベンチマークツール。

```bash
./llm-evaluator.py --help
```

### net-port.rb

macOS のネットワークポート情報を取得するスクリプト。AppleScript からの呼び出しに最適化。

```bash
./net-port.rb --help
```

詳しくは [NET-PORT.md](NET-PORT.md) を参照。

### music-ctrl.rb

macOS の音楽制御サービス（com.apple.rcd）を管理するユーティリティ。

```bash
./music-ctrl.rb --help
```

### get-ssid.sh

現在接続している Wi-Fi の SSID を取得するスクリプト。

```bash
./get-ssid.sh
```

**注**: `net-port.rb` でも SSID 取得機能があります。

### run-code.sh

Proxifier の起動状態を検出して VS Code を起動するラッパースクリプト。

```bash
./run-code.sh --wrapper-help
```

Proxifier 起動中は自動的にプロキシ環境変数を無効化し、二重プロキシによる接続エラーを防ぎます。

### run-claude.sh

Proxifier の起動状態を検出して Claude Code を起動するラッパースクリプト。

```bash
./run-claude.sh --wrapper-help
```

Proxifier 起動中は自動的にプロキシ環境変数を無効化し、二重プロキシによる接続エラーを防ぎます。

### proxy-env.rb

macOS のシステムプロキシ（自動プロキシ設定）を参照・変更するツール。

```bash
./proxy-env.rb --help
```

### check-proxy.rb

プロキシサーバー経由の HTTP 接続を確認するツール。ISP 情報の取得にも対応。

```bash
./check-proxy.rb --help
```

### check-fxz.rb

FXZ VPN 接続時にローカルネットワーク宛のルーティングが VPN トンネルにリダイレクトされる問題を検出・修正するスクリプト。

```bash
./check-fxz.rb --help
```

詳しくは [FXZ-ISSUE.md](FXZ-ISSUE.md) を参照。

### uv-maint.rb

uv 管理の Python 仮想環境のパッケージをメンテナンスするツール。古いパッケージの確認・更新、依存関係チェック、孤立パッケージの検出ができます。対象の仮想環境は `$VIRTUAL_ENV` を自動参照します（`-p` で明示指定も可能）。

```bash
./uv-maint.rb --help
```

### archive-folder.sh

任意のディレクトリを日付付き tar.gz アーカイブでバックアップするスクリプト。

```bash
./archive-folder.sh --help
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
- [FXZ-ISSUE.md](FXZ-ISSUE.md) - FXZ VPN ルーティング問題の詳細
- [MCP_SETUP.md](MCP_SETUP.md) - MCP設定の詳細ガイド

## ライセンス

個人利用のためのユーティリティスクリプト集です。
