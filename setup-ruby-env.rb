#!/usr/bin/env ruby
# frozen_string_literal: true

# setup-ruby-env.rb
# Sets up a Ruby project with Bundler and direnv auto-activation

require "fileutils"
require "optparse"
require "pathname"

begin
  require "colorize"
rescue LoadError
  # Fallback if colorize is not available
  String.class_eval do
    def colorize(color)
      self
    end

    def green
      colorize(:green)
    end

    def red
      colorize(:red)
    end

    def yellow
      colorize(:yellow)
    end

    def bold
      self
    end
  end
end

class SetupRubyEnv
  DEFAULT_VENV_DIR = ".venv"
  DEFAULT_RUBY_VERSION = "3.3"
  MCP_CONFIGS = ["work", "personal"].freeze

  def initialize
    @venv_dir = DEFAULT_VENV_DIR
    @ruby_version = DEFAULT_RUBY_VERSION
    @mcp_config = ""
    @project_dir = "."
  end

  def run
    parse_arguments
    setup_project_dir
    check_requirements
    create_venv
    setup_bundler
    setup_mcp
    setup_direnv
    create_project_structure
    create_gitignore
    print_summary
  end

  private

  def parse_arguments
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: setup-ruby-env.rb [OPTIONS] [PROJECT_DIR]"
      opts.separator ""
      opts.separator "Sets up a Ruby development environment with Bundler and direnv."
      opts.separator ""
      opts.separator "OPTIONS:"

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit 0
      end

      opts.on("-v", "--ruby-version VERSION", "Ruby version to use (default: #{DEFAULT_RUBY_VERSION})") do |v|
        @ruby_version = v
      end

      opts.on("-d", "--venv-dir DIR", "Virtual environment directory name (default: #{DEFAULT_VENV_DIR})") do |d|
        @venv_dir = d
      end

      opts.on("-m", "--mcp CONFIG", "MCP configuration: 'work' or 'personal'") do |m|
        unless MCP_CONFIGS.include?(m)
          print_error "Invalid MCP config: #{m} (must be 'work' or 'personal')"
          exit 1
        end
        @mcp_config = m
      end

      opts.separator ""
      opts.separator "ARGUMENTS:"
      opts.separator "  PROJECT_DIR             Directory to setup (default: current directory)"
      opts.separator ""
      opts.separator "EXAMPLES:"
      opts.separator "  #{File.basename($0)}                           # Setup in current directory"
      opts.separator "  #{File.basename($0)} my-project                # Setup in ./my-project"
      opts.separator "  #{File.basename($0)} --ruby-version 3.2        # Use Ruby 3.2"
      opts.separator "  #{File.basename($0)} --mcp work                # Setup with work GitHub MCP config"
      opts.separator ""
      opts.separator "REQUIREMENTS:"
      opts.separator "  - Ruby 3.0+ with Bundler"
      opts.separator "  - direnv: Environment switcher (https://direnv.net/)"
    end

    parser.parse!

    @project_dir = ARGV[0] || "."
  end

  def setup_project_dir
    unless Dir.exist?(@project_dir)
      print_info "Creating project directory: #{@project_dir}"
      FileUtils.mkdir_p(@project_dir)
    end

    Dir.chdir(@project_dir)
    @project_dir = Dir.pwd
    print_info "Working in: #{@project_dir}"
  end

  def check_requirements
    print_info "Checking requirements..."

    unless command_exists?("ruby")
      print_error "Ruby is not installed. Please install Ruby first."
      exit 1
    end

    unless command_exists?("bundle")
      print_error "Bundler is not installed. Please install it first:"
      puts "  gem install bundler"
      exit 1
    end

    unless command_exists?("direnv")
      print_error "direnv is not installed. Please install it first:"
      puts "  macOS: brew install direnv"
      puts "  Then add to your shell config: eval \"$(direnv hook bash)\" or eval \"$(direnv hook zsh)\""
      exit 1
    end

    print_info "All requirements satisfied ✓"
  end

  def create_venv
    if Dir.exist?(@venv_dir)
      print_warn "Virtual environment already exists at #{@venv_dir}"
      return if !prompt_yes?("Do you want to recreate it?")

      print_info "Removing existing virtual environment..."
      FileUtils.rm_rf(@venv_dir)
    end

    print_info "Creating virtual environment with Ruby #{@ruby_version}..."
    system("ruby -m venv #{@venv_dir}")
    print_info "Virtual environment created at #{@venv_dir} ✓"
  rescue StandardError => e
    print_error "Failed to create virtual environment: #{e.message}"
    exit 1
  end

  def setup_bundler
    print_info "Setting up Bundler..."

    unless File.exist?("Gemfile")
      print_info "No Gemfile found, creating a basic one..."
      create_basic_gemfile
    end

    print_info "Installing gems with Bundler..."
    system("bundle install --local") || system("bundle install")
    print_info "Bundler configured ✓"
  rescue StandardError => e
    print_error "Failed to setup Bundler: #{e.message}"
    exit 1
  end

  def create_basic_gemfile
    gemfile_content = <<~GEMFILE
      # frozen_string_literal: true

      source "https://rubygems.org"

      ruby "#{@ruby_version}"

      # Add your gems here
    GEMFILE

    File.write("Gemfile", gemfile_content)
    print_info "Created Gemfile ✓"
  end

  def setup_mcp
    return if @mcp_config.empty?

    unless command_exists?("claude")
      print_error "claude CLI is not installed. MCP setup requires Claude Code."
      print_info "Please install Claude Code first: https://claude.ai/download"
      return
    end

    wrapper_script, server_name = mcp_config_paths

    unless File.exist?(wrapper_script)
      print_error "MCP wrapper script not found: #{wrapper_script}"
      return
    end

    if mcp_server_configured?(server_name)
      print_info "MCP server '#{server_name}' is already configured ✓"
      return
    end

    print_info "Adding MCP server '#{server_name}'..."
    if system("claude mcp add --transport stdio #{server_name} -- #{wrapper_script}")
      print_info "MCP server '#{server_name}' added successfully ✓"
    else
      print_error "Failed to add MCP server '#{server_name}'"
    end
  end

  def mcp_config_paths
    scripts_dir = File.expand_path("~/Scripts/Shell")
    case @mcp_config
    when "work"
      ["#{scripts_dir}/run-github-mcp-work.sh", "github-work"]
    when "personal"
      ["#{scripts_dir}/run-github-mcp-personal.sh", "github-personal"]
    end
  end

  def mcp_server_configured?(server_name)
    output = `claude mcp list 2>/dev/null`
    output.include?(server_name)
  rescue StandardError
    false
  end

  def setup_direnv
    envrc_file = ".envrc"
    new_content = generate_envrc_content

    if File.exist?(envrc_file)
      current_content = File.read(envrc_file)
      unless current_content == new_content
        print_warn ".envrc already exists"
        puts "Current content:"
        puts current_content.split("\n").map { |line| "  #{line}" }.join("\n")
        puts ""
        puts "New content:"
        puts new_content.split("\n").map { |line| "  #{line}" }.join("\n")
        puts ""

        return unless prompt_yes?("Do you want to replace it?")
      else
        print_info ".envrc already up to date ✓"
        return
      end
    end

    File.write(envrc_file, new_content)
    print_info "Created .envrc ✓"

    print_info "Allowing direnv for this directory..."
    system("direnv allow")
    print_info "direnv configured ✓"
  rescue StandardError => e
    print_error "Failed to setup direnv: #{e.message}"
  end

  def generate_envrc_content
    content = ""

    # Ruby environment setup
    content += "# Ruby environment\n"
    content += "source #{@venv_dir}/bin/activate.sh\n"
    content += "\n"

    # GitHub tokens for MCP if configured
    unless @mcp_config.empty?
      content += "# GitHub API tokens and username for MCP\n"
      case @mcp_config
      when "work"
        content += 'export GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")' + "\n"
        content += 'export GITHUB_USERNAME="juny-s"' + "\n"
      when "personal"
        content += 'export GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHub For MCP/token")' + "\n"
        content += 'export GITHUB_USERNAME="switchdriven"' + "\n"
      end
    end

    content
  end

  def create_project_structure
    create_gemfile_if_missing
    create_readme_if_missing
  end

  def create_gemfile_if_missing
    return if File.exist?("Gemfile")

    return unless prompt_yes?("Do you want to create a basic Gemfile?")

    create_basic_gemfile
  end

  def create_readme_if_missing
    return if File.exist?("README.md")

    return unless prompt_yes?("Do you want to create a basic README.md?")

    project_name = File.basename(@project_dir)
    readme_content = <<~README
      # #{project_name}

      ## Setup

      This project uses `Bundler` for dependency management and `direnv` for automatic environment activation.

      ### Prerequisites

      - Ruby 3.0+ with Bundler
      - [direnv](https://direnv.net/)

      ### Installation

      The development environment is already configured. Simply enter the directory and direnv will automatically activate the environment.

      ```bash
      cd #{project_name}
      # Environment is automatically activated by direnv
      ```

      ### Installing Dependencies

      ```bash
      bundle install
      ```

    README

    File.write("README.md", readme_content)
    print_info "Created README.md ✓"
  end

  def create_gitignore
    return if File.exist?(".gitignore")

    return unless prompt_yes?("Do you want to create a .gitignore file?")

    gitignore_content = <<~GITIGNORE
      # Ruby
      *.gem
      *.rbc
      .bundle/
      .gems/
      Gemfile.lock
      .ruby-version

      # Virtual environments
      #{@venv_dir}/
      venv/
      env/
      ENV/

      # direnv
      .envrc
      .direnv/

      # IDE
      .vscode/
      .idea/
      *.swp
      *.swo
      *~

      # OS
      .DS_Store
      .AppleDouble
      .LSOverride

      # Logs
      *.log

      # Temporary files
      *.tmp
      *.bak
      *.backup
    GITIGNORE

    File.write(".gitignore", gitignore_content)
    print_info "Created .gitignore ✓"
  end

  def print_summary
    puts ""
    print_info "=========================================".bold
    print_info "Setup completed successfully! 🎉".green
    print_info "=========================================".bold
    puts ""
    print_info "Next steps:"
    puts "  1. cd #{@project_dir}"
    puts "  2. Install dependencies: bundle install"
    puts "  3. Start coding!"
    puts ""
    print_info "The environment will be automatically activated when you enter the directory."

    unless @mcp_config.empty?
      puts ""
      print_info "MCP Configuration:"
      puts "  - Config: #{@mcp_config}"
      puts "  - Server: #{@mcp_config == 'work' ? 'github-work (GitHub Enterprise)' : 'github-personal (GitHub.com)'}"
      puts "  - Check status: claude mcp list"
    end
  end

  def command_exists?(cmd)
    system("which #{cmd} > /dev/null 2>&1")
  end

  def prompt_yes?(question)
    print "#{question} (y/N): "
    answer = $stdin.gets.chomp
    answer.downcase.start_with?("y")
  end

  def print_info(message)
    puts "[INFO] #{message}".green
  end

  def print_warn(message)
    puts "[WARN] #{message}".yellow
  end

  def print_error(message)
    puts "[ERROR] #{message}".red
  end
end

# Run the setup
SetupRubyEnv.new.run if __FILE__ == $0
