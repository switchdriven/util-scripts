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

このリポジトリはユーティリティスクリプト集です。各スクリプトの使い方は `--help` オプションで確認してください。

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

## 参考資料

- 各スクリプトの使い方: `./script --help` で確認
- [MCP_SETUP.md](./MCP_SETUP.md) - MCP の詳細設定とトラブルシューティング
- [uv 公式ドキュメント](https://github.com/astral-sh/uv)
- [direnv 公式ドキュメント](https://direnv.net/)
- [Claude Code MCP](https://docs.claude.com/en/docs/claude-code/mcp)
