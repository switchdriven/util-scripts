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

APP_PATHS = {
  'chrome'        => '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  'chromium'      => '/Applications/Chromium.app/Contents/MacOS/Chromium',
  'brave'         => '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
  'edge'          => '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  'edge-beta'     => '/Applications/Microsoft Edge Beta.app/Contents/MacOS/Microsoft Edge Beta',
  'edge-dev'      => '/Applications/Microsoft Edge Dev.app/Contents/MacOS/Microsoft Edge Dev',
  'edge-canary'   => '/Applications/Microsoft Edge Canary.app/Contents/MacOS/Microsoft Edge Canary',
}.freeze

BOLD  = "\e[1m"
CYAN  = "\e[36m"
RESET = "\e[0m"

options = { browser: 'chrome', all: false, launch: nil }

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"
  opts.separator ''
  opts.separator 'Options:'
  opts.on('-b', '--browser BROWSER',
          "対象ブラウザ (#{BROWSERS.keys.join(', ')})",
          "デフォルト: chrome") { |v| options[:browser] = v.downcase }
  opts.on('-a', '--all', 'インストール済みの全ブラウザを表示') { options[:all] = true }
  opts.on('-l', '--launch FOLDER', 'プロファイルを指定して起動 (例: "Profile 2")') { |v| options[:launch] = v }
  opts.on('-h', '--help', 'このヘルプを表示') { puts opts; exit }
end.parse!

if options[:launch] && options[:all]
  warn '--launch と --all は同時に指定できません。'
  exit 1
end

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

browser = options[:browser]
unless BROWSERS.key?(browser)
  warn "未知のブラウザ: #{browser}"
  warn "使用可能: #{BROWSERS.keys.join(', ')}"
  exit 1
end

if options[:launch]
  folder   = options[:launch]
  data_dir = BROWSERS[browser]
  app_path = APP_PATHS[browser]

  unless Dir.exist?(File.join(data_dir, folder))
    warn "プロファイルフォルダが見つかりません: #{folder}"
    warn "利用可能なフォルダは --browser #{browser} で一覧確認してください。"
    exit 1
  end

  app_bundle = app_path[/\A.*\.app/]
  unless Dir.exist?(app_bundle)
    warn "アプリが見つかりません: #{app_bundle}"
    exit 1
  end

  system('open', '-na', app_bundle, '--args', "--profile-directory=#{folder}")
  puts "#{browser} を #{folder} で起動しました。"
elsif options[:all]
  found = false
  BROWSERS.each { |name, dir| found = true if list_profiles(name, dir) }
  warn '対応ブラウザが見つかりませんでした。' unless found
else
  unless list_profiles(browser, BROWSERS[browser])
    warn "#{browser} のプロファイルディレクトリが見つかりませんでした: #{BROWSERS[browser]}"
    exit 1
  end
end
