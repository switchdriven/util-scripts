#!/bin/bash
#
# Apple がプライバシー保護のために SSID 情報を引き出しづらくしている対応のスクリプト
#
# 動作原理は次のとおり
# - インターフェース(ディフォルトは en0)に IP Address が振られているかチェック
# - そのアドレスが自己解決アドレスではない
# - ショートカット「GetSSID」を実行し、クリップボード経由で現在の SSID を取得する
#   （副作用: 実行中にクリップボードの内容が上書きされる）

# コマンドのフルパス
IPCONFIG=/usr/sbin/ipconfig
SHORTCUTS=/usr/bin/shortcuts
PBPASTE=/usr/bin/pbpaste

# インターフェース（デフォルト: en0）
IFACE=${1:-en0}

# 指定インターフェースのIPアドレスを確認
ip_addr=$($IPCONFIG getifaddr "$IFACE" 2>/dev/null)

# 未取得チェック
if [[ -z "$ip_addr" ]]; then
    echo "Wi-Fi not connected ($IFACE)"
    exit 1
fi

# 自己割り当てアドレス（リンクローカル）チェック
if [[ "$ip_addr" =~ ^169\.254\. ]]; then
    echo "Wi-Fi connection error - DHCP failed ($IFACE)"
    exit 1
fi

# ショートカットを使って SSID を取得（クリップボード経由）
if ! $SHORTCUTS run GetSSID >/dev/null 2>&1; then
    echo "Failed to run GetSSID shortcut ($IFACE)"
    exit 1
fi
ssid=$($PBPASTE)

if [[ -n "$ssid" ]]; then
    echo "$ssid"
else
    echo "Failed to get SSID ($IFACE)"
    exit 1
fi
