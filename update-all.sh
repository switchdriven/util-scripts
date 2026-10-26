#!/usr/bin/env bash

set -euo pipefail

BREW_CMD="/opt/homebrew/bin/brew"
NPM_CMD="/opt/homebrew/bin/npm"
MAS_CMD="/opt/homebrew/bin/mas"
JQ_CMD="/opt/homebrew/bin/jq"
UV_MAINT_CMD="$HOME/Scripts/Ruby/uv-maint.rb"
UV_TOOL_MAINT_CMD="$HOME/Scripts/Ruby/uv-tool-maint.rb"
export MAS_NO_AUTO_INDEX=1

ask_upgrade() {
    local tool="$1"
    local outdated_output="$2"
    if [[ -z "$outdated_output" ]]; then
        echo "[$tool] すべて最新です"
        return 1
    fi
    echo "$outdated_output"
    read -r -p "[$tool] アップデートしますか？ [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

ask_upgrade_uv() {
    local tool="$1"
    local cmd="$2"
    local up_to_date_marker="$3"
    local output
    output=$("$cmd")
    echo "$output"
    if echo "$output" | grep -q "$up_to_date_marker"; then
        return 1
    fi
    read -r -p "[$tool] アップデートしますか？ [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# マーケットプレイスのカタログから plugin の最新バージョンを求める。判定できなければ空文字。
# カタログの version を優先し、無ければ相対パスソースの plugin.json を見る（外部 git ソースは判定不可）。
claude_plugin_latest_version() {
    local name="$1"
    local marketplace="$2"
    local mp_dir
    mp_dir=$($JQ_CMD -r --arg m "$marketplace" '.[$m].installLocation // empty' "$HOME/.claude/plugins/known_marketplaces.json")
    [[ -n "$mp_dir" && -f "$mp_dir/.claude-plugin/marketplace.json" ]] || return 0
    local entry
    entry=$($JQ_CMD -c --arg n "$name" '.plugins[] | select(.name == $n)' "$mp_dir/.claude-plugin/marketplace.json")
    [[ -n "$entry" ]] || return 0
    local version
    version=$($JQ_CMD -r '.version // empty' <<< "$entry")
    if [[ -z "$version" ]]; then
        local src
        src=$($JQ_CMD -r '.source | if type == "string" then . else empty end' <<< "$entry")
        if [[ -n "$src" && -f "$mp_dir/$src/.claude-plugin/plugin.json" ]]; then
            version=$($JQ_CMD -r '.version // empty' "$mp_dir/$src/.claude-plugin/plugin.json")
        fi
    fi
    echo "$version"
}

# --- Homebrew ---
echo ""
echo "=== Homebrew ==="
$BREW_CMD update -v
BREW_OUTDATED=$($BREW_CMD outdated)
if ask_upgrade "Homebrew" "$BREW_OUTDATED"; then
    $BREW_CMD upgrade -y
fi

# --- npm global packages ---
echo ""
echo "=== npm (global) ==="
NPM_OUTDATED=$($NPM_CMD outdated -g --depth=0 || true)
if ask_upgrade "npm" "$NPM_OUTDATED"; then
    $NPM_CMD update -g
fi

# --- uv (global venv packages) ---
# このリポジトリのスクリプトが直接依存する環境なので、自動アップグレードは行わず確認表示のみ。
# 更新する場合は `uv-maint.rb -u` を手動で実行し、依存スクリプトの動作確認を行うこと。
echo ""
echo "=== uv (global venv) ==="
$UV_MAINT_CMD

# --- uv tool (global tools) ---
echo ""
echo "=== uv tool (global) ==="
if ask_upgrade_uv "uv tool" "$UV_TOOL_MAINT_CMD" "All tools are up to date."; then
    $UV_TOOL_MAINT_CMD -u
fi

# --- App Store (mas) ---
echo ""
echo "=== App Store ==="
MAS_OUTDATED=$($MAS_CMD outdated)
if ask_upgrade "mas" "$MAS_OUTDATED"; then
    $MAS_CMD upgrade
fi

# --- Claud Code ---
echo ""
echo "=== Claude Code ==="
claude update

# --- Claude Code plugins ---
# `claude plugin` には outdated 相当のコマンドが無いため、マーケットプレイスを更新した上で
# カタログ上の最新バージョンとインストール済みバージョンを比較し、差分があるものだけ update にかける。
# 最新バージョンを判定できない（外部 git ソース等）ものは更新候補に含める。
# project/local スコープはカレントディレクトリ依存なので対象外。
echo ""
echo "=== Claude Code plugins ==="
# 社内 GHE のマーケットプレイスは VPN 未接続時などに取得できないため、失敗しても続行する
claude plugin marketplace update || echo "[Claude plugins] 一部のマーケットプレイスを更新できませんでした（キャッシュ済みのカタログで続行）"
CLAUDE_PLUGINS=""
while IFS=$'\t' read -r plugin_id installed_version; do
    [[ -n "$plugin_id" ]] || continue
    latest_version=$(claude_plugin_latest_version "${plugin_id%@*}" "${plugin_id##*@}")
    if [[ "$latest_version" == "$installed_version" ]]; then
        continue
    fi
    CLAUDE_PLUGINS+="${plugin_id}"$'\t'"${installed_version} -> ${latest_version:-?(不明)}"$'\n'
done < <(claude plugin list --json | $JQ_CMD -r '.[] | select(.scope == "user") | "\(.id)\t\(.version)"')
CLAUDE_PLUGINS="${CLAUDE_PLUGINS%$'\n'}"
if ask_upgrade "Claude plugins" "$CLAUDE_PLUGINS"; then
    while IFS=$'\t' read -r plugin_id _; do
        claude plugin update --scope user "$plugin_id" </dev/null || echo "[Claude plugins] $plugin_id の更新に失敗しました"
    done <<< "$CLAUDE_PLUGINS"
fi

# --- Apple Container ---
# https://github.com/apple/container
# brew版に移行済み。バイナリ自体の更新は上記の Homebrew セクションで行われるため、
# ここでは起動中の apiserver が CLI（brew でインストール済みのバージョン）より古い場合のみ、
# 再起動して新しいバージョンを反映する。
echo ""
echo "=== Apple Container ==="
CONTAINER_RUNNING=$(launchctl list | grep -e 'com\.apple\.container\W' || true)
if [[ -n "$CONTAINER_RUNNING" ]]; then
    CONTAINER_VERSIONS=$(container system version --format json)
    CONTAINER_CLI_VERSION=$($JQ_CMD -r '.[] | select(.appName == "container") | .version' <<< "$CONTAINER_VERSIONS")
    CONTAINER_SERVER_VERSION=$($JQ_CMD -r '.[] | select(.appName == "container-apiserver") | .version' <<< "$CONTAINER_VERSIONS")
    if [[ "$CONTAINER_CLI_VERSION" == "$CONTAINER_SERVER_VERSION" ]]; then
        echo "[Apple Container] 起動中の container は最新です ($CONTAINER_SERVER_VERSION)"
    else
        echo "[Apple Container] container が更新されています (起動中: $CONTAINER_SERVER_VERSION -> インストール済み: $CONTAINER_CLI_VERSION)"
        read -r -p "[Apple Container] 再起動しますか？ [y/N]: " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            container system stop
            container system start
        else
            echo "[Apple Container] スキップしました"
        fi
    fi
else
    container system start
fi
