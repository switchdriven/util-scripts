#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Show IP address settings
# Displays network interface addresses using the `ip` command (iproute2mac).
# Uses standard library only (open3, optparse, json).
#
# Usage:
#   check-ip.rb [options]
#
# Options:
#   -d, --debug           Show debug info
#   -4, --inet            Show only inet4 addresses
#   -i, --netif IFACE     Show only specified interface
#   -a, --all             Show all interfaces (including utun*)
#   -h, --help            Show this help
#

require 'open3'
require 'optparse'
require 'json'

IP_CMD = '/opt/homebrew/bin/ip'

def main
  options = { debug: false, inet: false, netif: nil, all: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: check-ip.rb [options]'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-d', '--debug',          'Show debug info')                { options[:debug] = true }
    opts.on('-4', '--inet',           'Show only inet4 addresses')      { options[:inet]  = true }
    opts.on('-i', '--netif IFACE',    'Show only specified interface')  { |v| options[:netif] = v }
    opts.on('-a', '--all',            'Show all interfaces')            { options[:all]   = true }
    opts.on_tail('-h', '--help',      'Show this help')                 { puts opts; exit 0 }
  end.parse!

  cmd = [IP_CMD, '-j', 'address', 'show']
  cmd << options[:netif] if options[:netif]

  $stderr.puts "Cmd = #{cmd}" if options[:debug]

  stdout, stderr, status = Open3.capture3(*cmd)
  unless status.success?
    $stderr.puts "error on exec ip: #{stderr.strip}"
    exit 1
  end

  if stdout.empty?
    $stderr.puts "no information on #{options[:netif]}"
    return
  end

  ip_data = JSON.parse(stdout)

  if_list = ip_data.each_with_index.filter_map do |iface, index|
    next if !options[:all] && iface['ifname'].include?('utun')

    [index, iface['ifname']]
  end

  $stderr.puts 'Device utun* is omitted' if options[:debug] && !options[:all]

  if_list.each do |index, ifname|
    iface = ip_data[index]

    unless iface['addr_info']
      $stderr.puts "Skip interface: #{ifname}" if options[:debug]
      next
    end

    addr_list = iface['addr_info'].filter_map do |inet|
      next if options[:inet] && inet['family'] == 'inet6'

      addr = "#{inet['family']} #{inet['local']}/#{inet['prefixlen']}"
      addr += " brd #{inet['broadcast']}" if inet['broadcast']
      addr
    end

    next if addr_list.empty?

    flags = iface['flags'].join(',')
    puts "#{ifname} : <#{flags}> mtu #{iface['mtu']} status #{iface['operstate']}"
    puts "\t link/#{iface['address']} #{iface['link_type']} brd #{iface['broadcast']}" if iface['address']
    addr_list.each { |addr| puts "\t #{addr}" }
  end
end

main if $PROGRAM_NAME == __FILE__
