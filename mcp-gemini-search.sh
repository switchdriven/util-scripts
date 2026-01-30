#!/bin/bash

# Gemini Search MCP サーバーラッパー
# Keychain から API キーを取得して MCP サーバーを起動

API_KEY=$(security find-generic-password -w -s "gemini-token")
PROJECT_DIR=/Users/junya/Dev/google-search-mcp

if [ -z "$API_KEY" ]; then
    echo "Error: Gemini API key not found in Keychain" >&2
    echo "Please run: mcp-keychain-setting.sh" >&2
    exit 1
fi

# Gemini API キーを環境変数で渡して MCP サーバーを起動
export GEMINI_API_KEY="$API_KEY"

exec uv run --project $PROJECT_DIR $PROJECT_DIR/mcp_server.py "$@"
