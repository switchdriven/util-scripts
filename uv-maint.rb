#!/opt/homebrew/opt/ruby@3.3/bin/ruby
# frozen_string_literal: true

# uv-maint.rb
# Manage packages in a uv-managed virtual environment:
#   - Show/upgrade outdated packages
#   - Check dependency integrity
#   - Find leaf (unrequired) packages

require "json"
require "optparse"

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

DEFAULT_VENV = ENV["VIRTUAL_ENV"] || File.expand_path("~/Scripts/.venv")

def print_info(msg) = puts "[INFO] #{msg}".green
def print_warn(msg) = puts "[WARN] #{msg}".yellow
def print_error(msg) = puts "[ERROR] #{msg}".red

options = {
  venv: DEFAULT_VENV,
  upgrade: false,
  check: false,
  leaves: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [OPTIONS]"
  opts.separator ""
  opts.separator "Manage packages in a uv-managed virtual environment."
  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end

  opts.on("-p", "--venv PATH", "Path to virtual environment (default: #{DEFAULT_VENV})") do |v|
    options[:venv] = File.expand_path(v)
  end

  opts.on("-u", "--upgrade", "Upgrade all outdated packages") do
    options[:upgrade] = true
  end

  opts.on("-c", "--check", "Check dependency integrity") do
    options[:check] = true
  end

  opts.on("-l", "--leaves", "Show leaf packages (not required by others) and optionally uninstall") do
    options[:leaves] = true
  end

  opts.separator ""
  opts.separator "EXAMPLES:"
  opts.separator "  #{File.basename($0)}                       # Show outdated packages"
  opts.separator "  #{File.basename($0)} -u                    # Upgrade all outdated packages"
  opts.separator "  #{File.basename($0)} -c                    # Check dependency integrity"
  opts.separator "  #{File.basename($0)} -l                    # Show leaf packages (interactive uninstall)"
  opts.separator "  #{File.basename($0)} -p /path/to/.venv -u  # Upgrade in another venv"
end

parser.parse!

venv_path = options[:venv]
python_bin = File.join(venv_path, "bin", "python")

unless system("which uv > /dev/null 2>&1")
  print_error "uv is not installed."
  exit 1
end

unless File.exist?(python_bin)
  print_error "Virtual environment not found: #{venv_path}"
  exit 1
end

# --check: dependency integrity
if options[:check]
  print_info "Checking dependency integrity in #{venv_path}..."
  puts ""
  system("uv pip check --python \"#{python_bin}\"")
  exit $?.exitstatus
end

# --leaves: find and optionally uninstall leaf packages
if options[:leaves]
  print_info "Scanning packages in #{venv_path}..."

  all_output = `uv pip list --python "#{python_bin}" --format json 2>/dev/null`
  all_packages = JSON.parse(all_output).map { |p| p["name"] }

  show_output = `uv pip show #{all_packages.join(" ")} --python "#{python_bin}" 2>/dev/null`

  # Parse "Required-by" from pip show output (records separated by ---)
  leaves = show_output.split(/^---\n?/).filter_map do |record|
    name = record[/^Name:\s*(.+)/, 1]&.strip
    required_by = record[/^Required-by:\s*(.*)/, 1]&.strip
    name if name && (required_by.nil? || required_by.empty?)
  end

  if leaves.empty?
    print_info "No leaf packages found."
    exit 0
  end

  puts ""
  puts "Leaf packages (not required by any other package):".bold
  leaves.each do |name|
    puts "  #{name}".cyan
  end
  puts ""
  puts "To uninstall:".bold
  puts "  uv pip uninstall #{leaves.join(" ")} --python \"#{python_bin}\""

  exit 0
end

# Default: show outdated packages (and upgrade if -u)
print_info "Checking outdated packages in #{venv_path}..."

output = `uv pip list --outdated --python "#{python_bin}" --format json 2>/dev/null`

begin
  packages = JSON.parse(output)
rescue JSON::ParserError => e
  print_error "Failed to parse package list: #{e.message}"
  exit 1
end

if packages.empty?
  print_info "All packages are up to date."
  exit 0
end

puts ""
puts "Outdated packages:".bold
puts "  #{"Package".ljust(25)} #{"Current".ljust(15)} Latest"
puts "  #{"-" * 55}"
packages.each do |pkg|
  name = pkg["name"].ljust(25)
  current = pkg["version"].ljust(15)
  latest = pkg["latest_version"]
  puts "  #{name} #{current} #{latest}".yellow
end
puts ""

unless options[:upgrade]
  print_warn "Dry run: pass -u / --upgrade to actually upgrade."
  exit 0
end

package_names = packages.map { |p| p["name"] }
print_info "Upgrading #{package_names.size} package(s)..."

success = system("uv pip install --upgrade #{package_names.join(" ")} --python \"#{python_bin}\"")

if success
  puts ""
  print_info "All packages upgraded successfully."
else
  print_error "Some packages failed to upgrade."
  exit 1
end
