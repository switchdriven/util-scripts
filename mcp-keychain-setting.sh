#!/bin/sh
#
# MCP サーバーが必要な API Token をキーチェーンに登録するためのスクリプト
#
# API Token 本体は 1password で管理しているが、直接ラッパースクリプトから
# 1password CLI を呼ぶと不幸が起こる可能性が高いので、一旦、キーチェーンに格納する。
#
# 対応サービス:
#   - GitHub (個人用・会社用)
#   - Perplexity

echo "Getting keys from 1password"

# GitHub トークン
GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHub For MCP/token")
GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")

# Perplexity API キー
PERPLEXITY_API_KEY=$(op read "op://Personal/Perplexity API/credential")

echo "Delete current keys"
security delete-generic-password -s "github-personal-token" > /dev/null 2>&1
security delete-generic-password -s "github-work-token" > /dev/null 2>&1
security delete-generic-password -s "perplexity-token" > /dev/null 2>&1

echo "Setting tokens to keychain"

# 個人用 GitHub トークン
security add-generic-password \
  -s "github-personal-token" \
  -a "$(whoami)" \
  -w "$GITHUB_PERSONAL_TOKEN"

# 会社用 GitHub Enterprise トークン
security add-generic-password \
  -s "github-work-token" \
  -a "$(whoami)" \
  -w "$GITHUB_WORK_TOKEN"

# Perplexity API キー
security add-generic-password \
  -s "perplexity-token" \
  -a "$(whoami)" \
  -w "$PERPLEXITY_API_KEY"

echo "Verifying tokens"

TOKEN_P=$(security find-generic-password -w -s "github-personal-token")
printf "Check github-personal-token .. "
if [ "$TOKEN_P" != "$GITHUB_PERSONAL_TOKEN" ]; then
    echo "NG"
    exit 1
else
    echo "OK"
fi

TOKEN_W=$(security find-generic-password -w -s "github-work-token")
printf "Check github-work-token .. "
if [ "$TOKEN_W" != "$GITHUB_WORK_TOKEN" ]; then
    echo "NG"
    exit 1
else
    echo "OK"
fi

TOKEN_PERPLEXITY=$(security find-generic-password -w -s "perplexity-token")
printf "Check perplexity-token .. "
if [ "$TOKEN_PERPLEXITY" != "$PERPLEXITY_API_KEY" ]; then
    echo "NG"
    exit 1
else
    echo "OK"
fi

exit 0 

