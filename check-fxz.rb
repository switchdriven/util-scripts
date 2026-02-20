#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Check & fix routing when using FXZ VPN
# Detects local network routes captured by the VPN tunnel and generates fix commands.
#
# Usage:
#   check-fxz.rb [options]
#
# Options:
#   -d, --debug           Show debug info
#   -f, --fix             Generate fix routing commands
#   -i, --netif INTERFACE Target network interface (auto-detected if omitted)
#   -h, --help            Show this help
#

require 'ipaddr'
require 'json'
require 'open3'
require 'optparse'
require 'set'

IP_COMMAND = '/opt/homebrew/bin/ip'

# IPv4 local networks reachable via gateway (need route del + route add if uncovered)
GATEWAY_NETWORKS_V4 = [
  IPAddr.new('192.168.1.0/24'),
  IPAddr.new('192.168.2.0/24'),
  IPAddr.new('192.168.3.0/24')
].freeze

# Directly connected networks (only need route del, no route add needed)
DIRECT_NETWORKS_V4 = [
  IPAddr.new('10.211.55.0/24')
].freeze

# All local networks (used for FXZ route matching)
LOCAL_NETWORKS_V4 = (GATEWAY_NETWORKS_V4 + DIRECT_NETWORKS_V4).freeze

# IPv6 half-default routes that VPN adds even when IPv6 is disabled
IPV6_HALF_DEFAULTS = [
  IPAddr.new('::/1'),
  IPAddr.new('8000::/1')
].freeze

