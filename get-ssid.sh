#!/bin/bash
# 
# Apple がプライバシー保護のために SSID 情報を引き出しづらくしている対応のスクリプト
#
# 動作原理は次のとおり
# - インターフェース(ディフォルトは en0)に IP Address が振られているかチェック
# - そのアドレスが自己解決アドレスではない
# - 優先ネットワーク一覧の先頭を取得して、現在の SSID とする

# コマンドのフルパス
IPCONFIG=/usr/sbin/ipconfig
NETWORKSETUP=/usr/sbin/networksetup
SED=/usr/bin/sed

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

# 優先ネットワーク一覧の先頭を取得
ssid=$($NETWORKSETUP -listpreferredwirelessnetworks "$IFACE" 2>/dev/null \
    | $SED -n '2p' \
    | $SED 's/^[[:space:]]*//')

if [[ -n "$ssid" ]]; then
    echo "$ssid"
else
    echo "Failed to get SSID ($IFACE)"
    exit 1
fi