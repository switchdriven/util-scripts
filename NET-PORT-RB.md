# net-port.rb

macOS のネットワークポート情報を取得するユーティリティ。AppleScript からの呼び出しを想定した設計で、外部モジュール依存なしの Ruby 実装。

## 機能

- **ハードウェアポート一覧取得**: すべてのネットワークポートとデバイス名を取得
- **デバイス名取得**: ポート名からデバイス名を検索
- **接続ステータス確認**: ポートの active/inactive ステータスを取得
- **IP アドレス取得**: ポートに割り当てられた IPv4 アドレスを取得
- **SSID 取得**: Wi-Fi ポートの現在の接続 SSID を取得
- **複数出力形式**: テキスト（デフォルト）および JSON 形式に対応

## インストール

```bash
chmod +x net-port.rb
```

## コマンドラインインターフェース

### 基本的な使い方

```bash
# ハードウェアポート一覧を表示
./net-port.rb list

# ポート名からデバイス名を取得
./net-port.rb device Wi-Fi

# ポートのステータスを取得
./net-port.rb status Wi-Fi

# ポートの IPv4 アドレスを取得
./net-port.rb addr Wi-Fi

# Wi-Fi ポートの SSID を取得
./net-port.rb ssid Wi-Fi

# ヘルプを表示
./net-port.rb -h
./net-port.rb --help
```

### 出力形式の指定

```bash
# JSON 形式で出力
./net-port.rb --format json list
./net-port.rb --format json device Wi-Fi
./net-port.rb --format json ssid Wi-Fi
```

## 出力形式

### テキスト形式（デフォルト）

```bash
$ net-port.rb list
Wi-Fi:en0
Ethernet:en1
Thunderbolt Bridge:bridge0

$ net-port.rb device Wi-Fi
en0

$ net-port.rb status Wi-Fi
active

$ net-port.rb addr Wi-Fi
192.168.1.100

$ net-port.rb ssid Wi-Fi
MySSID
```

### JSON 形式

```bash
$ net-port.rb --format json list
{"ports":[{"name":"Wi-Fi","device":"en0"},{"name":"Ethernet","device":"en1"}]}

$ net-port.rb --format json device Wi-Fi
{"port":"Wi-Fi","device":"en0"}

$ net-port.rb --format json status Wi-Fi
{"port":"Wi-Fi","status":"active"}

$ net-port.rb --format json addr Wi-Fi
{"port":"Wi-Fi","addr":"192.168.1.100"}

$ net-port.rb --format json ssid Wi-Fi
{"port":"Wi-Fi","ssid":"MySSID"}
```

## AppleScript からの利用

### 基本的な例

```applescript
-- Wi-Fi の SSID を取得
set currentSSID to (do shell script "/path/to/net-port.rb ssid Wi-Fi")
display dialog "Current network: " & currentSSID

-- Wi-Fi のステータスを確認
set wifiStatus to (do shell script "/path/to/net-port.rb status Wi-Fi")
if wifiStatus is "active" then
    display notification "Wi-Fi is connected"
end if

-- Wi-Fi の IP アドレスを取得
set ipAddr to (do shell script "/path/to/net-port.rb addr Wi-Fi")
display dialog "IP Address: " & ipAddr
```

### エラーハンドリング

```applescript
-- エラーハンドリング付き呼び出し
try
    set currentSSID to (do shell script "/path/to/net-port.rb ssid Wi-Fi")
    display dialog "Connected to: " & currentSSID buttons {"OK"}
on error errMsg
    display dialog "Error: " & errMsg buttons {"OK"} with icon caution
end try
```

### JSON 出力を使用する場合

```applescript
-- JSON 出力を取得してパース
set portListJSON to (do shell script "/path/to/net-port.rb --format json list")
-- JSON パース処理（AppleScript の標準には JSON パーサがないため、
-- System Events や外部ツール（jq など）での処理が必要）
```

## 実装の詳細

