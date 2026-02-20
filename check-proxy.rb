#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Check proxy connectivity
# Tests HTTP connection via specified proxy server.
# Uses standard library only (open3, optparse).
#
# Usage:
#   check-proxy.rb [options]
#
# Options:
#   -d, --debug           Show debug info
#   -p, --proxy URL       Set proxy server URL
#   -n, --name NAME       Proxy server name from built-in list
#   -l, --list            Show known proxies
#   -i, --isp             Check which ISP the connection uses
#   -h, --help            Show this help
#

require 'open3'
require 'optparse'

PROXY_SERVERS = [
  { name: 'none',   url: 'none' },                          # no proxy
  { name: 'socks',  url: 'socks://nuc.local:3228' },        # nuc.local socks
  { name: 'squid',  url: 'http://nuc.local:3128' },         # nuc.local squid
  { name: 'local',  url: 'http://localhost:3128' },         # localhost squid
  { name: 'office', url: 'http://proxy.iiji.jp:8080' },     # IIJ Office proxy
].freeze

TEST_TARGET   = 'https://www.google.com'
DETAIL_TARGET = 'https://env.b4iine.net'
TEMP_BODY     = '/tmp/curl.out'

def parse_isp_from_html(path)
  html = File.read(path, encoding: 'utf-8')
  # Locate first env_1box block, then extract txt content (strip inner tags)
  start = html.index('<div class="env_1box">')
  raise "env_1box not found in #{path}" unless start

  txt_match = html[start..].match(/<div[^>]+class="txt"[^>]*>(.*?)<\/div>/m)
  raise "txt not found in #{path}" unless txt_match

  txt_match[1].gsub(/<[^>]+>/, '').strip
rescue StandardError => e
  raise "error on reading from #{path}: #{e}"
end

def main
  options = { debug: false, proxy: nil, name: nil, list: false, isp: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: check-proxy.rb [options]'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-d', '--debug',        'Show debug info')            { options[:debug] = true }
    opts.on('-p', '--proxy URL',    'Set proxy server URL')       { |v| options[:proxy] = v }
    opts.on('-n', '--name NAME',    'Proxy server name from list',
            PROXY_SERVERS.map { |s| s[:name] })                   { |v| options[:name] = v }
    opts.on('-l', '--list',         'Show known proxies')         { options[:list] = true }
    opts.on('-i', '--isp',          'Check which ISP is in use')  { options[:isp] = true }
    opts.on_tail('-h', '--help',    'Show this help')             { puts opts; exit 0 }
  end.parse!

  if options[:list]
    PROXY_SERVERS.each { |s| puts "%-8s %s" % [s[:name], s[:url]] }
    return
  end

  proxy_url = if options[:name]
    entry = PROXY_SERVERS.find { |s| s[:name] == options[:name] }
    $stderr.puts "Unknown proxy name: #{options[:name]}" unless entry
    entry&.fetch(:url)
  elsif options[:proxy]
    options[:proxy]
  else
    PROXY_SERVERS.first[:url]
  end

  debug_source = options[:name] ? 'name option' : (options[:proxy] ? 'proxy option' : 'default')
  puts "Set proxy to #{proxy_url} by #{debug_source}" if options[:debug]

  target_url = options[:isp] ? DETAIL_TARGET : TEST_TARGET
  body_out   = options[:isp] ? TEMP_BODY     : '/dev/null'

  puts "Trying #{target_url} via proxy #{proxy_url} ... " if options[:debug]

  proxy_args = proxy_url == 'none' ? [] : ['--proxy', proxy_url]
  cmd = ['/usr/bin/curl', '--connect-timeout', '5', '-s',
         *proxy_args, '-o', body_out, '-w', '%{http_code}\n', target_url]

  output, status = Open3.capture2e(*cmd)
  code = status.success? ? output.lines.first&.strip.to_i : 0

  if code == 200
    if options[:isp]
      begin
        isp = parse_isp_from_html(TEMP_BODY)
        puts "OK/#{isp}"
      rescue StandardError => e
        puts e.message
      end
    else
      puts 'OK'
    end
  else
    puts "NG (#{code})"
  end
end

main if $PROGRAM_NAME == __FILE__
