#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Network port information utility for macOS
# Retrieves hardware port details, network status, IP addresses, and SSID
#

require 'optparse'
require 'json'

# Color codes for terminal output
COLORS = {
  reset: "\e[0m",
  red: "\e[31m",
  green: "\e[32m",
  yellow: "\e[33m"
}.freeze

class NetworkPortUtility
  def initialize(format: 'text')
    @format = format
    @device_cache = nil
  end

  # Get list of all hardware ports and their devices
  def get_device_list
    return @device_cache if @device_cache

    ports = {}
    output = `networksetup -listallhardwareports 2>/dev/null`
    lines = output.split("\n")

    port_name = nil
    lines.each do |line|
      case line
      when /^Hardware Port: (.+)$/
        port_name = Regexp.last_match(1)
      when /^Device: (.+)$/
        if port_name
          device_name = Regexp.last_match(1)
          ports[port_name] = device_name
          port_name = nil
        end
      end
    end

    @device_cache = ports
  end

  # Get port status (active/inactive)
  def get_port_status(device)
    output = `ifconfig #{device} 2>/dev/null`
    lines = output.split("\n")

    lines.each do |line|
      match = line.match(/\tstatus: (.+)$/)
      return match[1] if match
    end

    'inactive'
  rescue StandardError
    'inactive'
  end

  # Get IPv4 address for a port
  def get_port_addr(device)
    output = `ifconfig #{device} 2>/dev/null`
    lines = output.split("\n")

    lines.each do |line|
      match = line.match(/\tinet\s+(\S+)\s/)
      return match[1] if match
    end

    nil
  rescue StandardError
    nil
  end

  # Get SSID for a Wi-Fi port
  # Logic from get-ssid.sh: checks IP, DHCP status, then retrieves preferred network
  def get_ssid(device)
    # Check if interface has an IP address
    ip_addr = `ipconfig getifaddr #{device} 2>/dev/null`.strip

    if ip_addr.empty?
      set_error("Wi-Fi not connected (#{device})")
      return nil
    end

    # Check for link-local address (DHCP failure)
    if ip_addr.match?(/^169\.254\./)
      set_error("Wi-Fi connection error - DHCP failed (#{device})")
      return nil
    end

    # Get preferred network (first in the list)
    ssid_output = `networksetup -listpreferredwirelessnetworks #{device} 2>/dev/null | sed -n '2p' | sed 's/^[[:space:]]*//'`.strip

    if ssid_output.empty?
      set_error("Failed to get SSID (#{device})")
      return nil
    end

    ssid_output
  rescue StandardError => e
    set_error("Error getting SSID: #{e.message}")
    nil
  end

  # Command: list all ports and devices
  def cmd_list
    ports = get_device_list

    case @format
    when 'json'
      output = { ports: ports.map { |name, device| { name:, device: } } }
      puts JSON.generate(output)
    when 'text'
      ports.each { |name, device| puts "#{name}:#{device}" }
    end
  end

  # Command: get device name for a port
  def cmd_device(port)
    ports = get_device_list

    case @format
    when 'json'
      if ports.key?(port)
        output = { port:, device: ports[port] }
        puts JSON.generate(output)
      else
        set_error("Port '#{port}' not found")
        exit 1
      end
    when 'text'
      if ports.key?(port)
        puts ports[port]
      else
        puts 'none'
      end
    end
  end

  # Command: get status for a port
  def cmd_status(port)
    ports = get_device_list

    case @format
    when 'json'
      if ports.key?(port)
        status = get_port_status(ports[port])
        output = { port:, status: }
        puts JSON.generate(output)
      else
        set_error("Port '#{port}' not found")
        exit 1
      end
    when 'text'
      if ports.key?(port)
        status = get_port_status(ports[port])
        puts status
      else
        puts 'inactive'
      end
    end
  end

  # Command: get IPv4 address for a port
  def cmd_addr(port)
    ports = get_device_list

    case @format
    when 'json'
      if ports.key?(port)
        addr = get_port_addr(ports[port])
        if addr
          output = { port:, addr: }
          puts JSON.generate(output)
        else
          set_error("No IPv4 address for port '#{port}'")
          exit 1
        end
      else
        set_error("Port '#{port}' not found")
        exit 1
      end
    when 'text'
      if ports.key?(port)
        addr = get_port_addr(ports[port])
        puts addr if addr
      end
    end
  end

  # Command: get SSID for a port
  def cmd_ssid(port)
    ports = get_device_list

    case @format
    when 'json'
      if ports.key?(port)
        ssid = get_ssid(ports[port])
        if ssid
          output = { port:, ssid: }
          puts JSON.generate(output)
        else
          exit 1
        end
      else
        set_error("Port '#{port}' not found")
        exit 1
      end
    when 'text'
      if ports.key?(port)
        ssid = get_ssid(ports[port])
        puts ssid if ssid
      else
        set_error("Port '#{port}' not found")
        exit 1
      end
    end
  end

  private

  def set_error(message)
    warn "Error: #{message}"
  end
end

def main
  format = 'text'
  help = false

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: net-port.rb [options] <command> [arguments]'

    opts.on('--format FORMAT', 'Output format (text, json)', 'default: text') do |f|
      format = f
    end

    opts.on_tail('-h', '--help', 'Show this message') do
      help = true
    end
  end

  parser.parse!

  if help || ARGV.empty?
    puts parser
    puts <<~HELP

      Commands:
        list              List all hardware ports and devices
        device PORT       Show device name for a port
        status PORT       Show connection status for a port
        addr PORT         Show IPv4 address for a port
        ssid PORT         Show SSID for a Wi-Fi port

      Examples:
        net-port.rb list
        net-port.rb device Wi-Fi
        net-port.rb status Ethernet
        net-port.rb addr Wi-Fi
        net-port.rb ssid Wi-Fi
        net-port.rb --format json device Wi-Fi
    HELP
    exit 0
  end

  command = ARGV.shift
  utility = NetworkPortUtility.new(format:)

  case command
  when 'list'
    utility.cmd_list
  when 'device'
    port = ARGV.shift
    if port
      utility.cmd_device(port)
    else
      warn 'Error: port argument required'
      exit 1
    end
  when 'status'
    port = ARGV.shift
    if port
      utility.cmd_status(port)
    else
      warn 'Error: port argument required'
      exit 1
    end
  when 'addr'
    port = ARGV.shift
    if port
      utility.cmd_addr(port)
    else
      warn 'Error: port argument required'
      exit 1
    end
  when 'ssid'
    port = ARGV.shift
    if port
      utility.cmd_ssid(port)
    else
      warn 'Error: port argument required'
      exit 1
    end
  else
    warn "Error: unknown command '#{command}'"
    exit 1
  end
end

main if $PROGRAM_NAME == __FILE__
