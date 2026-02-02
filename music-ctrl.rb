#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Music control service management utility for macOS
# Allows starting, stopping, and checking the status of the music control service
#
# Usage:
#   music-ctrl.rb [options] <command>
#
# Commands:
#   start                 Start the music control service
#   stop                  Stop the music control service
#   status                Show the status of the music control service
#
# Options:
#   -h, --help           Show this help message
#

require 'optparse'

# Color codes for terminal output
COLORS = {
  reset: "\e[0m",
  red: "\e[31m",
  green: "\e[32m",
  yellow: "\e[33m"
}.freeze

class MusicControlService
  SERVICE_PLIST = '/System/Library/LaunchAgents/com.apple.rcd.plist'.freeze

  def control_service(action)
    command = action == :start ? 'load' : 'unload'
    success = system("launchctl #{command} -w #{SERVICE_PLIST} 2>/dev/null")

    message = if success
                "Service #{action == :start ? 'started' : 'stopped'} successfully"
              else
                "Failed to #{action} service. May require sudo or SIP is enabled."
              end

    if success
      puts "#{COLORS[:green]}#{message}#{COLORS[:reset]}"
    else
      warn "#{COLORS[:red]}#{message}#{COLORS[:reset]}"
      exit 1
    end
  end

  def start_service
    control_service(:start)
  end

  def stop_service
    control_service(:stop)
  end

  def service_status
    output = `launchctl list 2>/dev/null | grep com.apple.rcd`
    $?.success? && !output.strip.empty?
  end

  def display_status
    status = service_status ? 'running' : 'stopped'
    color = status == 'running' ? COLORS[:green] : COLORS[:red]
    puts "Music Control Service is #{color}#{status}#{COLORS[:reset]}"
  end
end

def main
  help = false

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: music-ctrl.rb [options] <command>'

    opts.on_tail('-h', '--help', 'Show this message') do
      help = true
    end
  end

  parser.parse!

  if help || ARGV.empty?
    puts parser
    puts <<~HELP
      Commands:
        start                 Start the music control service
        stop                  Stop the music control service
        status                Show the status of the music control service
    HELP
    exit 0
  end

  command = ARGV.shift
  service = MusicControlService.new

  case command
  when 'start'
    service.start_service
  when 'stop'
    service.stop_service
  when 'status'
    service.display_status
  else
    warn "Unknown command: #{command}"
    puts parser
    exit 1
  end
end

main if $PROGRAM_NAME == __FILE__