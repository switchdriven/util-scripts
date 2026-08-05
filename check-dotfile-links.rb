#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

# check-dotfile-links.rb
# Claude Code / Claude Desktop の設定ファイルについて、
# ~/Documents/Dotfiles との symlink 運用が壊れていないかチェックし、
# 壊れていれば修復する（内容が同一の場合のみ自動修復）。
#
# 運用の前提:
#   各設定ファイルは「実体（source）」と「symlink（link）」のペアで管理する。
#   全ペアとも Dotfiles 側が実体・アプリ側が symlink（Dotfiles に置くことで
#   iCloud Drive 経由の自動バックアップを受けられるようにするため）。
#
#   Claude Desktop の claude_desktop_config.json はアプリがアトミック保存
#   （一時ファイル書き込み→rename）を行うため、アプリ側の symlink は保存の
#   たびに実ファイルへ置き換わって「壊れる」ことがある。これは想定内の挙動として
#   本スクリプトで検出・修復する（他の2ペアも同様の仕組みで壊れうる）。
#
# 「壊れる」とは: link の場所に symlink ではなく実体ファイルが新規作成されている状態。
# 安全設計:
#   - デフォルトはドライラン（チェック・レポートのみ）。修復するには --execute が必須。
#   - 自動修復するのは「link 側の実体ファイルの内容が source と完全一致する場合」のみ。
#     内容が異なる場合は警告を出して手を止める（上書き・削除は絶対にしない）。
#   - 自動修復の実処理は「link 側の実体ファイルを削除 → source への symlink を新規作成」。
#     内容一致を確認済みなのでデータは失われないが、link 側にあった実ファイルという
#     形では残らない（symlink 経由で同じ内容が見える形になる）。
#   - source（Dotfiles 側）は、このスクリプトではどのケースでも一切書き換えない。
#     常に「source が正、link 側をそれに合わせる」一方向の修復であり、
#     source → link 方向で上書きされることはない。
#   - symlink が指すターゲットが期待と違う/切れている場合も自動修復はしない（要確認のため報告のみ）。

require "optparse"
require "fileutils"
require "open3"

begin
  require "colorize"
rescue LoadError
  String.class_eval do
    def green = self
    def yellow = self
    def red = self
    def bold = self
    def cyan = self
  end
end

DOTFILES = File.expand_path("~/Documents/Dotfiles")

# name: 表示用ラベル
# source: 実体ファイルの場所（コピー元の正）
# link: symlink を張る場所（source を指す）
TARGETS = [
  {
    name: "Claude Code 設定 (settings.json)",
    source: File.join(DOTFILES, "claude_setting.json"),
    link: File.expand_path("~/.claude/settings.json")
  },
  {
    name: "Claude Code CLAUDE.md",
    source: File.join(DOTFILES, "CLAUDE.md"),
    link: File.expand_path("~/.claude/CLAUDE.md")
  },
  {
    name: "Claude Desktop 設定 (claude_desktop_config.json)",
    source: File.join(DOTFILES, "claude_desktop_config.json"),
    link: File.expand_path("~/Library/Application Support/Claude/claude_desktop_config.json")
  }
].freeze

def print_info(msg) = puts "[INFO] #{msg}".green
def print_warn(msg) = puts "[WARN] #{msg}".yellow
def print_error(msg) = puts "[ERROR] #{msg}".red

# ターゲット1件の状態を判定する。
#   :ok             - symlink が source を正しく指している
#   :missing_link   - link が存在せず、source は存在する（安全に作成可能）
#   :missing_both   - link も source も存在しない（未セットアップ、対象外アプリなど）
#   :broken_symlink - link は symlink だが指す先が存在しない
#   :wrong_target   - link は symlink だが source 以外を指している
#   :source_missing - link は実体ファイルだが source が存在しない（要手動確認）
#   :replaced_same  - link が実体ファイルに置き換わっており、内容は source と同一（自動修復対象）
#   :replaced_diff  - link が実体ファイルに置き換わっており、内容が source と異なる（要手動確認）
def target_status(source, link)
  link_is_symlink = File.symlink?(link)

  if !link_is_symlink && !File.exist?(link)
    return File.exist?(source) ? :missing_link : :missing_both
  end

  if link_is_symlink
    raw_target = File.readlink(link)
    resolved_target = File.expand_path(raw_target, File.dirname(link))
    return :wrong_target if resolved_target != File.expand_path(source)

    return File.exist?(link) ? :ok : :broken_symlink
  end

  # link は symlink ではない = 実体ファイル/ディレクトリが新規にできている
  return :source_missing unless File.exist?(source)
  return :source_missing if File.directory?(link) != File.directory?(source)

  FileUtils.compare_file(link, source) ? :replaced_same : :replaced_diff
end

def repair!(target, status, execute:, yes:)
  name, source, link = target.values_at(:name, :source, :link)

  case status
  when :missing_link
    print_info "#{name}: symlink 作成 #{link} -> #{source}"
    return unless execute

    File.symlink(source, link)
    print_info "  作成しました。"
  when :replaced_same
    print_info "#{name}: 内容一致のため修復 (#{link} を削除して symlink 化)"
    return unless execute

    unless yes
      print "  #{link} を削除して #{source} への symlink に置き換えます。よろしいですか? [y/N]: "
      answer = $stdin.gets&.strip&.downcase
      unless answer == "y" || answer == "yes"
        print_warn "  スキップしました。"
        return
      end
    end

    FileUtils.rm_f(link)
    File.symlink(source, link)
    print_info "  修復しました。"
  end
