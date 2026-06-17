#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

BROWSERS = {
  'chrome'        => File.expand_path('~/Library/Application Support/Google/Chrome'),
  'chromium'      => File.expand_path('~/Library/Application Support/Chromium'),
  'brave'         => File.expand_path('~/Library/Application Support/BraveSoftware/Brave-Browser'),
  'edge'          => File.expand_path('~/Library/Application Support/Microsoft Edge'),
  'edge-beta'     => File.expand_path('~/Library/Application Support/Microsoft Edge Beta'),
  'edge-dev'      => File.expand_path('~/Library/Application Support/Microsoft Edge Dev'),
  'edge-canary'   => File.expand_path('~/Library/Application Support/Microsoft Edge Canary'),
}.freeze

BOLD  = "\e[1m"
CYAN  = "\e[36m"
RESET = "\e[0m"

options = { browser: 'chrome', all: false }

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"
  opts.separator ''
  opts.separator 'Options:'
  opts.on('-b', '--browser BROWSER',
          "対象ブラウザ (#{BROWSERS.keys.join(', ')})",
          "デフォルト: chrome") { |v| options[:browser] = v.downcase }
  opts.on('-a', '--all', 'インストール済みの全ブラウザを表示') { options[:all] = true }
  opts.on('-h', '--help', 'このヘルプを表示') { puts opts; exit }
end.parse!

def list_profiles(browser_name, data_dir)
  return false unless Dir.exist?(data_dir)

  profile_dirs = Dir.glob(File.join(data_dir, '{Default,Profile *}')).sort_by do |d|
    basename = File.basename(d)
    basename == 'Default' ? '000' : basename
  end

  return false if profile_dirs.empty?

  puts "#{BOLD}#{CYAN}#{browser_name}#{RESET}  #{data_dir}"
  puts '─' * 60

  profile_dirs.each do |dir|
    prefs_path = File.join(dir, 'Preferences')
    next unless File.exist?(prefs_path)

    name = begin
      prefs = JSON.parse(File.read(prefs_path))
      profile_name = prefs.dig('profile', 'name')
      # ブラウザが自動設定したデフォルト名（"ユーザー N" / "User N" / "プロファイル N" / "Profile N"）の場合
      # account_info のアカウント名で補完する
      if profile_name.nil? || profile_name.match?(/\A(ユーザー|User|プロファイル|Profile)\s+\d+\z/)
        account = prefs.dig('account_info', 0)
        full_name = account&.fetch('full_name', nil).then { |v| v&.empty? ? nil : v }
        email     = account&.fetch('email', nil).then { |v| v&.empty? ? nil : v }
        profile_name = full_name || email || profile_name
      end
      profile_name || '(名前なし)'
    rescue JSON::ParserError
      '(読み取りエラー)'
    end

    folder = File.basename(dir)
    printf "  %-14s  %s\n", folder, name
  end

  puts
  true
end

if options[:all]
  found = false
  BROWSERS.each { |name, dir| found = true if list_profiles(name, dir) }
  warn '対応ブラウザが見つかりませんでした。' unless found
else
  browser = options[:browser]
  unless BROWSERS.key?(browser)
    warn "未知のブラウザ: #{browser}"
    warn "使用可能: #{BROWSERS.keys.join(', ')}"
    exit 1
  end
  unless list_profiles(browser, BROWSERS[browser])
    warn "#{browser} のプロファイルディレクトリが見つかりませんでした: #{BROWSERS[browser]}"
    exit 1
  end
end
