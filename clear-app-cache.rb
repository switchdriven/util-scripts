#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

# clear-app-cache.rb
# ~/Library/Application Support 以下を走査し、フォルダ名に "cache" を含む
# ディレクトリ（Chrome/Edge/Zed などが自動生成する再生成可能なキャッシュ）を
# 検出・削除するツール。
#
# 安全設計:
#   - フォルダ名に "cache" を含むディレクトリのみを対象にする（命名規則ベース）。
#     Local Storage / IndexedDB / vm_bundles のような実データは自然に対象外になる。
#   - HARD_EXCLUDE に含むトップレベルフォルダ（例: MobileSync = iPhoneバックアップ）は
#     オプションでも解除できない絶対除外。
#   - デフォルトはドライラン。削除するには --execute が必須。
#   - --execute 実行時も一覧と合計サイズを表示し、--yes がない限り確認を求める。

require "optparse"
require "fileutils"

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

DEFAULT_ROOT = File.expand_path("~/Library/Application Support")
DEFAULT_THRESHOLD_GB = 5.0
DEFAULT_MIN_SIZE_MB = 1024.0
CACHE_NAME_PATTERN = /cache/i

# 絶対に対象にしないトップレベルフォルダ（--exclude では解除不可）
HARD_EXCLUDE = [
  "MobileSync" # iPhone/iPadバックアップ
].freeze

# トップレベルフォルダ名 -> 起動確認に使う pgrep -f パターン
# 実行中に削除するとキャッシュ書き込みと競合する可能性があるため、
# 判明しているものだけ事前に警告する（未掲載のアプリはチェックしない）。
PROCESS_HINTS = {
  "Google" => ["Google Chrome"],
  "Microsoft Edge" => ["Microsoft Edge"],
  "Zed" => ["Zed"],
  "Claude" => ["Claude"],
  "Slack" => ["Slack"],
  "obsidian" => ["Obsidian"],
  "1Password" => ["1Password"],
  "Code" => ["Visual Studio Code"],
  "Microsoft" => ["Microsoft Teams"]
}.freeze

def running_app?(pattern)
  system("pgrep", "-f", pattern, out: File::NULL, err: File::NULL)
end

def running_tops(tops)
  tops.select { |top| PROCESS_HINTS[top]&.any? { |pattern| running_app?(pattern) } }
end

def print_info(msg) = puts "[INFO] #{msg}".green
def print_warn(msg) = puts "[WARN] #{msg}".yellow
def print_error(msg) = puts "[ERROR] #{msg}".red

def human(bytes)
  units = %w[B KB MB GB TB]
  size = bytes.to_f
  idx = 0
  while size >= 1024 && idx < units.size - 1
    size /= 1024
    idx += 1
  end
  format("%.1f%s", size, units[idx])
end

def dir_size_bytes(path)
  out = `du -sk "#{path}" 2>/dev/null`.split.first
  out ? out.to_i * 1024 : 0
end

# TCC で保護された一部のパス（例: com.apple.LaunchServicesTemplateApp.dv）は
# lstat すら EPERM になることがあるため、Find.find ではなく自前の再帰にして
# エントリ単位で権限エラーを無視できるようにする。
def scan_cache_dirs(root, exclude_names, only_names, pattern)
  candidates = []
  stack = [root]

  until stack.empty?
    dir = stack.pop

    begin
      entries = Dir.children(dir)
    rescue SystemCallError
      next
    end

    entries.each do |name|
      path = File.join(dir, name)

      begin
        next if File.symlink?(path)
        next unless File.directory?(path)
      rescue SystemCallError
        next
      end

      rel_top = path.sub("#{root}/", "").split("/").first
      next if exclude_names.include?(rel_top)
      next if !only_names.empty? && !only_names.include?(rel_top)

      if name.match?(pattern)
        candidates << { path: path, top: rel_top }
        next # マッチしたキャッシュフォルダの中はこれ以上潜らない
      end

      stack << path
    end
  end

  candidates
end