### 内部関数

#### `get_device_list`
`networksetup -listallhardwareports` コマンドの出力をパースして、すべてのハードウェアポートとデバイス名のマッピングを取得します。

```ruby
get_device_list # => {"Wi-Fi" => "en0", "Ethernet" => "en1", ...}
```

#### `get_port_status(device)`
`ifconfig` コマンドで指定デバイスのステータスを取得します。

```ruby
get_port_status("en0") # => "active" or "inactive"
```

#### `get_port_addr(device)`
`ifconfig` コマンドで指定デバイスの IPv4 アドレスを取得します。

```ruby
get_port_addr("en0") # => "192.168.1.100" or nil
```

#### `get_ssid(device)`
指定デバイスの Wi-Fi SSID を取得します。以下のロジックを実装：

1. `ipconfig getifaddr` で IP アドレスを確認
2. IP アドレスが空でないことを確認
3. リンクローカルアドレス（169.254.x.x）でないことを確認
4. `networksetup -listpreferredwirelessnetworks` で優先ネットワーク一覧の先頭を SSID として取得

エラー時は STDERR にメッセージを出力し、`nil` を返します。

```ruby
get_ssid("en0") # => "MySSID" or nil
```

### キャッシング

`get_device_list` の結果はメモリ内にキャッシュされ、同一インスタンス内での複数回呼び出しの際のパフォーマンスを向上させます。

## エラーハンドリング

### テキスト形式

- **存在しないポート**: `"none"` を出力し、exit code は 0
- **接続されていないポート**: 何も出力しない（IPv4 アドレスなし）

### JSON 形式

- **存在しないポート**: エラーメッセージを STDERR に出力し、exit code は 1
- **データ取得失敗**: エラーメッセージを STDERR に出力し、exit code は 1

## 外部依存

このスクリプトは Ruby の標準ライブラリのみを使用します。以下の外部コマンドに依存：

- `networksetup` - ネットワーク設定情報の取得（システム標準）
- `ifconfig` - ネットワークインターフェース設定の確認（システム標準）
- `sed` - テキスト処理（システム標準、SSID 取得時のみ）

外部 Ruby ライブラリは不要です。

## テスト例

```bash
# 基本的なテスト
./net-port.rb list
./net-port.rb device Wi-Fi
./net-port.rb status Wi-Fi
./net-port.rb addr Wi-Fi
./net-port.rb ssid Wi-Fi

# JSON 出力テスト
./net-port.rb --format json list
./net-port.rb --format json device Wi-Fi

# エラーハンドリングテスト
./net-port.rb device NonExistent          # => "none" (exit code 0)
./net-port.rb --format json device NonExistent  # => error (exit code 1)
```

## トラブルシューティング

### SSID が取得できない場合

1. Wi-Fi が接続されているか確認
   ```bash
   ./net-port.rb status Wi-Fi
   ```

2. IP アドレスが割り当てられているか確認
   ```bash
   ./net-port.rb addr Wi-Fi
   ```

3. `ipconfig` コマンドを直接実行して確認
   ```bash
   ipconfig getifaddr en0
   ```

### ポートが見つからない場合

1. 利用可能なポートを確認
   ```bash
   ./net-port.rb list
   ```

2. デバイス名が正確かどうか確認（例：`Wi-Fi` は大文字小文字を区別）

## 実行例（AppleScript）

`test-net-port-applescript.applescript` を参照してください。このファイルには以下の AppleScript 関数の実装例が含まれています：

- `getWiFiSSID()` - Wi-Fi SSID を取得
- `getWiFiDevice()` - Wi-Fi デバイス名を取得
- `getWiFiStatus()` - Wi-Fi ステータスを取得
- `getWiFiAddr()` - Wi-Fi IP アドレスを取得
- `getPortListJSON()` - ポート情報を JSON で取得

## ライセンス

このスクリプトは `util-scripts` リポジトリの一部です。