class FxzChecker
  def initialize(debug: false, fix: false, netif: nil)
    @debug = debug
    @fix   = fix
    @netif = netif
  end

  def run
    chk_i = @netif || get_fxz_interface
    unless chk_i
      puts 'No FXZ interface found.'
      exit 1
    end

    local_networks_v6 = get_local_ipv6_networks('en0')

    if @debug
      puts "FXZ interface = #{chk_i}"
      puts "Local IPv4 networks = #{LOCAL_NETWORKS_V4.map { |n| to_cidr(n) }}"
      puts "Local IPv6 networks = #{local_networks_v6.map { |n| to_cidr(n) }}"
    end

    fxz_routes = %w[ip_v4 ip_v6].flat_map do |af|
      get_routing_table(af).select { |r| r['dev'] == chk_i }
    end

    local_routes = fxz_routes.select do |route|
      local_route?(route['dst'], LOCAL_NETWORKS_V4, local_networks_v6)
    end

    if @debug
      puts "\nFXZ routes total: #{fxz_routes.length}"
      puts "Local routes to fix: #{local_routes.length}"
      local_routes.each { |r| pp r }
    end

    covered_v4 = covered_indices(local_routes, GATEWAY_NETWORKS_V4)
    covered_v6 = covered_indices(local_routes, local_networks_v6)

    if @debug
      uncovered_v4 = GATEWAY_NETWORKS_V4.each_with_index.reject { |_, i| covered_v4.include?(i) }.map(&:first)
      uncovered_v6 = local_networks_v6.each_with_index.reject { |_, i| covered_v6.include?(i) }.map(&:first)
      puts "Uncovered IPv4 networks (need route add): #{uncovered_v4.map { |n| to_cidr(n) }}" unless uncovered_v4.empty?
      puts "Uncovered IPv6 networks (need route add): #{uncovered_v6.map { |n| to_cidr(n) }}" unless uncovered_v6.empty?
    end

    ipv6_half_defaults = ipv6_half_default_routes(fxz_routes)

    if @fix
      output_fix_commands(local_routes, ipv6_half_defaults, chk_i)
    else
      v4_count = local_routes.count { |r| r['addr_family'] == 'ip_v4' }
      v6_count = local_routes.count { |r| r['addr_family'] == 'ip_v6' }
      puts "#{local_routes.length} Dst Found (IPv4: #{v4_count}, IPv6: #{v6_count})"
      if ipv6_half_defaults.any?
        puts "IPv6 half-default routes via FXZ: #{ipv6_half_defaults.length} (use --fix to remove)"
      end
    end
  end

  private

  def get_routing_table(addr_family)
    opt = addr_family == 'ip_v4' ? '-4' : '-6'
    out, status = Open3.capture2(IP_COMMAND, '-j', opt, 'route')
    return [] unless status.success?

    JSON.parse(out).map { |row| row.merge('addr_family' => addr_family) }
  rescue JSON::ParserError
    []
  end

  def get_fxz_interface
    out, status = Open3.capture2(IP_COMMAND, '-j', 'addr')
    return nil unless status.success?

    JSON.parse(out).each do |iface|
      next unless iface['ifname']&.include?('utun')
      return iface['ifname'] if iface.fetch('addr_info', []).length > 1
    end
    nil
  rescue JSON::ParserError
    nil
  end

  def get_local_ipv6_networks(interface = 'en0')
    out, status = Open3.capture2(IP_COMMAND, '-j', '-6', 'addr', 'show', interface)
    return [] unless status.success?

    networks = []
    JSON.parse(out).each do |iface|
      iface.fetch('addr_info', []).each do |addr_info|
        addr_str  = addr_info['local']
        prefixlen = addr_info['prefixlen'] || 64

        next if addr_str.nil? || addr_str.empty?

        addr = IPAddr.new(addr_str)
        next if addr.link_local?

        # Normalize to /64 if prefix is longer
        prefixlen = 64 if prefixlen > 64
        network = IPAddr.new(addr_str).mask(prefixlen)
        networks << network unless networks.include?(network)
      rescue IPAddr::InvalidAddressError
        next
      end
    end
    networks
  rescue JSON::ParserError
    []
  end

  def local_route?(dst, local_networks_v4, local_networks_v6)
    net = parse_ip_network(dst)
    return false unless net

    if net.ipv4?
      local_networks_v4.any? { |local| subnet_of?(local, net) }
    else
      local_networks_v6.any? { |local| subnet_of?(local, net) }
    end
  end

  def get_default_gateway(fxz_interface)
    get_routing_table('ip_v4').each do |route|
      next unless route['dst'] == 'default'
      next if route['dev'] == fxz_interface

      gw  = route['gateway']
      dev = route['dev']
      return [gw, dev] if gw && dev
    end
    nil
  end

  def covered_indices(local_routes, local_networks)
    covered = Set.new
    local_routes.each do |route|
      net = parse_ip_network(route['dst'])
      next unless net

      local_networks.each_with_index do |local_net, i|
        next unless net.family == local_net.family

        covered.add(i) if subnet_of?(local_net, net)
      end
    end
    covered
  end

  def ipv6_half_default_routes(fxz_routes)
    fxz_routes.select do |route|
      next false unless route['addr_family'] == 'ip_v6'

      net = parse_ip_network(route['dst'])
      next false unless net

      IPV6_HALF_DEFAULTS.any? { |half| net == half }
    end
  end

  def output_fix_commands(local_routes, ipv6_half_defaults, chk_i)
    local_routes.each do |route|
      dst = normalize_dst(route['dst'], route['addr_family'])
      if route['addr_family'] == 'ip_v6'
        puts "ip -6 route del #{dst} dev #{chk_i}"
      else
        puts "ip route del #{dst} dev #{chk_i}"
      end
    end

    ipv6_half_defaults.each do |route|
      dst = normalize_dst(route['dst'], route['addr_family'])
      puts "ip -6 route del #{dst} dev #{chk_i}"
    end

    gw_info = get_default_gateway(chk_i)
    if gw_info
      gw, dev = gw_info
      GATEWAY_NETWORKS_V4.each do |net|
        puts "ip route add #{to_cidr(net)} via #{gw} dev #{dev}"
      end
    end
  end

  # Returns true if child is a subnet of (or equal to) parent
  def subnet_of?(parent, child)
    parent.include?(child.to_range.first) && parent.include?(child.to_range.last)
  end

  def parse_ip_network(dst)
    return nil if dst.nil? || dst == 'default'

    IPAddr.new(dst)
  rescue IPAddr::InvalidAddressError
    nil
  end

  # Remove /32 (IPv4) or /128 (IPv6) suffix from host route destinations
  def normalize_dst(dst, addr_family)
    case addr_family
    when 'ip_v4' then dst.delete_suffix('/32')
    when 'ip_v6' then dst.delete_suffix('/128')
    else dst
    end
  end

  def to_cidr(net)
    "#{net}/#{net.prefix}"
  end
end

def main
  options = { debug: false, fix: false, netif: nil }

  OptionParser.new do |opts|
    opts.banner = 'Usage: check-fxz.rb [options]'

    opts.on('-d', '--debug', 'Show debug info') { options[:debug] = true }
    opts.on('-f', '--fix', 'Generate fix routing commands') { options[:fix] = true }
    opts.on('-i', '--netif INTERFACE', 'Target network interface (auto-detected if omitted)') do |v|
      options[:netif] = v
    end
    opts.on_tail('-h', '--help', 'Show this help') { puts opts; exit 0 }
  end.parse!

  FxzChecker.new(**options).run
end

main if $PROGRAM_NAME == __FILE__
