# 社内ネットワーク障害診断スクリプト 要件まとめ

## 背景

月曜日の朝に社内ネットワークの調子がおかしくなることがある。
症状例：有線LANはリンクアップしているが DNS が引けない、など。

状況を素早く把握するため、`check-network.rb` を作成した。

## ネットワーク環境

| 項目 | 内容 |
|------|------|
| 有線LAN | en10（メイン） |
| WiFi | en0（サブ） |
| DNS | DHCP で配布 |
| Proxy | WPAD (`http://wpad.iiji.jp/proxy.pac`) で自動設定 |
| Proxy サーバー | `proxy.iiji.jp:8080`（DNS ラウンドロビン → proxy-w / proxy-e の2台） |

## チェック項目

### Interface
- 指定インターフェース（デフォルト: en10）の `status: active` 確認
- IP アドレスの取得確認

### L3 Connectivity
- デフォルトゲートウェイへの到達性
  - 通常: ping でARP解決させてから ARP キャッシュの MAC アドレスを確認
  - `--arping` オプション時: `arping` コマンドで直接ARP疎通確認（要 root）
  - **ping(ICMP) は使わない**：ゲートウェイがICMPをブロックしているため

### DNS
- DHCP で配布されたDNSサーバーへの疎通確認
  - **ping は使わない**：DNSサーバーがICMPをブロックしているため
  - `dig` で実際にDNSクエリを投げて `NOERROR` が返るか確認
- `www.google.com` の名前解決確認（Ruby `Resolv` 使用）

### Proxy
- WPAD PAC ファイルの取得（`http://wpad.iiji.jp/proxy.pac`）
- PAC ファイルから `PROXY host:port` を簡易パース
- 取得したProxyサーバーへのTCP接続確認

### Web Connectivity
| 対象 | URL | Proxy |
|------|-----|-------|
| 社内サービス（Proxy不使用） | `https://ldap-help.iiji.jp/` | なし |
| 社内サービス（Proxy経由） | `https://cf.iij-group.jp/` | あり |
| 社外 | `https://www.google.com/` | あり |

## 出力形式

テストプログラム風に、チェック項目ごとに OK/NG を表示する。

```
Network Diagnostic  [interface: en10]
============================================================

## Interface
  en10 is up                                             OK (IP: 10.x.x.x)

## L3 Connectivity
  Default gateway 10.x.x.x reachable (ARP)              OK (MAC: xx:xx:xx:xx:xx:xx)

## DNS
  DNS server 10.x.x.x answers query                     OK
  Name resolution  www.google.com                        OK (x.x.x.x)

## Proxy
  WPAD PAC accessible                                    OK (http://wpad.iiji.jp/proxy.pac)
  Proxy proxy.iiji.jp:8080 reachable (TCP)               OK

## Web Connectivity
  ldap-help.iiji.jp  (社内・Proxy不使用)                       OK (HTTP 302)
  cf.iij-group.jp    (社内・Proxy経由)                        OK (HTTP 302)
  www.google.com     (社外・Proxy経由)                        OK (HTTP 200)

============================================================
Result: 9/9 passed
```

## 実装メモ

### ゲートウェイ到達性の確認方法

ゲートウェイ（`10.206.104.x`）と自端末（`10.206.105.x`）は異なる /24 に見えるが、
実際には同一 L2 セグメント（より大きなサブネット）に存在する。
ゲートウェイは ICMP をブロックするが ARP には応答する。

- ping + ARP キャッシュ方式（sudo 不要）
  1. `ping -c 1 -t 2 -I <iface> <gw>` でARP解決を促す（ICMP応答は不要）
  2. `arp -n <gw>` でMACアドレスを確認 → あれば到達性あり
- arping 方式（`--arping` オプション、sudo 必要）
  - BSD arping（Homebrew）の出力: `60 bytes from xx:xx:xx:xx:xx:xx (IP): index=0 ...`
  - `arping -c 1 -w 2 -I <iface> <host>`

### Proxy の東西構成

`proxy.iiji.jp` は DNS ラウンドロビンで以下2台に分散している：
- `proxy-w.iiji.jp:8080`（西）
- `proxy-e.iiji.jp:8080`（東）

DNS クエリからバランス状態は判断できない（DNS はヘルスチェックを持たない）ため、
個別に直接接続して確認する必要がある。→ `check-proxy.rb --office` で対応。

## 関連スクリプト

| スクリプト | 用途 |
|-----------|------|
| `check-network.rb` | ネットワーク全体の診断（本スクリプト） |
| `check-proxy.rb --office` | 社内Proxy（東西）の個別疎通確認 |
