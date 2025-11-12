#!/bin/sh
#
# GitHub MCP Server のラッパースクリプト
#
# 直接呼ぶと claude_desktop_config.json にAPI Tokenを書かないといけないのでラッパースクリプトにした
# API Token 自体はキーチェーンから取得する設計
# キーチェーンへのAPI Token設定は mcp-github-setting.sh で実施する

# GitHub MCP Server のパス
GITHUB_MCP_SERVER_PATH="/Users/junya/Dev/github-mcp-server/github-mcp-server"

# 個人用 GitHub の設定
PERSONAL_KEYCHAIN_NAME="github-personal-token"

# 会社用 GitHub の設定
WORK_KEYCHAIN_NAME="github-work-token"
WORK_GITHUB_HOST="https://gh.iiji.jp"

# 使用方法チェック
if [ $# -eq 0 ]; then
  echo "Usage: $0 {personal|work}" >&2
  exit 1
fi

MODE=$1

# モードに応じて設定を切り替え
case "$MODE" in
  personal)
    KEYCHAIN_NAME=$PERSONAL_KEYCHAIN_NAME
    GITHUB_HOST=""
    ;;
  work)
    KEYCHAIN_NAME=$WORK_KEYCHAIN_NAME
    GITHUB_HOST=$WORK_GITHUB_HOST
    ;;
  *)
    echo "Error: Invalid mode '$MODE'. Use 'personal' or 'work'" >&2
    exit 1
    ;;
esac

# キーチェーンからトークンを取得
TOKEN=$(security find-generic-password -w -s "$KEYCHAIN_NAME" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "Error: Could not retrieve $KEYCHAIN_NAME from keychain" >&2
  exit 1
fi

# 環境変数を設定
export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"

# GitHub Enterprise の場合はホストも設定
if [ -n "$GITHUB_HOST" ]; then
  export GITHUB_HOST="$GITHUB_HOST"
fi

# github-mcp-server を実行（パスを実際のものに置き換えてください）
exec $GITHUB_MCP_SERVER_PATH stdio
