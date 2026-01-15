# util-scripts

各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

## 主な機能

### 🌟 setup-env.rb（推奨）

統合開発環境セットアップスクリプストです。Python、Ruby、または言語なし（direnv/MCP のみ）に対応し、言語を自動検出します。

- **Python、Ruby、None の3つの言語に対応**
- **言語の自動検出機能**（pyproject.toml や Gemfile から自動判別）
- `uv`（Python）または `Bundler`（Ruby）での仮想環境管理
- `direnv`による環境の自動アクティベーション
- Claude Code MCP (Model Context Protocol) サーバーの設定
- 言語固有のプロジェクト構造を自動初期化
- **direnv/MCP のみが必要なプロジェクトに対応**（JXA、シェルスクリプト専用プロジェクトなど）

#### 使い方

```bash
# 言語を明示的に指定
./setup-env.rb --lang python my-project
./setup-env.rb --lang ruby my-project
./setup-env.rb --lang none my-jxa-project         # direnv/MCP のみ

# 短縮形
./setup-env.rb -l python my-project
./setup-env.rb -l ruby my-project
./setup-env.rb -l none my-jxa-project

# バージョン指定
./setup-env.rb -l python -v 3.12 my-project
./setup-env.rb -l ruby -v 3.2 my-project

# MCP設定（明示的に指定）
./setup-env.rb -l python --mcp work my-work-project
./setup-env.rb -l ruby --mcp personal my-project
./setup-env.rb -l none --mcp work my-jxa-work-project

# 既存プロジェクト（言語自動検出）
cd existing-project
/path/to/setup-env.rb .

# MCP自動検出（ディレクトリベース）
./setup-env.rb -l python ~/Projects/work-project    # 自動的に --mcp work が適用
./setup-env.rb -l python ~/Dev/personal-project     # 自動的に --mcp personal が適用
./setup-env.rb -l none ~/Projects/jxa-project       # 自動的に --mcp work が適用

# ヘルプの表示
./setup-env.rb --help
```

**機能**:
- **言語の自動検出**: `pyproject.toml` で Python、`Gemfile` で Ruby、マーカーファイルなしで対話的に選択
- **MCP の自動検出**: `~/Projects/*` で work、`~/Dev/*` で personal を自動検出
- **None 言語対応**: `--lang none` で direnv と MCP のセットアップのみ（言語環境不要なプロジェクト向け）
- **非対話モード対応**: CI/自動化環境で言語選択をスキップ（デフォルトは Python）

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

### net-port.rb

macOS のネットワークポート情報を取得するRubyスクリプトです。AppleScriptからの呼び出しを想定した設計で、外部モジュール依存なしで実装されています。

- ハードウェアポート一覧、デバイス名、接続ステータス、IP アドレス、SSID を取得
- テキスト/JSON 形式の出力に対応
- AppleScript との連携に最適化
- **外部 Ruby ライブラリ不要**（Ruby 標準ライブラリのみ使用）

#### 使い方

```bash
# ハードウェアポート一覧を表示
./net-port.rb list

# ポート名からデバイス名を取得
./net-port.rb device Wi-Fi

# ポートのステータスを取得
./net-port.rb status Wi-Fi

# ポートの IPv4 アドレスを取得
./net-port.rb addr Wi-Fi

# Wi-Fi ポートの SSID を取得
./net-port.rb ssid Wi-Fi

# ポートのすべての情報を取得（推奨）
./net-port.rb all Wi-Fi

# JSON 形式で出力
./net-port.rb --format json list
./net-port.rb --format json device Wi-Fi
./net-port.rb --format json all Wi-Fi

# ヘルプを表示
./net-port.rb --help
```

#### AppleScript からの利用例

```applescript
-- Wi-Fi の SSID を取得
set currentSSID to (do shell script "/path/to/net-port.rb ssid Wi-Fi")
display dialog "Current network: " & currentSSID

-- Wi-Fi のステータスを確認してアクション
try
    set wifiStatus to (do shell script "/path/to/net-port.rb status Wi-Fi")
    if wifiStatus is "active" then
        display notification "Wi-Fi is connected"
    end if
on error errMsg
    display dialog "Error: " & errMsg buttons {"OK"} with icon caution
end try

-- Wi-Fi のすべての情報を取得（推奨）
set allInfo to (do shell script "/path/to/net-port.rb all Wi-Fi")
display dialog allInfo with title "All Wi-Fi Information"
```

#### 詳細ドキュメント

詳しくは [NET-PORT.md](NET-PORT.md) を参照してください。

### get-ssid.sh

現在接続しているWi-FiのSSIDを取得するシェルスクリプトです。

