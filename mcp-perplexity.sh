#!/bin/bash

# Perplexity MCP サーバーラッパー
# Keychain から API キーを取得して MCP サーバーを起動

API_KEY=$(security find-generic-password -w -s "perplexity-token")

if [ -z "$API_KEY" ]; then
    echo "Error: Perplexity API key not found in Keychain" >&2
    echo "Please run: mcp-keychain-setting.sh" >&2
    exit 1
fi

# Perplexity API キーを環境変数で渡して MCP サーバーを起動
export PERPLEXITY_API_KEY="$API_KEY"
exec perplexity-mcp "$@"
