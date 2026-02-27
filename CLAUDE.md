# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリ（`util-scripts`）は、各種ヘルパースクリプトやツールを含むユーティリティスクリプト集です。

各スクリプトの機能については [README.md](README.md) を参照してください。

## 開発環境

### Python環境
- Python仮想環境は`uv`で管理
- デフォルトのPythonバージョン: 3.13
- 環境のアクティベーションは`direnv`が`.envrc`経由で自動実行

#### このリポジトリに `.venv` を作らない理由

このリポジトリの Python スクリプトは `~/Scripts/Python/` にシンボリックリンクを貼って運用しています。
実行時は `~/Scripts/.venv` が activate された状態になるため、このリポジトリ自体には仮想環境は不要です。

`pyproject.toml` は依存ライブラリの記録として残していますが、実際のパッケージ管理は `~/Scripts/.venv` に対して `uv pip install` で行います。

**`setup-env.rb` でこのリポジトリに `.venv` を作らないこと。** 作ると `~/Scripts/.venv` が上書きされ、スクリプトの実行環境が壊れます。

#### `.envrc` の構成

`.envrc` に `source ~/Scripts/.venv/bin/activate` を追加しています。これにより：

- `cd` 時に `VIRTUAL_ENV=/Users/junya/Scripts/.venv` が設定される
- `uv-maint.rb` がデフォルトで `VIRTUAL_ENV` を参照して正しい仮想環境を対象にする
- 各プロジェクト固有の `.venv` がある場合はそちらが優先される（direnv が上書き）

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

## MCP（Model Context Protocol）

詳細な設定方法については [MCP_SETUP.md](MCP_SETUP.md) を参照してください。

### GitHubアカウント情報

- **会社用GitHub Enterprise**: ドメイン `gh.iiji.jp`、ユーザー名 `juny-s`（MCPサーバー名: `github-work`）
- **個人用GitHub.com**: ドメイン `github.com`、ユーザー名 `switchdriven`（MCPサーバー名: `github-personal`）

`setup-env.rb` で MCP 設定を指定すると、`.envrc` に `GITHUB_USERNAME` が自動設定されます。

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

このリポジトリはユーティリティスクリプト集です。各スクリプトの使い方は `--help` オプションで確認してください。

## 開発ガイドライン

### 新規スクリプトの追加

#### Pythonスクリプト
- Python 3.13+ の機能を使用
- 型ヒントを含める
- 適切なshebangを追加: `#!/usr/bin/env python3`
- スクリプトを実行可能にする: `chmod +x script.py`

#### Rubyスクリプト
- **標準ライブラリのみで実装することを原則とする**
  - `open3`, `optparse`, `json`, `net/http` など標準添付ライブラリを優先
  - Homebrew Ruby（`/opt/homebrew/opt/ruby@3.3`）を使用、仮想環境なし・グローバルgem管理
  - 外部gem（nokogiri 等）はビルドコスト・グローバル汚染・可搬性低下のリスクがある
- **外部gemが必要になる場合は Ruby ではなく Python で実装する**
  - Python であれば `~/Scripts/.venv` で依存管理でき、環境が分離される
- 適切なshebangを追加: `#!/opt/homebrew/opt/ruby@3.3/bin/ruby`
  - `#!/usr/bin/env ruby` は使わない（AppleScript 等から呼ばれると古い system Ruby が使われるため）
  - Ruby をバージョンアップする際は全 `.rb` の shebang を一括置換すること:
    ```bash
    grep -rl "^#!/opt/homebrew/opt/ruby@3.3/bin/ruby" . --include="*.rb" --exclude-dir=".gems" \
      | xargs sed -i '' 's|ruby@3.3|ruby@3.4|g'
    ```
  - **新規スクリプト作成前に `brew outdated ruby@3.3` で新バージョンを確認すること**
- `# frozen_string_literal: true` を先頭に追加
- スクリプトを実行可能にする: `chmod +x script.rb`

#### シェルスクリプト
- 移植性のためbashを使用
- 適切なshebangを追加: `#!/usr/bin/env bash`
- 安全性のため`set -euo pipefail`を使用
- スクリプトを実行可能にする: `chmod +x script.sh`
- カラーコードを使って見やすい出力にする（setup-python-env.shを参考）

#### ドキュメント
- 各スクリプトには `--help` オプションを実装する
- README.md には概要1行 + `--help` のみ記載:
  ```markdown
  ### script-name.py

  スクリプトの概要を1行で説明。

  ```bash
  ./script-name.py --help
  ```
  ```

### 依存関係
- Pythonの依存関係は`pyproject.toml`で管理
  ```bash
  # pyproject.toml の dependencies に追加後
  uv pip install -e .
  ```
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

[MCP_SETUP.md](MCP_SETUP.md) のトラブルシューティングを参照してください。

## 参考資料

- 各スクリプトの使い方: `./script --help` で確認
- [MCP_SETUP.md](./MCP_SETUP.md) - MCP の詳細設定とトラブルシューティング
- [uv 公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv 公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
