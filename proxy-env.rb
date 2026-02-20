#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Manage and check proxy settings
# This script manages the proxy server settings using the networksetup utility.
#
# Usage:
#   proxy-env.rb [options] <action> [port]
#
# Actions:
#   on    Enable proxy for specified port (requires --name and port)
#   off   Disable proxy for specified port (requires port)
#   show  Show proxy settings (optionally for a specific port)
#   squid Show squid configuration and process status
#   list  List available proxy configurations
#
# Options:
#   -d, --debug        Enable debug output
#   -n, --name NAME    Proxy config name (required for 'on')
#   -h, --help         Show this help
#

require 'optparse'
require 'open3'

NETWORKSETUP = '/usr/sbin/networksetup'
SQUID_CONF   = '/opt/homebrew/etc/squid.conf'

NETWORK_PORTS = [
  { name: 'wifi',  interface: 'Wi-Fi' },
  { name: 'ether', interface: 'USB 10/100/1000 LAN' },
  { name: 'fxz',   interface: 'FXZ' }
].freeze

PROXY_CONFIG = [
  { name: 'socks',  url: 'http://localhost:8080/proxy/proxy-socks.pac' },
  { name: 'squid',  url: 'http://localhost:8080/proxy/proxy-squid.pac' },
  { name: 'local',  url: 'http://localhost:8080/proxy/proxy-local.pac' },
  { name: 'office', url: 'http://wpad.iiji.jp/proxy.pac' }
].freeze

class ProxyManager
  def initialize(debug: false)
    @debug = debug
  end

  def show(port = nil)
    if port
      show_port_proxy(port)
    else
      show_all_proxy_status
    end
  end

  def enable(port, name)
    config = PROXY_CONFIG.find { |p| p[:name] == name }
    unless config
      warn "error: proxy '#{name}' not found"
      exit 1
    end

    url = config[:url]
    warn "cmd = #{NETWORKSETUP} -setautoproxyurl #{port} #{url}" if @debug

    run_networksetup!('-setautoproxyurl', port, url)
    run_networksetup!('-setautoproxystate', port, 'on')
    show_port_proxy(port)
  end

  def disable(port)
    warn "cmd = #{NETWORKSETUP} -setautoproxystate #{port} off" if @debug
    run_networksetup!('-setautoproxystate', port, 'off')
    show_port_proxy(port)
  end

  def squid_status
    puts 'Squid Conf:'
    begin
      target = File.readlink(SQUID_CONF)
      puts "  #{target}"
    rescue Errno::EINVAL
      # not a symlink
      if File.exist?(SQUID_CONF)
        puts "  #{SQUID_CONF} (not a symlink)"
      else
        puts '  (not found)'
      end
    end

    puts
    puts 'Squid process:'
    out, status = Open3.capture2('ps', '-ea')
    if status.success?
      lines = out.lines.select do |line|
        line.include?('squid') && !line.include?('grep') && !line.include?('proxy-env.rb')
      end
      if lines.empty?
        puts '  (not running)'
      else
        lines.each { |line| puts "  #{line.strip}" }
      end
    else
      warn '  error: failed to run ps'
    end
  end

  def list_configs
    width = PROXY_CONFIG.map { |p| p[:name].length }.max
    PROXY_CONFIG.each do |p|
      puts "  #{p[:name].ljust(width)}  #{p[:url]}"
    end
  end

  private

  def parse_proxy_output(output)
    output.lines.each_with_object({}) do |line, hash|
      key, value = line.split(': ', 2)
      hash[key.strip] = value.strip if key && value
    end
  end

  def print_proxy_info(interface, output)
    parsed = parse_proxy_output(output)
    url     = parsed['URL'] || '(none)'
    enabled = parsed['Enabled'] || '(unknown)'
    puts "#{interface}:"
    puts "  URL:     #{url}"
    puts "  Enabled: #{enabled}"
  end

  def show_port_proxy(port)
    out, status = Open3.capture2(NETWORKSETUP, '-getautoproxyurl', port)
    if status.success?
      print_proxy_info(port, out)
    else
      warn "error: failed to get proxy for #{port}"
      exit 1
    end
  end

  def show_all_proxy_status
    NETWORK_PORTS.each do |port|
      out, status = Open3.capture2(NETWORKSETUP, '-getautoproxyurl', port[:interface])
      if status.success?
        print_proxy_info(port[:interface], out)
      else
        puts "#{port[:interface]}:"
        puts '  error: failed to get proxy info'
      end
      puts
    end

    puts 'System (scutil):'
    out, status = Open3.capture2('scutil', '--proxy')
    if status.success?
      scutil = out.lines.each_with_object({}) do |line, hash|
        key, value = line.strip.split(' : ', 2)
        hash[key] = value if key && value
      end
      enabled = scutil['ProxyAutoConfigEnable'] == '1'
      url     = enabled ? (scutil['ProxyAutoConfigURLString'] || '(null)') : '(null)'
      puts "  URL:     #{url}"
      puts "  Enabled: #{enabled ? 'Yes' : 'No'}"
    else
      warn '  error: failed to run scutil'
    end
  end

  def run_networksetup!(*args)
    _, status = Open3.capture2(NETWORKSETUP, *args)
    unless status.success?
      warn "error: networksetup #{args.join(' ')} failed"
      exit 1
    end
  end
end

ACTIONS = %w[on off show squid list].freeze
PROXY_NAMES = PROXY_CONFIG.map { |p| p[:name] }.freeze

def main
  options = { debug: false, name: nil }

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: proxy-env.rb [options] <action> [port]'

    opts.on('-d', '--debug', 'Enable debug output') do
      options[:debug] = true
    end

    opts.on('-n', '--name NAME', PROXY_NAMES, "Proxy config name (#{PROXY_NAMES.join(', ')})") do |v|
      options[:name] = v
    end

    opts.on_tail('-h', '--help', 'Show this help') do
      puts opts
      puts
      puts "Actions: #{ACTIONS.join(', ')}"
      exit 0
    end
  end

  begin
    parser.parse!
  rescue OptionParser::InvalidArgument => e
    warn "error: #{e.message}"
    exit 1
  end

  action = ARGV.shift
  unless ACTIONS.include?(action)
    warn action ? "error: unknown action '#{action}'" : 'error: action is required'
    warn "Available actions: #{ACTIONS.join(', ')}"
    exit 1
  end

  port = ARGV.shift
  manager = ProxyManager.new(debug: options[:debug])

  case action
  when 'show'
    manager.show(port)
  when 'squid'
    manager.squid_status
  when 'list'
    manager.list_configs
  when 'on'
    unless port
      warn "error: port is required for action 'on'"
      exit 1
    end
    unless options[:name]
      warn "error: --name is required for action 'on'"
      exit 1
    end
    manager.enable(port, options[:name])
  when 'off'
    unless port
      warn "error: port is required for action 'off'"
      exit 1
    end
    manager.disable(port)
  end
end

main if $PROGRAM_NAME == __FILE__
