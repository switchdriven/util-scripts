#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

# uv-tool-maint.rb
# Check and upgrade outdated tools installed via `uv tool install`.

require "json"
require "net/http"
require "optparse"
require "uri"

begin
  require "colorize"
rescue LoadError
  String.class_eval do
    def green = self
    def yellow = self
    def red = self
    def bold = self
    def cyan = self
  end
end

def print_info(msg) = puts "[INFO] #{msg}".green
def print_warn(msg) = puts "[WARN] #{msg}".yellow
def print_error(msg) = puts "[ERROR] #{msg}".red

options = { upgrade: false, interactive: false, targets: [] }

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [OPTIONS] [TOOL...]"
  opts.separator ""
  opts.separator "Check and upgrade outdated tools installed via `uv tool install`."
  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end

  opts.on("-u", "--upgrade", "Upgrade outdated tools (all, or those specified as arguments)") do
    options[:upgrade] = true
  end

  opts.on("-i", "--interactive", "Choose which tools to upgrade interactively") do
    options[:interactive] = true
  end

  opts.separator ""
  opts.separator "EXAMPLES:"
  opts.separator "  #{File.basename($0)}                  # Show outdated tools"
  opts.separator "  #{File.basename($0)} -u               # Upgrade all outdated tools"
  opts.separator "  #{File.basename($0)} -u openai        # Upgrade only openai"
  opts.separator "  #{File.basename($0)} -i               # Choose interactively"
end

parser.parse!
options[:targets] = ARGV.map(&:downcase)

unless system("which uv > /dev/null 2>&1")
  print_error "uv is not installed."
  exit 1
end

# Parse `uv tool list` output
# Format: "<package> v<version>"  (followed by "- <command>" lines)
raw = `uv tool list 2>/dev/null`
tools = raw.lines.filter_map do |line|
  next if line.start_with?("- ")
  next unless line =~ /\A(\S+)\s+v(\d\S*)/
  { name: $1, version: $2 }
end

if tools.empty?
  print_info "No tools installed via `uv tool install`."
  exit 0
end

# Validate -u TOOL arguments
unless options[:targets].empty?
  installed_names = tools.map { |t| t[:name].downcase }
  unknown = options[:targets].reject { |t| installed_names.include?(t) }
  unless unknown.empty?
    print_error "Unknown tool(s): #{unknown.join(", ")}"
    print_error "Installed tools: #{installed_names.join(", ")}"
    exit 1
  end
end

# Fetch latest version from PyPI
def pypi_latest(package_name)
  uri = URI("https://pypi.org/pypi/#{package_name}/json")
  # Temporarily unset HTTP_PROXY (uppercase) to suppress Ruby's deprecation warning.
  # Net::HTTP still respects http_proxy (lowercase) for actual proxy routing.
  saved_proxy = ENV.delete("HTTP_PROXY")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  response = http.get(uri.request_uri)
  return nil unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  data.dig("info", "version")
rescue StandardError
  nil
ensure
  ENV["HTTP_PROXY"] = saved_proxy if saved_proxy
end

print_info "Checking #{tools.size} tool(s) against PyPI..."
puts ""

outdated = []
tools.each do |tool|
  latest = pypi_latest(tool[:name])
  if latest.nil?
    puts "  #{tool[:name].ljust(30)} #{"(PyPI lookup failed)".yellow}"
    next
  end

  if latest == tool[:version]
    puts "  #{tool[:name].ljust(30)} #{tool[:version].ljust(15)} up to date".green
  else
    puts "  #{tool[:name].ljust(30)} #{tool[:version].ljust(15)} -> #{latest}".yellow
    outdated << tool[:name]
  end
end

puts ""

if outdated.empty?
  print_info "All tools are up to date."
  exit 0
end

puts "Outdated: #{outdated.join(", ")}".bold
puts ""

# Determine targets to upgrade
to_upgrade =
  if options[:interactive]
    # Interactive: ask for each outdated tool
    selected = []
    outdated.each do |name|
      print "Upgrade #{name.cyan}? [y/N] "
      answer = $stdin.gets&.strip&.downcase
      selected << name if answer == "y"
    end
    selected
  elsif options[:targets].any?
    # Filter outdated to only requested targets
    not_outdated = options[:targets].reject { |t| outdated.map(&:downcase).include?(t.downcase) }
    unless not_outdated.empty?
      print_warn "Already up to date: #{not_outdated.join(", ")}"
    end
    outdated.select { |name| options[:targets].include?(name.downcase) }
  elsif options[:upgrade]
    outdated
  else
    []
  end

if to_upgrade.nil? || to_upgrade.empty?
  print_warn "No tools selected for upgrade." if options[:interactive] || options[:targets].any?
  print_warn "Dry run: pass -u / --upgrade to upgrade all, or -i to choose interactively." unless options[:upgrade] || options[:interactive]
  exit 0
end

print_info "Upgrading: #{to_upgrade.join(", ")}..."
success = system("uv tool upgrade #{to_upgrade.join(" ")}")

if success
  puts ""
  print_info "Done."
else
  print_error "Some tools failed to upgrade."
  exit 1
end
