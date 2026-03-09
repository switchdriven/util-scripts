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

### check-network.rb

社内ネットワークの総合診断ツール。インターフェース状態・L3疎通（ARP）・DNS・Proxy・Web到達性をまとめてチェックする。

```bash
./check-network.rb --help
```

詳しくは [OFFICE-NETWORK-ISSUE.md](OFFICE-NETWORK-ISSUE.md) を参照。

### check-proxy.rb

プロキシサーバー経由の HTTP 接続を確認するツール。ISP 情報の取得、社内 Proxy 東西（proxy-w / proxy-e）の個別チェックにも対応。

```bash
./check-proxy.rb --help
```

### check-fxz.rb

FXZ VPN 接続時にローカルネットワーク宛のルーティングが VPN トンネルにリダイレクトされる問題を検出・修正するスクリプト。

```bash
./check-fxz.rb --help
```

詳しくは [FXZ-ISSUE.md](FXZ-ISSUE.md) を参照。

### check-squid.rb

Squid プロキシの設定ファイル（シンボリックリンク）を切り替え、サービスの再起動・再設定を行うツール。

```bash
./check-squid.rb --help
```

### check-mdns.rb

mDNS / Bonjour の状態を確認するツール。名前解決・DNS キャッシュ統計・サービス一覧・ヘルスチェック・キャッシュフラッシュに対応。

```bash
./check-mdns.rb --help
```

### mdig.sh

`.local` ホスト名を mDNS マルチキャスト（224.0.0.251:5353）で直接解決するシンプルなツール。

```bash
./mdig.sh <hostname>
```

### show-ip.rb

macOS のネットワークインターフェースの IP アドレス・MACアドレス・フラグ等を表示するツール。

```bash
./show-ip.rb --help
```

### show-port.rb

lsof を使って現在開いているネットワーク接続・ポートを表示するツール。

```bash
./show-port.rb --help
```

### show-services.rb

macOS の networksetup コマンドからネットワークサービス名とデバイス名の対応表を取得するツール。自動プロキシ設定の確認にも対応。

```bash
./show-services.rb --help
```

### check-sign.sh

pyHanko を使って PDF ファイルのデジタル署名を検証するスクリプト。

```bash
./check-sign.sh --help
```

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

### mcp-keychain-setting.sh

1Password から MCP サーバー用 API トークンを取得して macOS Keychain に登録するスクリプト。

```bash
./mcp-keychain-setting.sh
```

### mcp-tavily.sh

Keychain から Tavily API キーを取得して Tavily MCP サーバーを起動するラッパースクリプト。

```bash
./mcp-tavily.sh
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
- [OFFICE-NETWORK-ISSUE.md](OFFICE-NETWORK-ISSUE.md) - 社内ネットワーク障害診断スクリプトの要件・設計

## ライセンス

個人利用のためのユーティリティスクリプト集です。
