#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

# clear-app-cache.rb
# 1. ~/Library/Application Support 以下を走査し、フォルダ名に "cache" を含む
#    ディレクトリ（Chrome/Edge/Zed などが自動生成する再生成可能なキャッシュ）を
#    検出・削除する。
# 2. Homebrew のダウンロードキャッシュ (~/Library/Caches/Homebrew) を
#    `brew cleanup --prune=all` 経由で確認・削除する。
# 3. uv のパッケージキャッシュ (~/.cache/uv) を `uv cache clean` 経由で確認・削除する。
#
# 安全設計:
#   - フォルダ名に "cache" を含むディレクトリのみを対象にする（命名規則ベース）。
#     Local Storage / IndexedDB / vm_bundles のような実データは自然に対象外になる。
#   - HARD_EXCLUDE に含むトップレベルフォルダ（例: MobileSync = iPhoneバックアップ）は
#     オプションでも解除できない絶対除外。
#   - Homebrew / uv のキャッシュは自前で rm -rf せず、必ず各ツールのキャッシュ削除
#     コマンド（`brew cleanup` / `uv cache clean`）に判断を委ねる
#     （何が不要かは各ツール自身が一番正確に把握しているため）。
#   - uv キャッシュは他プロセスがロックを保持していると `uv cache clean` がタイムアウト
#     まで無反応でブロックするため、実行前に lsof でロック保持プロセスを検出し、
#     いる場合は呼び出さずにスキップして kill コマンド例を案内する。
#   - デフォルトはドライラン。削除するには --execute が必須。
#   - --execute 実行時も一覧と合計サイズを表示し、--yes がない限り確認を求める。
#   - --skip-app-support / --skip-homebrew / --skip-uv で各セクションを個別に無効化できる。

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

def confirm?(prompt)
  print "#{prompt} [y/N]: "
  answer = $stdin.gets&.strip&.downcase
  answer == "y" || answer == "yes"
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

# --- Application Support セクション ----------------------------------------

def app_support_section(options)
  root = options[:root]
  unless Dir.exist?(root)
    print_error "指定されたルートが存在しません: #{root}"
    return false
  end

  exclude_names = (HARD_EXCLUDE + options[:excludes]).uniq

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

  candidates = scan_cache_dirs(root, exclude_names, options[:only], CACHE_NAME_PATTERN)
  candidates.each { |c| c[:bytes] = dir_size_bytes(c[:path]) }
  candidates.reject! { |c| c[:bytes] < options[:min_size_mb] * 1024 * 1024 }
  candidates.sort_by! { |c| -c[:bytes] }

  if candidates.empty?
    print_info "Application Support: 削除候補のキャッシュフォルダは見つかりませんでした。"
    puts ""
    return true
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

  unless options[:execute]
    print_info "ドライランのため削除は行っていません。削除するには --execute を指定してください。"
    puts ""
    return true
  end

  unless options[:yes]
    unless confirm?("上記 #{candidates.size} 件・合計 #{human(total_bytes)} を削除します。よろしいですか?")
      print_warn "キャンセルしました。"
      puts ""
      return true
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
    puts ""
    return false
  end

  puts ""
  true
end

# --- Homebrew セクション -----------------------------------------------------

def brew_available?
  system("brew", "--version", out: File::NULL, err: File::NULL)
end

def run_brew_cleanup(dry_run:)
  cmd = ["brew", "cleanup", "--prune=all"]
  cmd << "-n" if dry_run
  Open3.capture2e(*cmd)
end

def extract_would_free(output)
  line = output.lines.find { |l| l.include?("would free approximately") }
  line&.[](/approximately\s+([\d.]+\w+)/, 1)
end

