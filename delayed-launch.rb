#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Launch apps after a delay at login
# Workaround for macOS 27, where apps launched at login sometimes fail to load
# their Accessibility permission (tccd is not ready yet) and ask for it again.
# Remove the apps from Login Items and let a LaunchAgent run this script instead.
#
# Usage:
#   delayed-launch.rb [options]
#
# Options:
#   -c, --config PATH     App list (default: ~/.config/delayed-launch/apps.conf)
#   -d, --delay SEC       Seconds to wait before launching (default: 20)
#   -i, --interval SEC    Seconds between each launch (default: 1)
#   -n, --dry-run         Check the app list without waiting or launching
#       --no-notify       Do not show notifications (before launching, and on failure)
#   -h, --help            Show this help
#
# Config file format (one bundle ID per line, '#' starts a comment):
#   com.hegenberg.BetterTouchTool   # BetterTouchTool
#   com.pilotmoon.popclip           # PopClip
#

require 'optparse'
require 'open3'

DEFAULT_CONFIG   = File.join(Dir.home, '.config', 'delayed-launch', 'apps.conf')
DEFAULT_DELAY    = 20
DEFAULT_INTERVAL = 1

def log(msg)
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{msg}"
  $stdout.flush
end

def notify(msg)
  # Pass the text as arguments so it is never interpreted as AppleScript
  script = ['on run argv', 'display notification (item 1 of argv) with title (item 2 of argv)', 'end run']
  args = script.flat_map { |line| ['-e', line] }
  _, err, status = Open3.capture3('osascript', *args, msg, 'delayed-launch')
  log "notify failed: #{err.strip}" unless status.success?
end

def load_bundle_ids(path)
  unless File.exist?(path)
    warn "error: config file not found: #{path}"
    exit 1
  end

  # launchd may start this before LANG is set, so do not rely on the default encoding
  File.readlines(path, chomp: true, encoding: 'UTF-8')
      .map { |line| line.sub(/#.*/, '').strip }
      .reject(&:empty?)
end

def app_path(bundle_id)
  out, = Open3.capture2('mdfind', "kMDItemCFBundleIdentifier == '#{bundle_id}'")
  out.lines.map(&:chomp).find { |p| p.end_with?('.app') }
end

def dry_run(bundle_ids)
  missing = 0
  bundle_ids.each do |id|
    path = app_path(id)
    if path
      puts "OK       #{id}  (#{path})"
    else
      puts "NOTFOUND #{id}"
      missing += 1
    end
  end
  exit(missing.zero? ? 0 : 1)
end

def launch_all(bundle_ids, delay:, interval:, notify:)
  log "waiting #{delay}s before launching #{bundle_ids.size} apps"
  sleep delay
  notify("#{bundle_ids.size}個のアプリを起動します") if notify

  failed = 0
  bundle_ids.each_with_index do |id, i|
    sleep interval if i.positive?
    # -g: launch in the background so the apps do not steal focus
    # -j: launch hidden so the apps do not pop up their windows
    _, err, status = Open3.capture3('open', '-g', '-j', '-b', id)
    if status.success?
      log "launched #{id}"
    else
      log "failed   #{id}: #{err.strip}"
      failed += 1
    end
  end
  log 'done'

  notify("#{failed}個のアプリの起動に失敗しました。ログを確認してください") if notify && failed.positive?
end

def main
  options = { config: DEFAULT_CONFIG, delay: DEFAULT_DELAY, interval: DEFAULT_INTERVAL, dry_run: false, notify: true }

  OptionParser.new do |opts|
    opts.banner = 'Usage: delayed-launch.rb [options]'

    opts.on('-c', '--config PATH', "App list (default: #{DEFAULT_CONFIG})") do |v|
      options[:config] = File.expand_path(v)
    end

    opts.on('-d', '--delay SEC', Integer, "Seconds to wait before launching (default: #{DEFAULT_DELAY})") do |v|
      options[:delay] = v
    end

    opts.on('-i', '--interval SEC', Integer, "Seconds between each launch (default: #{DEFAULT_INTERVAL})") do |v|
      options[:interval] = v
    end

    opts.on('-n', '--dry-run', 'Check the app list without waiting or launching') do
      options[:dry_run] = true
    end

    opts.on('--no-notify', 'Do not show notifications (before launching, and on failure)') do
      options[:notify] = false
    end

    opts.on_tail('-h', '--help', 'Show this help') do
      puts opts
      exit 0
    end
  end.parse!

  bundle_ids = load_bundle_ids(options[:config])
  if options[:dry_run]
    dry_run(bundle_ids)
  else
    launch_all(bundle_ids, delay: options[:delay], interval: options[:interval], notify: options[:notify])
  end
end

main if $PROGRAM_NAME == __FILE__
