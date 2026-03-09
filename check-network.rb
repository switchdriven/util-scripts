#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Network Diagnostic Script
# Checks L3 connectivity, DNS, proxy, and web reachability.
#
# Usage:
#   check-network.rb [options]
#
# Options:
#   -i, --interface IFACE   Network interface (default: en10)
#   -a, --arping            Use arping for gateway check instead of ping+ARP cache
#   -h, --help              Show this help
#

require 'open3'
require 'resolv'
require 'socket'
require 'optparse'

WPAD_URL = 'http://wpad.iiji.jp/proxy.pac'

CHECK_SITES = [
  { label: 'ldap-help.iiji.jp  (社内・Proxy不使用)', url: 'https://ldap-help.iiji.jp/', use_proxy: false },
  { label: 'cf.iij-group.jp    (社内・Proxy経由)',    url: 'https://cf.iij-group.jp/',   use_proxy: true  },
  { label: 'www.google.com     (社外・Proxy経由)',     url: 'https://www.google.com/',    use_proxy: true  },
].freeze

GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"
BOLD  = "\e[1m"
RESET = "\e[0m"

$pass = 0
$fail = 0

def section(title)
  puts
  puts "#{BOLD}#{CYAN}## #{title}#{RESET}"
end

def check(label)
  ok, detail = yield
  mark       = ok ? "#{GREEN}OK#{RESET}" : "#{RED}NG#{RESET}"
  suffix     = detail ? " (#{detail})" : ''
  puts "  %-54s %s%s" % [label, mark, suffix]
  ok ? ($pass += 1) : ($fail += 1)
  ok
rescue => e
  puts "  %-54s #{RED}NG#{RESET} (#{e.message})" % label
  $fail += 1
  false
end

# --- helpers ----------------------------------------------------------------

def arp_reachable?(host, iface)
  # Trigger ARP resolution via ping (ICMP reply not required), then check ARP cache for MAC address.
  # This confirms L2 reachability even when the gateway blocks ICMP.
  Open3.capture3('ping', '-c', '1', '-t', '2', '-I', iface, host)
  out, = Open3.capture3('arp', '-n', host)
  mac = out.match(/([0-9a-f]{1,2}(?::[0-9a-f]{1,2}){5})/i)&.[](1)
  mac ? [true, "MAC: #{mac}"] : [false, 'no ARP entry']
end

def arping_reachable?(host, iface)
  # Use arping to send ARP requests directly (requires root on macOS).
  # BSD arping output: "60 bytes from 34:73:2d:c6:3d:82 (10.x.x.x): index=0 ..."
  out, _, st = Open3.capture3('arping', '-c', '1', '-w', '2', '-I', iface, host)
  mac = out.match(/bytes from ([0-9a-f]{1,2}(?::[0-9a-f]{1,2}){5})/i)&.[](1)
  ok  = st.success? && !mac.nil?
  ok ? [true, "MAC: #{mac}"] : [false, 'no ARP reply']
end

def dns_query_ok?(server, hostname = 'www.google.com')
  # Use dig to send an actual DNS query instead of ping
  out, _, st = Open3.capture3('dig', '+time=3', '+tries=1', "@#{server}", hostname)
  st.success? && out.include?('NOERROR')
end

def get_gateway(iface)
  out, = Open3.capture3('netstat', '-rn', '-f', 'inet')
  out.each_line do |line|
    parts = line.split
    return parts[1] if parts[0] == 'default' && parts.last == iface
  end
  nil
end

def get_dns_servers(iface)
  out, = Open3.capture3('ipconfig', 'getoption', iface, 'domain_name_server')
  out.strip.split.select { |s| s.match?(/\A\d+\.\d+\.\d+\.\d+\z/) }
end

def fetch_pac(url)
  out, _, st = Open3.capture3('/usr/bin/curl', '--connect-timeout', '5',
                               '--max-time', '10', '-sf', url)
  st.success? && !out.empty? ? out : nil
end

