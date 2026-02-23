#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Check mDNS / Bonjour status
# Resolves .local hostnames via mDNS multicast, shows DNS cache stats,
# and browses Bonjour service types on the local network.
# Uses standard library only (open3, optparse).
#
# Usage:
#   check-mdns.rb [options] [hostname...]
#
# Options:
#   -H, --health           Show mDNS health check (mDNSResponder, UDP 5353)
#   -c, --cache            Show DNS cache statistics
#   -b, --browse           Browse Bonjour services and instances on local network
#   -f, --flush            Flush DNS cache and restart mDNSResponder (sudo)
#   -t, --timeout SECS     Timeout in seconds (default: 3)
#   -h, --help             Show this help
#

require 'open3'
require 'optparse'

DEFAULT_TIMEOUT = 3

def resolve_mdns(hostname, timeout:)
  fqdn = hostname.include?('.') ? hostname : "#{hostname}.local"

  addresses  = []
  rd, wr     = IO.pipe
  pid        = spawn('/usr/bin/dns-sd', '-G', 'v4v6', fqdn, out: wr, err: File::NULL)
  wr.close

  deadline    = Time.now + timeout
  got_results = false

  loop do
    # Once we have results, wait briefly for more; otherwise wait until deadline
    wait = got_results ? 0.2 : [deadline - Time.now, 0].max
    break if Time.now >= deadline

    ready = IO.select([rd], nil, nil, wait)
    break if ready.nil?

    line = rd.gets
    break if line.nil?
    next unless line.include?(' Add ')
    # Format: timestamp  Add  flags  IF  hostname  address  TTL
    next unless (m = line.match(/\s+Add\s+\S+\s+\S+\s+\S+\s+(\S+)/))

    addr = m[1].sub(/%.*/, '')  # strip IPv6 zone ID (e.g. %<0>)
    addresses << addr unless addresses.include?(addr)
    got_results = true
  end

  begin; Process.kill('TERM', pid); rescue Errno::ESRCH; end
  rd.close
  begin; Process.waitpid(pid); rescue Errno::ECHILD; end

  if addresses.any?
    puts "  #{fqdn} -> #{addresses.join(', ')}"
  else
    puts "  #{fqdn} -> (no answer)"
  end
end

def show_cache_stats
  stdout, stderr, status = Open3.capture3('/usr/bin/dscacheutil', '-statistics')
  unless status.success?
    $stderr.puts "dscacheutil error: #{stderr.strip}"
    return
  end

  output = stdout.strip
  if output.empty?
    # macOS 15+ outputs the message to stderr even on success
    msg = stderr.strip
    puts "  #{msg}" unless msg.empty?
  else
    puts output
  end
end

def dns_sd_browse_raw(type, timeout:)
  rd, wr = IO.pipe
  pid = spawn('/usr/bin/dns-sd', '-B', type, 'local', out: wr, err: File::NULL)
  wr.close

  deadline = Time.now + timeout
  loop do
    remaining = [deadline - Time.now, 0].max
    break if remaining.zero?

    ready = IO.select([rd], nil, nil, remaining)
    break if ready.nil?

    line = rd.gets
    break if line.nil?
    next unless line.include?(' Add ')
    yield line
  end

  begin; Process.kill('TERM', pid); rescue Errno::ESRCH; end
  rd.close
  begin; Process.waitpid(pid); rescue Errno::ECHILD; end
end

def browse_service_types(timeout:)
  # Returns ["_ssh._tcp", "_airplay._tcp", "_asquic._udp", ...]
  # Output format: "timestamp Add flags if .  _tcp.local.  _ssh"
  types = []
  dns_sd_browse_raw('_services._dns-sd._udp', timeout: timeout) do |line|
    next unless (m = line.match(/\s(_(tcp|udp))\.local\.\s+(\S+)\s*$/))
    type = "#{m[3]}.#{m[1]}"  # e.g. "_ssh._tcp"
    types << type unless types.include?(type)
  end
  types
end

def browse_instances(type, timeout:)
  # Returns ["juny-s-mac", "nuc", ...]
  # Output format: "timestamp Add flags if local.  _ssh._tcp.  juny-s-mac"
  instances = []
  dns_sd_browse_raw(type, timeout: timeout) do |line|
    next unless (m = line.match(/\s_\w[\w-]*\._(?:tcp|udp)\.\s+(.+?)\s*$/))
    inst = m[1].strip
    instances << inst unless instances.include?(inst)
  end
  instances
end

