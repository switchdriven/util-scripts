#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# set-mailto-app.sh — mailto: UTI のデフォルトハンドラーを切り替える
#
# 使い方:
#   set-mailto-app.sh                    # 現在のデフォルトアプリを表示
#   set-mailto-app.sh mail               # Apple Mail に切り替え
#   set-mailto-app.sh spark              # Spark に切り替え
#   set-mailto-app.sh <bundle-id>        # 任意のバンドルIDを指定
# ---------------------------------------------------------------------------

BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)

usage() {
  cat <<EOF
${BOLD}使い方:${RESET}
  $(basename "$0")                    現在のデフォルトメールアプリを表示
  $(basename "$0") mail               Apple Mail (com.apple.mail) に設定
  $(basename "$0") spark              Spark (com.readdle.SparkDesktop.appstore) に設定
  $(basename "$0") <bundle-id>        任意のバンドルIDを指定して設定

${BOLD}エイリアス:${RESET}
  mail   → com.apple.mail
  spark  → com.readdle.SparkDesktop.appstore
EOF
}

resolve_bundle_id() {
  case "$1" in
    mail)  echo "com.apple.mail" ;;
    spark) echo "com.readdle.SparkDesktop.appstore" ;;
    *)     echo "$1" ;;
  esac
}

# Swift コードをヒアドキュメントで一時ファイルに書き出して実行し、後始末する
# NSWorkspace の非 deprecated API (macOS 12+) を使用
run_swift() {
  local tmp_file
  tmp_file=$(mktemp /tmp/set-mailto-app-XXXXXX)

  cat > "$tmp_file" << 'SWIFT'
import AppKit
import Foundation

let args = CommandLine.arguments

if args.count == 1 {
  // 引数なし: 現在のデフォルトハンドラーを表示
  guard let url = URL(string: "mailto:"),
        let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
    print("(未設定)")
    exit(0)
  }
  let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? appURL.deletingPathExtension().lastPathComponent
  print(bundleID)
} else {
  // 引数あり: デフォルトハンドラーを設定
  let bundleID = args[1]
  guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
    fputs("error: アプリが見つかりません: \(bundleID)\n", stderr)
    exit(1)
  }

  let sema = DispatchSemaphore(value: 0)
  var errorMsg: String? = nil

  NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "mailto") { err in
    errorMsg = err?.localizedDescription
    sema.signal()
  }
  sema.wait()

  if let msg = errorMsg {
    fputs("error: \(msg)\n", stderr)
    exit(1)
  }
  print("ok")
}
SWIFT

  local result status
  if [[ -n "${1:-}" ]]; then
    result=$(swift "$tmp_file" "$1" 2>/dev/null) && status=0 || status=$?
  else
    result=$(swift "$tmp_file" 2>/dev/null) && status=0 || status=$?
  fi

  rm -f "$tmp_file"
  echo "$result"
  return $status
}

# --- メイン処理 ---

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    current=$(run_swift)
    echo "${CYAN}現在のデフォルトメールアプリ:${RESET} ${BOLD}${current}${RESET}"
    ;;
  *)
    bundle_id=$(resolve_bundle_id "$1")
    echo "設定中: ${BOLD}${bundle_id}${RESET}"

    result=$(run_swift "$bundle_id")
    if [[ "$result" == "ok" ]]; then
      echo "${GREEN}完了${RESET}: mailto のデフォルトアプリを ${BOLD}${bundle_id}${RESET} に設定しました"
    else
      echo "${RED}失敗${RESET}: $result" >&2
      exit 1
    fi
    ;;
esac
