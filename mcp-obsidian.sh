#!/bin/sh
#
# Obsidian MCP Server のラッパースクリプト
#
# API Key はキーチェーンから取得する設計
# キーチェーンへのAPI Key設定は mcp-keychain-setting.sh で実施する

OBSIDIAN_MCP_SERVER_PATH="/Users/junya/Obsidian/.obsidian/plugins/mcp-tools/bin/mcp-server"

KEYCHAIN_NAME="obsidian-token"

KEY=$(security find-generic-password -w -s "$KEYCHAIN_NAME" 2>/dev/null)

if [ -z "$KEY" ]; then
  echo "Error: Could not retrieve $KEYCHAIN_NAME from keychain" >&2
  exit 1
fi

export OBSIDIAN_API_KEY="$KEY"

exec $OBSIDIAN_MCP_SERVER_PATH