#!/bin/sh
#
# GitHub MCP Server (Personal) のラッパースクリプト
#
# GitHub.com 用のラッパー
# API Token はキーチェーンから取得する設計
# キーチェーンへのAPI Token設定は mcp-github-setting.sh で実施する

# GitHub MCP Server のパス
GITHUB_MCP_SERVER_PATH="/Users/junya/Dev/github-mcp-server/github-mcp-server"

# 個人用 GitHub の設定
KEYCHAIN_NAME="github-personal-token"

# キーチェーンからトークンを取得
TOKEN=$(security find-generic-password -w -s "$KEYCHAIN_NAME" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "Error: Could not retrieve $KEYCHAIN_NAME from keychain" >&2
  exit 1
fi

# 環境変数を設定
export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"

# github-mcp-server を実行
exec $GITHUB_MCP_SERVER_PATH stdio