options = {
  root: DEFAULT_ROOT,
  threshold_gb: DEFAULT_THRESHOLD_GB,
  min_size_mb: DEFAULT_MIN_SIZE_MB,
  excludes: [],
  only: [],
  execute: false,
  yes: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [OPTIONS]"
  opts.separator ""
  opts.separator "Application Support 以下のキャッシュフォルダ（名前に \"cache\" を含むディレクトリ）を"
  opts.separator "検出し、一覧表示・削除するツール。デフォルトはドライラン（一覧表示のみ）。"
  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end

  opts.on("--root PATH", "スキャン対象ルート (デフォルト: #{DEFAULT_ROOT})") do |v|
    options[:root] = File.expand_path(v)
  end

  opts.on("--threshold GB", Float, "「大容量フォルダ」として警告表示する閾値 (デフォルト: #{DEFAULT_THRESHOLD_GB})") do |v|
    options[:threshold_gb] = v
  end

  opts.on("--min-size MB", Float, "この値未満のキャッシュフォルダは無視する (デフォルト: #{DEFAULT_MIN_SIZE_MB.to_i} = 1GB)") do |v|
    options[:min_size_mb] = v
  end

  opts.on("--exclude NAME", "追加で除外するトップレベルフォルダ名 (繰り返し指定可)") do |v|
    options[:excludes] << v
  end

  opts.on("--only NAME", "指定したトップレベルフォルダのみ対象にする (繰り返し指定可、例: --only Google --only \"Microsoft Edge\")") do |v|
    options[:only] << v
  end

  opts.on("--execute", "実際に削除を実行する (省略時は一覧表示のみ)") do
    options[:execute] = true
  end

  opts.on("--yes", "削除前の確認プロンプトをスキップ (--execute と併用)") do
    options[:yes] = true
  end

  opts.separator ""
  opts.separator "EXAMPLES:"
  opts.separator "  #{File.basename($0)}                    # 対象を一覧表示（削除しない）"
  opts.separator "  #{File.basename($0)} --execute           # 確認プロンプトの上で削除"
  opts.separator "  #{File.basename($0)} --execute --yes     # 確認なしで削除（自動化用）"
  opts.separator "  #{File.basename($0)} --exclude Zed       # Zed フォルダを除外して実行"
  opts.separator "  #{File.basename($0)} --only Google --only \"Microsoft Edge\"  # ブラウザ系だけに絞って一覧表示"
end

parser.parse!

root = options[:root]
unless Dir.exist?(root)
  print_error "指定されたルートが存在しません: #{root}"
  exit 1
end

exclude_names = (HARD_EXCLUDE + options[:excludes]).uniq

# --- 1. 大容量フォルダ（閾値以上）を報告 ---------------------------------

print_info "#{root} を走査中..."
puts ""

top_level_dirs = Dir.children(root).select { |name| File.directory?(File.join(root, name)) }.sort

big_dirs = top_level_dirs.filter_map do |name|
  bytes = dir_size_bytes(File.join(root, name))
  gb = bytes / (1024.0**3)
  next unless gb >= options[:threshold_gb]

  [name, bytes]
end.sort_by { |(_, bytes)| -bytes }

puts "大容量フォルダ (#{options[:threshold_gb]}GB以上):".bold
if big_dirs.empty?
  puts "  該当なし"
else
  big_dirs.each do |name, bytes|
    note = HARD_EXCLUDE.include?(name) ? "  (※対象外: キャッシュではないため触りません)".yellow : ""
    puts format("  %8s  %s%s", human(bytes), name, note)
  end
end
puts ""

# --- 2. キャッシュ候補フォルダを検出 --------------------------------------

candidates = scan_cache_dirs(root, exclude_names, options[:only], CACHE_NAME_PATTERN)
candidates.each { |c| c[:bytes] = dir_size_bytes(c[:path]) }
candidates.reject! { |c| c[:bytes] < options[:min_size_mb] * 1024 * 1024 }
candidates.sort_by! { |c| -c[:bytes] }

if candidates.empty?
  print_info "削除候補のキャッシュフォルダは見つかりませんでした。"
  exit 0
end

total_bytes = candidates.sum { |c| c[:bytes] }

puts "削除候補のキャッシュフォルダ:".bold
candidates.group_by { |c| c[:top] }.each do |top, group|
  subtotal = group.sum { |c| c[:bytes] }
  puts "  #{top}/ (#{human(subtotal)})".cyan
  group.each do |c|
    rel = c[:path].sub("#{root}/", "")
    puts format("    %8s  %s", human(c[:bytes]), rel)
  end
end
puts ""
puts "合計: #{human(total_bytes)}（#{candidates.size}件）".bold
puts ""

running = running_tops(candidates.map { |c| c[:top] }.uniq)
unless running.empty?
  print_warn "以下のアプリが起動中です。キャッシュ書き込みと競合する可能性があるため、"
  print_warn "できればアプリを終了してから実行することを推奨します: #{running.join(', ')}"
  puts ""
end

# --- 3. 削除実行 ----------------------------------------------------------

unless options[:execute]
  print_info "ドライランのため削除は行っていません。削除するには --execute を指定してください。"
  exit 0
end

unless options[:yes]
  print "上記 #{candidates.size} 件・合計 #{human(total_bytes)} を削除します。よろしいですか? [y/N]: "
  answer = $stdin.gets&.strip&.downcase
  unless answer == "y" || answer == "yes"
    print_warn "キャンセルしました。"
    exit 0
  end
end

freed = 0
failed = []

candidates.each do |c|
  FileUtils.rm_rf(c[:path], secure: true)
  if Dir.exist?(c[:path])
    failed << c[:path]
  else
    freed += c[:bytes]
  end
end

puts ""
print_info "#{human(freed)} を解放しました。"
unless failed.empty?
  print_error "削除できなかったフォルダ (#{failed.size}件):"
  failed.each { |p| puts "  #{p}" }
  exit 1
end
