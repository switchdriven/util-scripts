#!/opt/homebrew/opt/ruby@3.3/bin/ruby
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

class FxzChecker
  def initialize(debug: false, fix: false, netif: nil)
    @debug = debug
    @fix   = fix
    @netif = netif
  end

  def run
    chk_i = @netif || get_fxz_interface
    unless chk_i
      warn 'No FXZ interface found.'
      exit 1
    end

    if @debug
      warn "FXZ interface = #{chk_i}"
      warn "Local IPv4 networks = #{LOCAL_NETWORKS_V4.map { |n| to_cidr(n) }}"
    end

    fxz_routes = %w[ip_v4 ip_v6].flat_map do |af|
      get_routing_table(af).select { |r| r['dev'] == chk_i }
    end

    # IPv4: only routes that fall within defined local networks
    local_routes_v4 = fxz_routes.select do |route|
      route['addr_family'] == 'ip_v4' && local_route_v4?(route['dst'])
    end

    # IPv6: all routes via FXZ interface are removed (FXZ hijacks all IPv6 traffic).
    # Exclude link-local (fe80::/10) and multicast (ff00::/8) — interface-scoped, cannot be deleted.
    all_routes_v6 = fxz_routes.select do |r|
      next false unless r['addr_family'] == 'ip_v6'

      net = parse_ip_network(r['dst'])
      net && !net.link_local? && !IPAddr.new('ff00::/8').include?(net)
    end

    if @debug
      warn "\nFXZ routes total: #{fxz_routes.length}"
      warn "Local IPv4 routes to fix: #{local_routes_v4.length}"
      warn "IPv6 routes to remove (all): #{all_routes_v6.length}"
      local_routes_v4.each { |r| warn r.inspect }
      all_routes_v6.each { |r| warn r.inspect }
    end

    if @debug
      covered_v4 = covered_indices(local_routes_v4, GATEWAY_NETWORKS_V4)
      uncovered_v4 = GATEWAY_NETWORKS_V4.each_with_index.reject { |_, i| covered_v4.include?(i) }.map(&:first)
      warn "Uncovered IPv4 networks (need route add): #{uncovered_v4.map { |n| to_cidr(n) }}" unless uncovered_v4.empty?
    end

    if @fix
      output_fix_commands(local_routes_v4, all_routes_v6, chk_i)
    else
      puts "IPv4: #{local_routes_v4.length} local route(s) via FXZ"
      puts "IPv6: #{all_routes_v6.length} route(s) via FXZ (all will be removed with --fix)"
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

  def local_route_v4?(dst)
    net = parse_ip_network(dst)
    return false unless net&.ipv4?

    LOCAL_NETWORKS_V4.any? { |local| subnet_of?(local, net) }
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

  def output_fix_commands(local_routes_v4, all_routes_v6, chk_i)
    return if local_routes_v4.empty? && all_routes_v6.empty?

    local_routes_v4.each do |route|
      dst = normalize_dst(route['dst'], 'ip_v4')
      puts "ip route del #{dst} dev #{chk_i}"
    end

    all_routes_v6.each do |route|
      dst = normalize_dst(route['dst'], 'ip_v6')
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
