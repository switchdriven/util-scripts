#!/bin/sh

# Tavily MCP サーバーラッパー
# Keychain から API キーを取得して MCP サーバーを起動

API_KEY=$(security find-generic-password -w -s "tavily-token")

if [ -z "$API_KEY" ]; then
    echo "Error: Tavily API key not found in Keychain" >&2
    echo "Please run: mcp-keychain-setting.sh" >&2
    exit 1
fi

# Tavily API キーを環境変数で渡して MCP サーバーを起動
export TAVILY_API_KEY="$API_KEY"

# Tavily MCP サーバーを起動
exec tavily-mcp "$@"

