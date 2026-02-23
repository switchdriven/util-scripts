#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

#
# Extract network services from macOS networksetup command
# Parses networksetup -listnetworkserviceorder output to list service/device pairs.
# Uses standard library only (open3, optparse, json).
#
# Usage:
#   network-extractor.rb [options] [file]
#
# Options:
#   -j, --json        Output in JSON format
#   -a, --autoproxy   Include auto proxy information
#   -h, --help        Show this help
#

require 'open3'
require 'optparse'
require 'json'

def parse_network_services(text)
  services = []
  current_service = nil

  text.strip.each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?('An asterisk')

    if (m = line.match(/\A\(\d+\)\s*(.+)/))
      current_service = m[1].strip
    elsif line.start_with?('(Hardware Port:') && current_service
      device_match = line.match(/Device:\s*([^)]*)/)
      device_name = device_match ? device_match[1].strip : ''
      services << { service_name: current_service, device_name: device_name }
      current_service = nil
    end
  end

  services
end

def get_autoproxy_info(service_name)
  stdout, _stderr, status = Open3.capture3('networksetup', '-getautoproxyurl', service_name)
  return { url: '', enabled: false, error: 'Failed to get proxy info' } unless status.success?

  info = {}
  stdout.strip.each_line do |line|
    if line.start_with?('URL:')
      info[:url] = line.sub('URL:', '').strip
    elsif line.start_with?('Enabled:')
      info[:enabled] = line.sub('Enabled:', '').strip.downcase == 'yes'
    end
  end
  info
rescue StandardError
  { url: '', enabled: false, error: 'Unknown error' }
end

def enrich_with_autoproxy(services)
  services.map { |svc| svc.merge(autoproxy: get_autoproxy_info(svc[:service_name])) }
end

def print_services(services, json_output:, include_autoproxy:)
  if json_output
    output = {
      network_services: services.map do |svc|
        h = { service_name: svc[:service_name], device_name: svc[:device_name] }
        h[:autoproxy] = svc[:autoproxy] if include_autoproxy
        h
      end,
      total_count: services.size
    }
    puts JSON.pretty_generate(output)
  elsif include_autoproxy
    puts "Network Services with Auto Proxy (#{services.size} services):"
    puts '-' * 90
    puts format('%-25s %-15s %-30s %-10s', 'Service Name', 'Device Name', 'Proxy URL', 'Enabled')
    puts '-' * 90
    services.each do |svc|
      proxy = svc[:autoproxy]
      if proxy[:error]
        url     = "(#{proxy[:error]})"
        enabled = 'N/A'
      else
        url     = proxy[:url]
        enabled = proxy[:enabled] ? 'Yes' : 'No'
      end
      puts format('%-25s %-15s %-30s %-10s', svc[:service_name], svc[:device_name], url, enabled)
    end
  else
    puts "Network Services (#{services.size} services):"
    puts '-' * 60
    puts format('%-30s %-20s', 'Service Name', 'Device Name')
    puts '-' * 60
    services.each do |svc|
      puts format('%-30s %-20s', svc[:service_name], svc[:device_name])
    end
  end
end

def main
  options = { json: false, autoproxy: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: show-services.rb [options] [file]'
    opts.separator ''
    opts.separator 'Options:'

    opts.on('-j', '--json',      'Output in JSON format')           { options[:json]      = true }
    opts.on('-a', '--autoproxy', 'Include auto proxy information')  { options[:autoproxy] = true }
    opts.on_tail('-h', '--help', 'Show this help')                  { puts opts; exit 0 }
  end.parse!

  text = if ARGV[0]
    begin
      File.read(ARGV[0], encoding: 'utf-8')
    rescue Errno::ENOENT
      $stderr.puts "File '#{ARGV[0]}' not found."
      exit 1
    rescue StandardError => e
      $stderr.puts "File read error: #{e}"
      exit 1
    end
  else
    stdout, _stderr, status = Open3.capture3('networksetup', '-listnetworkserviceorder')
    unless status.success?
      $stderr.puts 'Command execution error: networksetup failed'
      exit 1
    end
    stdout
  end

  services = parse_network_services(text)

  if services.empty?
    $stderr.puts 'No network services found.'
    exit 1
  end

  services = enrich_with_autoproxy(services) if options[:autoproxy]

  print_services(services, json_output: options[:json], include_autoproxy: options[:autoproxy])
end

main if $PROGRAM_NAME == __FILE__