- macOSのプライバシー保護機構を回避してSSID情報を取得
- 指定したネットワークインターフェース（デフォルト: `en0`）の接続状態を確認
- リンクローカルアドレス（DHCP失敗）の検出
- 接続失敗時には適切なエラーメッセージを表示

#### 使い方

```bash
# デフォルト（en0インターフェース）
./get-ssid.sh

# 特定のインターフェースを指定
./get-ssid.sh en1

# スクリプト内で使用
SSID=$(./get-ssid.sh)
echo "Connected to: $SSID"
```

#### 動作原理

1. 指定インターフェースに有効なIPアドレスが割り当てられているか確認
2. リンクローカルアドレス（`169.254.*`）による接続失敗を検出
3. 優先ネットワーク一覧から現在のSSIDを取得

#### 戻り値

- **成功時**: SSID名を出力（終了コード0）
- **Wi-Fi未接続**: `Wi-Fi not connected (en0)` を出力（終了コード1）
- **DHCP失敗**: `Wi-Fi connection error - DHCP failed (en0)` を出力（終了コード1）
- **SSID取得失敗**: `Failed to get SSID (en0)` を出力（終了コード1）

**注**: `net-port.rb` でも SSID 取得機能が実装されているため、AppleScript からは `net-port.rb` の使用をお勧めします。

### archive-folder.sh

任意のディレクトリを日付付き tar.gz アーカイブでバックアップするシェルスクリプトです。

- `<ディレクトリ名>-YYYYMMDD.tar.gz` 形式でアーカイブ作成
- **デフォルト**: シンボリックリンクの先の実体をバックアップ
- `--no-dereference` オプションでシンボリックリンク情報のみを保存
- 同じ日付のバックアップが既存の場合は上書き確認
- バックアップ完了後に該当ディレクトリの直近5個を表示

#### 使い方

```bash
# デフォルト（~/Backup/Archives にアーカイブ作成、symlink を辿る）
./archive-folder.sh ~/Obsidian              # Obsidian-20240115.tar.gz を作成
./archive-folder.sh ~/Documents             # Documents-20240115.tar.gz を作成

# カスタムバックアップ先を指定
./archive-folder.sh ~/MyVault ~/MyBackups   # ~/MyBackups/MyVault-20240115.tar.gz を作成

# symlink を辿らずに保存
./archive-folder.sh --no-dereference ~/Obsidian

# 強制実行（既存のバックアップを上書き確認なし）
./archive-folder.sh --force ~/Obsidian      # 確認を飛ばして実行
./archive-folder.sh -f ~/Documents          # 短縮形

# オプション組み合わせ
./archive-folder.sh --force --no-dereference ~/Obsidian

# ヘルプの表示
./archive-folder.sh --help

# デバッグモード
DEBUG=1 ./archive-folder.sh ~/Obsidian
```

#### デフォルト動作

- **バックアップ先**: `~/Backup/Archives`
- **ファイル名形式**: `<ディレクトリ名>-YYYYMMDD.tar.gz`（例: `Obsidian-20240115.tar.gz`）
- **シンボリックリンク**: 先の実体をバックアップ（`--dereference` を使用）
  - `--no-dereference` オプションでシンボリックリンク情報のみを保存

#### launchd で自動バックアップを設定（macOS）

毎日起動時にバックアップを自動実行できます。

**1. テンプレートから plist を作成:**

```bash
# テンプレートをコピー
cp org.warumono.backup-obsidian.plist.template /tmp/org.warumono.backup-obsidian.plist

# パスを置換（以下のコマンドで置換）
sed -i '' \
  "s|PATH_TO_SCRIPT|$(pwd)/archive-folder.sh|g" \
  "s|PATH_TO_OBSIDIAN|$HOME/Obsidian|g" \
  "s|HOME_DIR|$HOME|g" \
  /tmp/org.warumono.backup-obsidian.plist

# plist をインストール
cp /tmp/org.warumono.backup-obsidian.plist ~/Library/LaunchAgents/

# launchd に登録
launchctl load ~/Library/LaunchAgents/org.warumono.backup-obsidian.plist
```

**2. 動作確認:**

```bash
# 登録状況確認
launchctl list | grep backup-obsidian

# 手動実行（テスト）
launchctl start org.warumono.backup-obsidian

# ログ確認
tail -20 ~/Library/Logs/backup-obsidian.log
```

**3. アンインストール:**

```bash
launchctl unload ~/Library/LaunchAgents/org.warumono.backup-obsidian.plist
rm ~/Library/LaunchAgents/org.warumono.backup-obsidian.plist
```

**トラブルシューティング:**

- iCloud ドライブを使用している場合、初回実行時にアクセス権付与を求められます
- ログは `~/Library/Logs/backup-obsidian.log` と `backup-obsidian-error.log` に記録されます
- スクリプトのパスが変わった場合は plist を再生成してください

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
