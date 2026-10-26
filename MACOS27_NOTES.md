# macOS 27 移行メモ

macOS 27.0.1 (26A434) に移行した際（2026-10-26）に見つかった挙動の変化と、このリポジトリのスクリプトへの影響をまとめる。

## 変わったこと: 一般ユーザーからネットワーク情報が見えなくなった

macOS 27 では、root 以外のユーザーが実行したときに、次のコマンドの出力からネットワークの低レイヤー情報が伏せられたり除かれたりする。プライバシー保護のための制限と考えられる（Apple の公式な説明は未確認）。

| コマンド | 一般ユーザーで実行したとき | 代わりの方法 |
|---|---|---|
| `arp -an` / `arp -n <host>` | エントリが1件も出ない（`-- no entry`） | `sudo arp -an` なら見える |
| `ifconfig` の `ether` | すべて `02:00:00:00:00:00` | `networksetup -getmacaddress <dev>` / `networksetup -listallhardwareports` は本物の MAC を返す |
| `ip address show`（iproute2mac） | `ifconfig` と同じく MAC が伏せられる | 同上 |
| `ndp -an` | 自分のアドレスの Linklayer Address が `2:0:0:0:0:0` | — |
| `netstat -an` | TCP・UDP ともソケットが0件 | — |

次のものは影響を受けない。

- `ping`、`route -n get default`、`netstat -rn`（ルーティングテーブル）
- `dns-sd`（mDNS の名前解決・Bonjour のサービス一覧）
- `networksetup`、`scutil`、`ipconfig getifaddr`

なお、`networksetup -listallhardwareports` に出てこない仮想インターフェース（Parallels の `bridge100` / `bridge101` など）は、一般ユーザーでは本物の MAC を取得する方法がない。

## 影響を受けたスクリプトと対応

| スクリプト | 症状 | 対応 | コミット |
|---|---|---|---|
| `check-network.rb` | L3 Connectivity（ゲートウェイ到達確認）が常に `NG (no ARP entry)` | ping に応答があれば OK とし、応答がないときだけ ARP キャッシュを確認する | `0b3ad51` |
| `check-mdns.rb -H` | `UDP :5353  NG nothing listening` | UDP 5353 の待ち受け確認をやめ、自ホスト名（`<LocalHostName>.local`）の mDNS 自己解決で判定する | `75a1662` |
| `show-ip.rb` | MAC アドレスがすべて `02:00:00:00:00:00` | MAC を `networksetup -listallhardwareports` から取得する（一覧にないものは従来どおり） | `75a1662` |

`check-network.rb -a`（arping）はもともと root で実行する前提なので、影響しない。

## 問題がなかったもの

- Homebrew Ruby 3.3.13（`arm64-darwin27`）、`~/Scripts/.venv` の Python 3.14.9 は正常に動作した。
- 全スクリプトの構文チェックと `--help` は正常。
- 読み取りだけのモードで実行して問題がなかったもの: `net-port.rb`, `show-services.rb`, `show-port.rb`, `proxy-env.rb show`, `check-proxy.rb`, `check-fxz.rb`, `check-squid.rb`, `get-ssid.sh`, `chrome-profiles.rb`, `set-mailto-app.sh`, `music-ctrl.rb status`, `time-to-go-home.rb`, `uv-maint.rb`, `uv-tool-maint.rb`, `clear-app-cache.rb`, `check-python-env.sh`, `pdf-shrink.py`, `run-claude.sh`, `run-code.sh`
- `update-all.sh` は実際に実行して確認済み。

## 同じ時期に見つかった、macOS 27 とは別の問題

macOS 27 へのアップデートではなく、Mac の新調・移行が原因のもの。

- **Ethernet のデバイス名が変わった**（`en10` → `en9`）。`check-network.rb` のデフォルトを変更した。
- **`check-network.rb` の ping に `-I` を使っていた**。macOS の `ping` では `-I` はマルチキャスト用で、`invalid multicast interface` エラーになり ping が送られていなかった。インターフェースの指定は `-b` が正しい。以前は他の通信で ARP キャッシュが埋まっていたので、OK に見えていただけだった。
- **Claude Code / Claude Desktop の設定ファイルが、シンボリックリンクから実ファイルに置き換わっていた**（`check-dotfile-links.rb` が検出）。アプリ側の新しい内容を `~/Documents/Dotfiles` に取り込み、シンボリックリンクを張り直した。
