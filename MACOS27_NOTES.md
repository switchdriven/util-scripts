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

## ログイン時に起動したアプリがアクセシビリティ権限を再要求する

ログイン項目で自動起動したアプリが、システム設定上は許可済みなのにアクセシビリティ権限を再要求することがある。BetterTouchTool、PopClip、AltTab など、権限を使う常駐アプリのほとんどで起きた。ログイン直後に TCC（`tccd`）の準備ができていないためと推測されている。Apple の公式な説明はない。起動を遅らせれば起きないという報告がある。

対応として `delayed-launch.rb` を追加した。対象アプリはログイン項目から外し、LaunchAgent からこのスクリプトを実行して、20秒待ってから順に起動する。

- 対象アプリの一覧: `~/.config/delayed-launch/apps.conf`（1行に1つ bundle ID を書く）
- 待ち時間: `--delay`（初期値 20 秒）。再要求がまだ出るときは延ばす
- ログ: `~/Library/Logs/delayed-launch.log`
- `open -g -j` で起動するので、フォーカスを奪わず、ウインドウも隠れた状態で起動する
- 待ち始めるときに通知を出す。起動に失敗したアプリがあったときは、完了時にも通知を出す（`--no-notify` で無効）。通知はスクリプトエディタから出るので、表示スタイルはシステム設定 → 通知 → スクリプトエディタ で変える
- 2026-10-30 に再起動して、待ち時間30秒で7個が起動し、権限の再要求が出ないことを確認した。その後、20秒に短縮して試している

ログイン直後に launchd から起動されると `LANG` がまだ設定されておらず、Ruby が設定ファイルを US-ASCII として読んで、日本語コメントで落ちたことがある。そのため設定ファイルは UTF-8 として明示的に読んでいる（`a0e1a30`）。

導入手順:

```bash
sed -e "s|PATH_TO_SCRIPT|$HOME/Dev/util-scripts|" -e "s|HOME_DIR|$HOME|g" \
  org.warumono.delayed-launch.plist.template > ~/Library/LaunchAgents/org.warumono.delayed-launch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/org.warumono.delayed-launch.plist
```

そのうえで、対象アプリの自動起動を止める。登録のされ方によって止める場所が違う（`sudo sfltool dumpbtm` で確認できる）。

- システム設定 → 一般 → ログイン項目 にあるもの: そこから削除する
- アプリ自身が登録しているもの（AltTab など）: アプリの設定で「ログイン時に起動」をオフにする

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
