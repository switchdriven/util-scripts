# Zed Agent Mode で GitHub Copilot と Claude Code がリポジトリを共有する方法

## 概要

このリポジトリは元々 Claude Code（Agent）で運用していたが、Zed の Agent Mode から
GitHub Copilot CLI でも作業するようになった。両者がどこまで設定・コンテキストを
共有できるか、2026-11-20 に実地検証した結果をまとめる。

## 共有できるもの（追加作業不要）

### カスタム指示ファイル（`CLAUDE.md`）

Copilot CLI は起動時に `CLAUDE.md` を自動検出し、system prompt のカスタム指示として
読み込む。`AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` など複数の
規約ファイルに対応しているため、**このリポジトリのお作法（ブランチ運用・`gh` CLI優先・
言語別の実装方針など）は Claude Code / Copilot CLI の両方で自動的に共有される**。
新規ファイルを作る必要はない。

## 共有できないもの / ツール固有のもの

| 項目 | Claude Code | Copilot CLI |
|---|---|---|
| ローカル権限設定（Bashコマンド許可リストなど） | `.claude/settings.local.json` | `.github/copilot/settings.local.json`（`.gitignore`推奨） |
| 共有リポジトリ設定（コミット対象） | なし相当 | `.github/copilot/settings.json` |
| セッション状態・メモリ | `~/.claude/...` | `~/.copilot/session-state/` |
| エージェント定義 | Claude Agent形式 | `~/.copilot/agents/` |

必要なら `.claude/settings.local.json` の許可済みコマンドパターンを
`.github/copilot/settings.local.json` へ手動で移植すると、Copilot側でも同じ
コマンドを確認なしで実行できるようになる（未実施）。

## MCPサーバー設定（`.mcp.json`）: 環境によって挙動が異なる

このリポジトリには Claude Code 用に `.mcp.json`（`github-personal` / `github-work` /
`obsidian`）を置いてあるが、**実行環境によって読み込まれるかどうかが変わる**。

### 素の `copilot` CLI（ターミナルで直接起動）の場合 → 読み込まれる

- `copilot` 起動時、カレントディレクトリからリポジトリルートまで遡って
  `.mcp.json`（または `.github/mcp.json`）を探して読み込む仕様。
- フォーマットは Claude Code と同じ `{ "mcpServers": { "name": {...} } }`
  （bare top-level 形式も可）がそのまま使える。
- 優先順位: 同じ場所なら `.mcp.json` > `.github/mcp.json`、
  プロジェクト定義 > `~/.copilot/mcp-config.json`（ユーザーレベル）。
- 追加・確認コマンド:
  ```bash
  copilot mcp add SERVER-NAME -- COMMAND [ARGS...]   # stdio
  copilot mcp add --transport http SERVER-NAME URL   # HTTP
  /mcp add    # 対話モード
  /mcp list   # 読み込まれているサーバー一覧（--json可）
  ```

### Zed の Agent Mode（`copilot --acp` 経由）の場合 → 読み込まれない（既知のバグ）

Zed は `agent_servers.github-copilot-cli`（`~/.config/zed/settings.json`）経由で
`copilot --acp` を正しい cwd（リポジトリルート）で起動しているが、ログを見ても
MCPサーバー読み込み処理自体が一切走らない。これは Zed 側の不具合ではなく、
**`copilot` CLI 本体の `--acp` モードの既知バグ**:

- [github/copilot-cli#2198](https://github.com/github/copilot-cli/issues/2198):
  `.mcp.json` のワークスペースMCPサーバーが起動時にロードされず、
  `/mcp reload` を手動実行しないと反映されない（IDEロックファイル検出に依存しているため）。
- [github/copilot-cli#5447](https://github.com/github/copilot-cli/issues/5447):
  `--acp` モードは IDE ワークスペース discovery（`~/.copilot/ide` 連携）自体を
  スキップするため、ACPセッションには workspace MCP コンテキストが渡らない。

実際に `/mcp reload` を Zed の Agent Mode 内で試したが効果なし（ACPモードでは
workspace discovery の経路自体が無いため、reload対象が見つからない）。

**現状の回避策:**
- obsidian など project-level MCP が必要な作業は、Zedを使わずターミナルで
  素の `copilot` コマンドを直接起動する。
- Zed内で作業を続けたい場合、該当情報は手動で共有する（コピペ等）。
- upstream（`github/copilot-cli`）の修正を待つ。

## 検証環境

- Zed設定: `~/.config/zed/settings.json` の `agent_servers.github-copilot-cli`
  (`type: "registry"`)
- 実バイナリ: `~/Library/Application Support/Zed/external_agents/registry/npx/github-copilot-cli/node_modules/@github/copilot-darwin-arm64/copilot --acp`
- ログ: `~/.copilot/logs/process-*.log`（MCP関連の記録が無いことを確認して切り分けた）