def parse_proxy(pac)
  m = pac.match(/PROXY\s+([a-zA-Z0-9._-]+):(\d+)/)
  m ? [m[1], m[2].to_i] : nil
end

def fetch_url(url, proxy_host: nil, proxy_port: nil)
  args = %w[/usr/bin/curl --connect-timeout 5 --max-time 10 -sk
            -o /dev/null -w %{http_code}]
  args += ['--proxy', "http://#{proxy_host}:#{proxy_port}"] if proxy_host
  args << url
  out, _, st = Open3.capture3(*args)
  code = out.strip.to_i
  ok   = st.success? && code.positive? && code < 500
  [ok, "HTTP #{code}"]
end

# --- main -------------------------------------------------------------------

def run(iface, use_arping: false)
  puts
  puts "#{BOLD}Network Diagnostic  [interface: #{iface}]#{RESET}"
  puts '=' * 60

  # Interface
  section 'Interface'
  check("#{iface} is up") do
    out, = Open3.capture3('ifconfig', iface)
    active = out.include?('status: active')
    ip     = out.match(/inet (\d+\.\d+\.\d+\.\d+)/)&.[](1)
    [active, ip ? "IP: #{ip}" : 'no IP assigned']
  end

  # L3
  section 'L3 Connectivity'
  gw = get_gateway(iface)
  if gw
    if use_arping
      check("Default gateway #{gw} reachable (arping)") { arping_reachable?(gw, iface) }
    else
      check("Default gateway #{gw} reachable (ARP)") { arp_reachable?(gw, iface) }
    end
  else
    check('Default gateway reachable') { [false, "no default route found for #{iface}"] }
  end

  # DNS
  section 'DNS'
  dns_servers = get_dns_servers(iface)
  if dns_servers.empty?
    check('DNS server reachable (query)') { [false, 'no DNS servers received via DHCP'] }
  else
    dns_servers.each do |srv|
      check("DNS server #{srv} answers query") { [dns_query_ok?(srv), nil] }
    end
  end
  check('Name resolution  www.google.com') do
    addr = Resolv.getaddress('www.google.com')
    [true, addr]
  rescue Resolv::ResolvError => e
    [false, e.message]
  end

  # Proxy
  section 'Proxy'
  proxy_host = nil
  proxy_port = nil
  pac_content = nil

  pac_ok = check("WPAD PAC accessible") do
    pac_content = fetch_pac(WPAD_URL)
    [!pac_content.nil?, WPAD_URL]
  end

  if pac_ok
    proxy = parse_proxy(pac_content)
    if proxy
      proxy_host, proxy_port = proxy
      check("Proxy #{proxy_host}:#{proxy_port} reachable (TCP)") do
        Socket.tcp(proxy_host, proxy_port, connect_timeout: 5) { |s| s.close }
        [true, nil]
      end
    else
      check('Proxy server reachable') { [false, 'PROXY entry not found in PAC'] }
    end
  end

  # Web
  section 'Web Connectivity'
  CHECK_SITES.each do |site|
    ph = site[:use_proxy] ? proxy_host : nil
    pp = site[:use_proxy] ? proxy_port : nil
    check(site[:label]) { fetch_url(site[:url], proxy_host: ph, proxy_port: pp) }
  end

  # Summary
  puts
  puts '=' * 60
  total = $pass + $fail
  color = $fail.zero? ? GREEN : RED
  puts "#{BOLD}Result: #{color}#{$pass}/#{total} passed#{RESET}"
  puts
end

options = { interface: 'en10', arping: false }
OptionParser.new do |opts|
  opts.banner = 'Usage: check-network.rb [options]'
  opts.separator ''
  opts.separator 'Options:'
  opts.on('-i', '--interface IFACE', 'Network interface to check (default: en10)') { |v| options[:interface] = v }
  opts.on('-a', '--arping',          'Use arping for gateway check (requires root)') { options[:arping] = true }
  opts.on_tail('-h', '--help',       'Show this help') { puts opts; exit 0 }
end.parse!

run(options[:interface], use_arping: options[:arping])
