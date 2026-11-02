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
#   -d, --delay SEC       Seconds to wait before launching (default: 15, 0 with --restart-all)
#   -i, --interval SEC    Seconds between each launch (default: 1)
#   -r, --restart-all     Quit and relaunch every app in the list, as if all had 'restart'.
#                         Run this by hand when some apps still lost their permission.
#   -n, --dry-run         Check the app list without waiting or launching
#       --no-notify       Do not show notifications (before launching, and on failure)
#   -h, --help            Show this help
#
# Config file format (one bundle ID per line, '#' starts a comment):
#   com.hegenberg.BetterTouchTool   # BetterTouchTool
#   com.pilotmoon.popclip           # PopClip
#   com.lwouis.alt-tab-macos nohide # AltTab
#   com.culturedcode.ThingsMacSandboxHelper nohide restart
#
# Flags after the bundle ID:
#   nohide   Launch without -j. Some apps (e.g. AltTab) do not work when launched hidden.
#   restart  Quit the app first if it is already running. For apps that re-register
#            themselves as a login item (e.g. Things helper) and so start too early.
#

require 'optparse'
require 'open3'

DEFAULT_CONFIG   = File.join(Dir.home, '.config', 'delayed-launch', 'apps.conf')
DEFAULT_DELAY    = 15
DEFAULT_INTERVAL = 1
QUIT_TIMEOUT     = 5

App = Struct.new(:id, :hide, :restart)

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

def load_apps(path)
  unless File.exist?(path)
    warn "error: config file not found: #{path}"
    exit 1
  end

  # launchd may start this before LANG is set, so do not rely on the default encoding
  File.readlines(path, chomp: true, encoding: 'UTF-8')
      .map { |line| line.sub(/#.*/, '').split }
      .reject(&:empty?)
      .map { |id, *flags| App.new(id, !flags.include?('nohide'), flags.include?('restart')) }
end

def app_path(bundle_id)
  out, = Open3.capture2('mdfind', "kMDItemCFBundleIdentifier == '#{bundle_id}'")
  out.lines.map(&:chomp).find { |p| p.end_with?('.app') }
end

def running_pids(path)
  out, = Open3.capture2('pgrep', '-f', "^#{Regexp.escape(path)}/Contents/MacOS/")
  out.split.map(&:to_i)
end

# Ask the app to quit normally, like Cmd+Q or Quit in the Dock.
# Use NSRunningApplication#terminate rather than an AppleScript 'quit', which
# needs the Automation permission and could itself be hit by the TCC issue.
TERMINATE_SCRIPT = <<~JS
  ObjC.import('AppKit');
  function run(argv) {
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(argv[0]);
    for (let i = 0; i < apps.count; i++) apps.objectAtIndex(i).terminate;
  }
JS

def quit_if_running(app)
  path = app_path(app.id)
  return unless path

  pids = running_pids(path)
  return if pids.empty?

  _, err, status = Open3.capture3('osascript', '-l', 'JavaScript', '-e', TERMINATE_SCRIPT, app.id)
  unless status.success?
    log "quit failed #{app.id}: #{err.strip}"
    return
  end

  QUIT_TIMEOUT.times do
    if running_pids(path).empty?
      log "quit     #{app.id} (pid #{pids.join(', ')})"
      return
    end

    sleep 1
  end
  # Do not force it: the app may be waiting for the user (e.g. unsaved changes)
  log "still running after #{QUIT_TIMEOUT}s, not relaunched: #{app.id}"
end

def dry_run(apps)
  missing = 0
  apps.each do |app|
    path = app_path(app.id)
    note = "#{' [nohide]' unless app.hide}#{' [restart]' if app.restart}"
    if path
      puts "OK       #{app.id}#{note}  (#{path})"
    else
      puts "NOTFOUND #{app.id}#{note}"
      missing += 1
    end
  end
  exit(missing.zero? ? 0 : 1)
end

def launch_all(apps, delay:, interval:, notify:)
  if delay.positive?
    log "waiting #{delay}s before launching #{apps.size} apps"
    sleep delay
  end
  notify("#{apps.size}個のアプリを起動します") if notify

  failed = 0
  apps.each_with_index do |app, i|
    sleep interval if i.positive?
    quit_if_running(app) if app.restart
    # -g: launch in the background so the apps do not steal focus
    # -j: launch hidden so the apps do not pop up their windows
    args = ['-g', ('-j' if app.hide), '-b', app.id].compact
    _, err, status = Open3.capture3('open', *args)
    if status.success?
      log "launched #{app.id}#{' (nohide)' unless app.hide}"
    else
      log "failed   #{app.id}: #{err.strip}"
      failed += 1
    end
  end
  log 'done'

  notify("#{failed}個のアプリの起動に失敗しました。ログを確認してください") if notify && failed.positive?
end

def main
  options = { config: DEFAULT_CONFIG, delay: nil, interval: DEFAULT_INTERVAL, restart_all: false, dry_run: false,
              notify: true }

  OptionParser.new do |opts|
    opts.banner = 'Usage: delayed-launch.rb [options]'

    opts.on('-c', '--config PATH', "App list (default: #{DEFAULT_CONFIG})") do |v|
      options[:config] = File.expand_path(v)
    end

    opts.on('-d', '--delay SEC', Integer,
            "Seconds to wait before launching (default: #{DEFAULT_DELAY}, 0 with --restart-all)") do |v|
      options[:delay] = v
    end

    opts.on('-i', '--interval SEC', Integer, "Seconds between each launch (default: #{DEFAULT_INTERVAL})") do |v|
      options[:interval] = v
    end

    opts.on('-r', '--restart-all', "Quit and relaunch every app in the list, as if all had 'restart'") do
      options[:restart_all] = true
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

  apps = load_apps(options[:config])
  apps.each { |app| app.restart = true } if options[:restart_all]
  delay = options[:delay] || (options[:restart_all] ? 0 : DEFAULT_DELAY)
  if options[:dry_run]
    dry_run(apps)
  else
    launch_all(apps, delay: delay, interval: options[:interval], notify: options[:notify])
  end
end

main if $PROGRAM_NAME == __FILE__
