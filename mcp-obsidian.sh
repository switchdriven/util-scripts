#!/bin/sh
#
# Obsidian MCP Server のラッパースクリプト
#
# Local REST API 5.x の内蔵MCPサーバー（Streamable HTTP）に mcp-remote 経由で接続する
# API Key はキーチェーンから取得する設計
# キーチェーンへのAPI Key設定は mcp-keychain-setting.sh で実施する
#
# 前提:
#   - Obsidian が起動しており、Local REST API プラグインが有効
#   - CA証明書を ~/.config/obsidian/obsidian-local-rest-api.crt に保存済み
#     curl -k -o ~/.config/obsidian/obsidian-local-rest-api.crt \
#       https://127.0.0.1:27124/obsidian-local-rest-api.crt

OBSIDIAN_MCP_URL="https://127.0.0.1:27124/mcp/"
OBSIDIAN_CA_CERT="$HOME/.config/obsidian/obsidian-local-rest-api.crt"
NPX="/opt/homebrew/bin/npx"

KEYCHAIN_NAME="obsidian-token"

KEY=$(security find-generic-password -w -s "$KEYCHAIN_NAME" 2>/dev/null)

if [ -z "$KEY" ]; then
  echo "Error: Could not retrieve $KEYCHAIN_NAME from keychain" >&2
  exit 1
fi

if [ ! -f "$OBSIDIAN_CA_CERT" ]; then
  echo "Error: CA certificate not found: $OBSIDIAN_CA_CERT" >&2
  exit 1
fi

# API Key を引数に載せず（ps で見えないように）環境変数経由でヘッダーに展開させる
export AUTH_HEADER="Bearer $KEY"
export NODE_EXTRA_CA_CERTS="$OBSIDIAN_CA_CERT"

exec "$NPX" -y mcp-remote@latest "$OBSIDIAN_MCP_URL" \
  --header 'Authorization:${AUTH_HEADER}'