end

def show_diff_hint(source, link)
  source_stat = File.stat(source)
  link_stat = File.stat(link)
  puts "    source: #{source} (#{source_stat.size}B, #{source_stat.mtime})"
  puts "    link  : #{link} (#{link_stat.size}B, #{link_stat.mtime})"

  diff_out, = Open3.capture2("diff", "-u", source, link)
  return if diff_out.empty?

  puts "    --- diff (source vs link) ---"
  diff_out.each_line.first(20).each { |l| puts "    #{l}" }
  puts "    ... (省略)" if diff_out.lines.size > 20
rescue StandardError => e
  print_warn "  diff 表示に失敗しました: #{e.message}"
end

options = { execute: false, yes: false }

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [OPTIONS]"
  opts.separator ""
  opts.separator "Claude Code / Claude Desktop の設定ファイルについて、#{DOTFILES} との"
  opts.separator "symlink 運用が壊れていないかチェックし、壊れていれば修復するツール。"
  opts.separator "デフォルトはドライラン（チェック・レポートのみ）。"
  opts.separator ""
  opts.separator "自動修復するのは「symlink が実体ファイルに置き換わっており、"
  opts.separator "内容が source と完全一致する場合」のみ。この場合、link 側のファイルを"
  opts.separator "削除して source への symlink を張り直す（内容一致確認済みのためデータ消失なし）。"
  opts.separator "内容が異なる場合は警告して停止し、ファイルには一切手を触れない。"
  opts.separator "source（Dotfiles側）は、どのケースでも一切書き換えない。常に source が正、"
  opts.separator "link 側をそれに合わせる一方向の修復。"
  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end

  opts.on("--execute", "実際に修復を実行する (省略時はチェックのみ)") do
    options[:execute] = true
  end

  opts.on("--yes", "修復前の確認プロンプトをスキップ (--execute と併用)") do
    options[:yes] = true
  end

  opts.separator ""
  opts.separator "EXAMPLES:"
  opts.separator "  #{File.basename($0)}                # 状態を一覧表示（何も変更しない）"
  opts.separator "  #{File.basename($0)} --execute       # 確認プロンプトの上で修復"
  opts.separator "  #{File.basename($0)} --execute --yes # 確認なしで修復（自動化用）"
end

parser.parse!

unless Dir.exist?(DOTFILES)
  print_error "Dotfiles ディレクトリが見つかりません: #{DOTFILES}"
  exit 1
end

needs_attention = false
auto_fixable = []

print_info "チェック対象: #{TARGETS.size}件"
puts ""

TARGETS.each do |target|
  status = target_status(target[:source], target[:link])

  case status
  when :ok
    puts "OK   #{target[:name]}".green
  when :missing_both
    puts "SKIP #{target[:name]} (source/link ともに存在せず、未セットアップと思われます)".cyan
  when :missing_link
    puts "WARN #{target[:name]}: symlink が存在しません（source は存在）".yellow
    puts "     source: #{target[:source]}"
    puts "     link  : #{target[:link]} (なし)"
    auto_fixable << [target, status]
    needs_attention = true
  when :broken_symlink
    puts "WARN #{target[:name]}: symlink は存在しますが指す先が見つかりません（要手動確認）".yellow
    puts "     link: #{target[:link]} -> #{File.readlink(target[:link])} (存在しません)"
    needs_attention = true
  when :wrong_target
    puts "WARN #{target[:name]}: symlink が想定外のターゲットを指しています（要手動確認）".yellow
    puts "     期待: #{target[:link]} -> #{target[:source]}"
    puts "     実際: #{target[:link]} -> #{File.readlink(target[:link])}"
    needs_attention = true
  when :source_missing
    puts "WARN #{target[:name]}: link は実体ファイルですが source が存在しません（要手動確認）".yellow
    puts "     source: #{target[:source]} (なし)"
    puts "     link  : #{target[:link]}"
    needs_attention = true
  when :replaced_same
    puts "FIX  #{target[:name]}: symlink が実体ファイルに置き換わっていますが、内容は source と一致（自動修復可能）".yellow
    puts "     source: #{target[:source]}"
    puts "     link  : #{target[:link]} (実体ファイル)"
    auto_fixable << [target, status]
    needs_attention = true
  when :replaced_diff
    puts "ERROR #{target[:name]}: symlink が実体ファイルに置き換わっており、内容が source と異なります（自動修復しません）".red
    show_diff_hint(target[:source], target[:link])
    needs_attention = true
  end
  puts ""
end

if auto_fixable.empty?
  print_info "自動修復対象はありません。"
  exit(needs_attention ? 1 : 0)
end

unless options[:execute]
  print_info "#{auto_fixable.size}件が自動修復可能です。修復するには --execute を指定してください。"
  exit 1
end

auto_fixable.each do |target, status|
  repair!(target, status, execute: options[:execute], yes: options[:yes])
end

exit(needs_attention ? 1 : 0)