def homebrew_section(options)
  print_info "Homebrew キャッシュ (brew cleanup --prune=all) を確認中..."
  puts ""

  unless brew_available?
    print_warn "brew コマンドが見つからないため、Homebrew キャッシュの確認をスキップします。"
    puts ""
    return true
  end

  dry_output, dry_status = run_brew_cleanup(dry_run: true)
  unless dry_status.success?
    print_error "brew cleanup のドライラン実行に失敗しました:"
    puts dry_output
    return false
  end

  entries = dry_output.lines.select { |l| l.start_with?("Would remove:") }

  if entries.empty?
    print_info "Homebrew: 削除候補のキャッシュはありませんでした。"
    puts ""
    return true
  end

  freed_estimate = extract_would_free(dry_output) || "不明"

  puts "Homebrew 削除候補:".bold
  entries.each do |line|
    detail = line.sub("Would remove: ", "").strip.sub(Dir.home, "~")
    puts "  #{detail}"
  end
  puts ""
  puts "解放見込み: #{freed_estimate}（#{entries.size}件）".bold
  puts ""

  unless options[:execute]
    print_info "ドライランのため Homebrew キャッシュの削除は行っていません。削除するには --execute を指定してください。"
    puts ""
    return true
  end

  unless options[:yes]
    unless confirm?("Homebrew キャッシュ #{entries.size} 件（解放見込み #{freed_estimate}）を削除します。よろしいですか?")
      print_warn "Homebrew キャッシュの削除をキャンセルしました。"
      puts ""
      return true
    end
  end

  real_output, real_status = run_brew_cleanup(dry_run: false)
  puts real_output
  puts ""

  if real_status.success?
    print_info "Homebrew キャッシュの削除が完了しました。"
    true
  else
    print_error "brew cleanup の実行に失敗しました。"
    false
  end
end

# --- uv セクション -----------------------------------------------------------

UV_CACHE_DIR = File.expand_path("~/.cache/uv")
UV_LOCK_FILE = File.join(UV_CACHE_DIR, ".lock")

def uv_available?
  system("uv", "--version", out: File::NULL, err: File::NULL)
end

def parent_pid(pid)
  out = `ps -p #{pid} -o ppid= 2>/dev/null`.strip
  out.empty? ? nil : out.to_i
end

def process_command(pid)
  `ps -p #{pid} -o command= 2>/dev/null`.strip
end

# pid の祖先を辿り、/Applications 配下のアプリ本体（*.app/Contents/... を実行しているプロセス）
# が見つかればそのコマンドラインを返す。見つからなければ nil。
# (例: uv run の親を辿ると Claude Desktop 本体にたどり着く、など)
def resolve_owning_app(pid, max_depth: 10)
  current = pid
  max_depth.times do
    cmd = process_command(current)
    return cmd if cmd.include?(".app/Contents/")

    parent = parent_pid(current)
    break if parent.nil? || parent <= 1 || parent == current

    current = parent
  end
  nil
end

def app_display_name(command)
  match = command.match(%r{/Applications/([^/]+\.app)/})
  match ? match[1] : command
end

# uv cache clean は他プロセスがキャッシュを読み書き中だとロック解放待ちでブロックし、
# 最終的にタイムアウトしてエラーになる（デフォルト300秒）。ブロックしてから気づくのでは
# 遅いため、.lock を実際に開いているプロセスを lsof で事前に特定する。
def uv_lock_holders
  return [] unless File.exist?(UV_LOCK_FILE)

  pids = `lsof -t "#{UV_LOCK_FILE}" 2>/dev/null`.split("\n").map(&:to_i).uniq
  pids.filter_map do |pid|
    cmd = process_command(pid)
    next if cmd.empty? # 取得までの間にプロセスが終了した場合

    { pid: pid, command: cmd, owner: resolve_owning_app(pid) }
  end
end

def print_lock_holders(holders)
  holders.each do |h|
    puts "  PID #{h[:pid]}: #{h[:command]}"
    puts "    起動元: #{app_display_name(h[:owner])}" if h[:owner]
  end
end

def run_uv_cache_clean
  Open3.capture2e("uv", "cache", "clean")
end

