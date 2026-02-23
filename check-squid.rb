#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Check and manage squid proxy configuration
# Switches symlinked squid.conf and controls the squid service.
# Uses standard library only (open3, optparse).
#
# Usage:
#   check-squid.rb [options]
#
# Options:
#   -d, --debug           Enable debug mode
#   -n, --name NAME       Switch config to named preset
#   -r, --reconfig        Send reconfigure signal to squid
#   -s, --restart         Restart squid service
#   -h, --help            Show this help
#

require 'open3'
require 'optparse'

SQUID_CONFIG = '/opt/homebrew/etc/squid.conf'
SQUID_BIN    = '/opt/homebrew/sbin/squid'
SQUID_PID    = '/opt/homebrew/var/run/squid.pid'
BREW_CMD     = '/opt/homebrew/bin/brew'

SQUID_CONFIGS = [
  { name: 'fxz',     config: '/Users/junya/Documents/Etc/squid-fxzhome.conf' }, # For FXZ
  { name: 'office',  config: '/Users/junya/Documents/Etc/squid-proxy.conf' },   # For Office
  { name: 'default', config: '/Users/junya/Documents/Etc/squid-noproxy.conf' }, # For Default
].freeze

def run_cmd(cmd, label)
  output, status = Open3.capture2e(*cmd)
  output.lines.each { |line| print "  #{line}" }
  unless status.success?
    $stderr.puts "error on #{label}: exit #{status.exitstatus}"
    exit 1
  end
end

def main
  options = { debug: false, name: nil, reconfig: false, restart: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: check-squid.rb [options]'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-d', '--debug',       'Enable debug mode')          { options[:debug]   = true }
    opts.on('-n', '--name NAME',   'Switch config to named preset',
            SQUID_CONFIGS.map { |c| c[:name] })                  { |v| options[:name]    = v }
    opts.on('-r', '--reconfig',    'Send reconfigure signal to squid') { options[:reconfig] = true }
    opts.on('-s', '--restart',     'Restart squid service')      { options[:restart]  = true }
    opts.on_tail('-h', '--help',   'Show this help')             { puts opts; exit 0 }
  end.parse!

  begin
    current_config = File.readlink(SQUID_CONFIG)
  rescue SystemCallError => e
    $stderr.puts "error on reading link #{SQUID_CONFIG}: #{e}"
    exit 1
  end

  if options[:name]
    entry = SQUID_CONFIGS.find { |c| c[:name] == options[:name] }
    config_file = entry[:config]

    puts "Change config from #{current_config} to #{config_file}"

    puts "Remove #{SQUID_CONFIG}"
    begin
      File.delete(SQUID_CONFIG)
    rescue SystemCallError => e
      $stderr.puts "error on removing file #{SQUID_CONFIG}: #{e}"
      exit 1
    end

    puts "Link #{config_file} to #{SQUID_CONFIG}"
    begin
      File.symlink(config_file, SQUID_CONFIG)
    rescue SystemCallError => e
      $stderr.puts "error on creating symlink #{SQUID_CONFIG}: #{e}"
      exit 1
    end

    begin
      current_config = File.readlink(SQUID_CONFIG)
    rescue SystemCallError => e
      $stderr.puts "error on reading link #{SQUID_CONFIG}: #{e}"
      exit 1
    end
  end

  puts "Current config is #{current_config}"

  if options[:reconfig]
    run_cmd([SQUID_BIN, '-k', 'reconfigure'], 'reconfig')
  end

  if options[:restart]
    puts 'Stop service squid'
    run_cmd([BREW_CMD, 'services', 'stop', 'squid'], 'stopping squid')

    puts "Remove #{SQUID_PID}"
    begin
      File.delete(SQUID_PID)
    rescue SystemCallError => e
      $stderr.puts "error on removing file #{SQUID_PID}: #{e}"
      exit 1
    end

    puts 'Start service squid'
    run_cmd([BREW_CMD, 'services', 'start', 'squid'], 'starting squid')

    puts 'squid restarted'
  end
end

main if $PROGRAM_NAME == __FILE__
