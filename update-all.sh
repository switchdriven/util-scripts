#!/usr/bin/env bash

set -euo pipefail

BREW_CMD="/opt/homebrew/bin/brew"
NPM_CMD="/opt/homebrew/bin/npm"
MAS_CMD="/opt/homebrew/bin/mas"
UV_MAINT_CMD="$HOME/Scripts/Ruby/uv-maint.rb"
UV_TOOL_MAINT_CMD="$HOME/Scripts/Ruby/uv-tool-maint.rb"

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
echo ""
echo "=== uv (global venv) ==="
if ask_upgrade_uv "uv" "$UV_MAINT_CMD" "All packages are up to date."; then
    $UV_MAINT_CMD -u
fi

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

# --- Apple Container ---
# https://github.com/apple/container
echo ""
echo "=== Apple Container ==="
CONTAINER_RUNNING=$(launchctl list | grep -e 'com\.apple\.container\W' || true)
if [[ -n "$CONTAINER_RUNNING" ]]; then
    echo "[Apple Container] container が起動中です"
    read -r -p "[Apple Container] 停止してアップデートしますか？ [y/N]: " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        container system stop
        /usr/local/bin/update-container.sh
        container system start
    else
        echo "[Apple Container] スキップしました"
    fi
else
    /usr/local/bin/update-container.sh
    container system start
fi