def uv_section(options)
  print_info "uv キャッシュ (#{UV_CACHE_DIR}) を確認中..."
  puts ""

  unless uv_available?
    print_warn "uv コマンドが見つからないため、uv キャッシュの確認をスキップします。"
    puts ""
    return true
  end

  unless Dir.exist?(UV_CACHE_DIR)
    print_info "uv: キャッシュディレクトリが存在しないため、削除候補はありません。"
    puts ""
    return true
  end

  # uv cache clean はドライラン機能を持たないため、個別ファイル一覧は表示できない。
  # ディレクトリ合計サイズのみを削除候補として提示する。
  bytes = dir_size_bytes(UV_CACHE_DIR)
  if bytes < options[:min_size_mb] * 1024 * 1024
    print_info "uv: キャッシュサイズが閾値未満のため対象外です (#{human(bytes)})。"
    puts ""
    return true
  end

  puts "uv 削除候補:".bold
  puts "  #{UV_CACHE_DIR} (#{human(bytes)})"
  puts ""

  holders = uv_lock_holders
  unless holders.empty?
    print_warn "以下のプロセスが uv キャッシュのロックを保持しています。削除時にブロック/タイムアウトする可能性があります:"
    print_lock_holders(holders)
    puts ""
  end

  unless options[:execute]
    print_info "ドライランのため uv キャッシュの削除は行っていません。削除するには --execute を指定してください。"
    puts ""
    return true
  end

  unless options[:yes]
    unless confirm?("uv キャッシュ (#{human(bytes)}) を削除します。よろしいですか?")
      print_warn "uv キャッシュの削除をキャンセルしました。"
      puts ""
      return true
    end
  end

  # confirm 待ちの間に状況が変わっている可能性があるため実行直前に再チェックする。
  # ロック保持プロセスがいる場合、uv cache clean を呼ぶとタイムアウト(デフォルト300秒)
  # まで無反応でブロックしてしまうため、呼ばずに即座にスキップして対処法を案内する。
  holders = uv_lock_holders
  unless holders.empty?
    print_error "uv キャッシュのロックを保持しているプロセスがあるため、削除をスキップしました。"
    print_error "以下のプロセスを終了してから再実行してください:"
    print_lock_holders(holders)
    puts ""
    print_info "終了コマンド例: kill #{holders.map { |h| h[:pid] }.join(' ')}"
    puts ""
    return false
  end

  output, status = run_uv_cache_clean
  puts output unless output.strip.empty?
  puts ""

  if status.success?
    print_info "uv キャッシュの削除が完了しました（解放見込み #{human(bytes)}）。"
    true
  else
    print_error "uv cache clean の実行に失敗しました。"
    false
  end
end

# --- オプション解析 ----------------------------------------------------------

options = {
  root: DEFAULT_ROOT,
  threshold_gb: DEFAULT_THRESHOLD_GB,
  min_size_mb: DEFAULT_MIN_SIZE_MB,
  excludes: [],
  only: [],
  execute: false,
  yes: false,
  skip_app_support: false,
  skip_homebrew: false,
  skip_uv: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [OPTIONS]"
  opts.separator ""
  opts.separator "Application Support 以下のキャッシュフォルダ（名前に \"cache\" を含むディレクトリ）、"
  opts.separator "Homebrew のダウンロードキャッシュ、uv のパッケージキャッシュを検出し、"
  opts.separator "一覧表示・削除するツール。デフォルトはドライラン（一覧表示のみ）。"
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

  opts.on("--skip-app-support", "Application Support のスキャンをスキップする") do
    options[:skip_app_support] = true
  end

  opts.on("--skip-homebrew", "Homebrew キャッシュ (brew cleanup) の確認をスキップする") do
    options[:skip_homebrew] = true
  end

  opts.on("--skip-uv", "uv キャッシュ (uv cache clean) の確認をスキップする") do
    options[:skip_uv] = true
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
  opts.separator "  #{File.basename($0)} --skip-app-support --skip-homebrew  # uv キャッシュだけ確認・削除する"
end

parser.parse!

sections = []
sections << -> { app_support_section(options) } unless options[:skip_app_support]
sections << -> { homebrew_section(options) } unless options[:skip_homebrew]
sections << -> { uv_section(options) } unless options[:skip_uv]

if sections.empty?
  print_warn "すべてのセクションがスキップされたため、何も実行しません。"
  exit 0
end

results = sections.each_with_index.map do |section, idx|
  puts "" if idx.positive?
  section.call
end

exit(results.all? ? 0 : 1)