def browse_services(timeout:)
  types = browse_service_types(timeout: timeout)

  if types.empty?
    puts '  (no services found)'
    return
  end

  # Collect instances for each type in parallel
  $stderr.puts "Resolving instances for #{types.size} service types (#{timeout}s)..."
  inst_map = {}
  mu      = Mutex.new
  threads = types.map do |type|
    Thread.new do
      instances = browse_instances(type, timeout: timeout)
      mu.synchronize { inst_map[type] = instances }
    end
  end
  threads.each(&:join)

  types.sort.each do |type|
    insts = inst_map[type] || []
    puts "  #{type}"
    insts.sort.each { |inst| puts "    #{inst}" }
  end
end

def healthcheck
  label_w = 16

  # mDNSResponder process
  pids_out, _, pstatus = Open3.capture3('/usr/bin/pgrep', '-x', 'mDNSResponder')
  if pstatus.success? && !pids_out.strip.empty?
    pid = pids_out.strip.lines.first.strip
    puts "  %-#{label_w}s OK   pid #{pid}" % 'mDNSResponder'
  else
    puts "  %-#{label_w}s NG   process not found" % 'mDNSResponder'
  end

  # UDP 5353 listening (netstat doesn't require sudo)
  ns_out, _, _ = Open3.capture3('/usr/sbin/netstat', '-an', '-f', 'inet')
  ns6_out, _, _ = Open3.capture3('/usr/sbin/netstat', '-an', '-f', 'inet6')
  listening = (ns_out + ns6_out).lines.any? { |l| l.match?(/udp.*\*\.5353\s/) }
  if listening
    puts "  %-#{label_w}s OK" % 'UDP :5353'
  else
    puts "  %-#{label_w}s NG   nothing listening" % 'UDP :5353'
  end
end

def flush_cache
  puts 'Flushing DNS cache (sudo required)...'
  ok1 = system('sudo', '/usr/bin/dscacheutil', '-flushcache')
  ok2 = system('sudo', '/usr/bin/killall', '-HUP', 'mDNSResponder')
  if ok1 && ok2
    puts 'Done.'
  else
    $stderr.puts 'Flush failed.'
    exit 1
  end
end

def main
  options = { health: false, cache: false, browse: false, flush: false, timeout: DEFAULT_TIMEOUT }

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: check-mdns.rb [options] [hostname...]'
    opts.separator ''
    opts.separator 'Examples:'
    opts.separator '  check-mdns.rb nuc                # resolve nuc.local via mDNS'
    opts.separator '  check-mdns.rb nuc.local cherry   # resolve multiple hosts'
    opts.separator '  check-mdns.rb -H                 # health check (mDNSResponder, UDP 5353)'
    opts.separator '  check-mdns.rb -c                 # show DNS cache statistics'
    opts.separator '  check-mdns.rb -b -t 5            # browse Bonjour services for 5s'
    opts.separator '  check-mdns.rb -f                 # flush DNS cache (sudo)'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-H', '--health',          'Show mDNS health check')              { options[:health]  = true }
    opts.on('-c', '--cache',           'Show DNS cache statistics')           { options[:cache]   = true }
    opts.on('-b', '--browse',          'Browse Bonjour services and instances') { options[:browse]  = true }
    opts.on('-f', '--flush',           'Flush DNS cache (sudo)')              { options[:flush]   = true }
    opts.on('-t', '--timeout SECS',    "Timeout in seconds (default: #{DEFAULT_TIMEOUT})",
            Integer)                                                           { |v| options[:timeout] = v }
    opts.on_tail('-h', '--help',       'Show this help')                      { puts opts; exit 0 }
  end
  parser.parse!

  hostnames = ARGV

  if hostnames.empty? && options.none? { |k, v| k != :timeout && v }
    puts parser
    exit 0
  end

  if options[:flush]
    flush_cache
    exit 0
  end

  multi   = [options[:health], !hostnames.empty?, options[:cache], options[:browse]].count(true) > 1
  printed = false

  if options[:health]
    puts '=== mDNS Health Check ===' if multi
    healthcheck
    printed = true
  end

  unless hostnames.empty?
    puts '' if printed && multi
    puts '=== mDNS Resolution ===' if multi
    hostnames.each { |h| resolve_mdns(h, timeout: options[:timeout]) }
    printed = true
  end

  if options[:cache]
    puts '' if printed && multi
    puts '=== DNS Cache Statistics ===' if multi
    show_cache_stats
    printed = true
  end

  if options[:browse]
    puts '' if printed && multi
    puts "=== Bonjour Services (#{options[:timeout]}s) ===" if multi
    $stderr.puts "Browsing for #{options[:timeout]} seconds (x2 for instances)..."
    browse_services(timeout: options[:timeout])
  end
end

main if $PROGRAM_NAME == __FILE__
