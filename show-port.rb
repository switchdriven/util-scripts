#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Show network connections and listening ports
# Displays open network connections using lsof.
# Uses standard library only (open3, optparse).
#
# Usage:
#   show-port.rb [options]
#
# Options:
#   -d, --debug       Show debug info
#   -l, --listen      Show only listening ports
#   -h, --help        Show this help
#

require 'open3'
require 'optparse'

LSOF_CMD = ['/usr/sbin/lsof', '-i', '+c0', '-nPR'].freeze

def main
  options = { debug: false, listen: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: show-port.rb [options]'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-d', '--debug',  'Show debug info')         { options[:debug]  = true }
    opts.on('-l', '--listen', 'Show only listening ports') { options[:listen] = true }
    opts.on_tail('-h', '--help', 'Show this help')       { puts opts; exit 0 }
  end.parse!

  $stderr.puts "Cmd = #{LSOF_CMD}" if options[:debug]

  stdout, _stderr, status = Open3.capture3(*LSOF_CMD)
  unless status.success?
    $stderr.puts 'error on exec lsof'
    exit 1
  end

  lines = stdout.strip.split("\n")
  puts lines.first if options[:debug]

  lines[1..].each do |line|
    next if options[:listen] && !line.include?('LISTEN')

    puts line
  end
end

main if $PROGRAM_NAME == __FILE__
