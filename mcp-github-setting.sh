#!/bin/sh
#
# GitHub MCP Server が必要な API Token をキーチェーンに登録するためのスクリプト
#
# API Token 本体は 1password で管理しているが、直接ラッパースクリプト (mcp-github.sh) から
# 1password cliを呼ぶと不幸が起こる可能性が高いので、一旦、キーチェーン格納する。

echo "Getting keys from 1password"

GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHub For MCP/token")
GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")

echo "Delete current keys"
security delete-generic-password -s "github-personal-token" > /dev/null 2>&1
security delete-generic-password -s "github-work-token" > /dev/null 2>&1

echo "Setting token to keychain"
# 個人用 GitHub トークン
security add-generic-password \
  -s "github-personal-token" \
  -a "$(whoami)" \
  -w $GITHUB_PERSONAL_TOKEN

# 会社用 GitHub Enterprise トークン
security add-generic-password \
  -s "github-work-token" \
  -a "$(whoami)" \
  -w $GITHUB_WORK_TOKEN

# トークンの値を確認（テスト用）
TOKEN_P=$(security find-generic-password -w -s "github-personal-token")

printf "Check github-personal-token .. "

if [ $TOKEN_P != $GITHUB_PERSONAL_TOKEN ]; then
    echo "NG"
else
    echo "OK"
fi

printf "Check github-work-token .. "

TOKEN_W=$(security find-generic-password -w -s "github-work-token")

if [ $TOKEN_W != $GITHUB_WORK_TOKEN ]; then
    echo "NG"
else
    echo "OK"
fi

exit 0 

