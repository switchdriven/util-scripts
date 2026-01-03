#!/usr/bin/env ruby
# frozen_string_literal: true

# setup-env.rb
# Sets up development environments (Python/Ruby) with direnv auto-activation
# Supports automatic language detection and explicit language selection

require "fileutils"
require "optparse"
require "pathname"
require "json"

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

# Common helper methods for all strategies
module CommonHelpers
  def command_exists?(cmd)
    system("which #{cmd} > /dev/null 2>&1")
  end

  def prompt_yes?(question)
    print "#{question} (y/N): "
    answer = $stdin.gets
    return false if answer.nil? # Non-interactive mode, default to no
    answer.chomp.downcase.start_with?("y")
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

# Base module for language strategies
module LanguageStrategy
  def language_name
    raise NotImplementedError
  end

  def default_version
    raise NotImplementedError
  end

  def detect_existing_project?
    raise NotImplementedError
  end

  def check_language_requirements
    raise NotImplementedError
  end

  def create_venv(venv_dir, version)
    raise NotImplementedError
  end

  def setup_language_specific(venv_dir)
    # Optional: Override if language needs additional setup
  end

  def generate_venv_activation_line(venv_dir)
    raise NotImplementedError
  end

  def create_project_files(project_dir, version)
    raise NotImplementedError
  end

  def generate_gitignore(venv_dir)
    raise NotImplementedError
  end

  def summary_next_steps
    raise NotImplementedError
  end
end

# Python-specific setup strategy
class PythonStrategy
  include CommonHelpers
  include LanguageStrategy

  DEFAULT_VERSION = "3.13"

  def language_name
    "Python"
  end

  def default_version
    DEFAULT_VERSION
  end

  def detect_existing_project?
    File.exist?("pyproject.toml")
  end

  def check_language_requirements
    unless command_exists?("uv")
      print_error "uv is not installed. Please install it first:"
      puts "  curl -LsSf https://astral.sh/uv/install.sh | sh"
      exit 1
    end
  end

  def create_venv(venv_dir, version)
    if Dir.exist?(venv_dir)
      print_warn "Virtual environment already exists at #{venv_dir}"
      return if !prompt_yes?("Do you want to recreate it?")

      print_info "Removing existing virtual environment..."
      FileUtils.rm_rf(venv_dir)
    end

    print_info "Creating virtual environment with Python #{version}..."
    system("uv venv #{venv_dir} --python #{version}")
    print_info "Virtual environment created at #{venv_dir} ✓"
  rescue StandardError => e
    print_error "Failed to create virtual environment: #{e.message}"
    exit 1
  end

  def setup_language_specific(venv_dir)
    # Python doesn't need additional setup beyond venv
  end

  def generate_venv_activation_line(venv_dir)
    "source #{venv_dir}/bin/activate\n"
  end

  def create_project_files(project_dir, version)
    create_pyproject_if_missing(project_dir, version)
    create_readme_if_missing(project_dir)
  end

  def generate_gitignore(venv_dir)
    <<~GITIGNORE
      # Python
      __pycache__/
      *.py[cod]
      *.pyc
      *.so
      .Python

      # Virtual environments
      #{venv_dir}/
      venv/
      env/
      ENV/

      # direnv
      .envrc
      .direnv/

      # Claude Code local settings (user-specific)
      .claude/

      # NOTE: .mcp.json is project config and should be committed

      # IDE
      .vscode/
      .idea/
      *.swp
      *.swo
      *~

      # Distribution / packaging
      dist/
      build/
      *.egg-info/

      # Testing
      .pytest_cache/
      .coverage
      htmlcov/

      # Environment variables
      .env
      .env.local

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
  end

  def summary_next_steps
    [
      "Install dependencies: uv pip install <package>",
      "Start coding!"
    ]
  end

  private

  def create_pyproject_if_missing(project_dir, version)
    return if File.exist?("pyproject.toml")

    return unless prompt_yes?("Do you want to create a basic pyproject.toml?")

    project_name = File.basename(project_dir)
    pyproject_content = <<~TOML
      [project]
      name = "#{project_name}"
      version = "0.1.0"
      description = ""
      readme = "README.md"
      requires-python = ">= #{version}"
      dependencies = []

      [build-system]
      requires = ["hatchling"]
      build-backend = "hatchling.build"
    TOML

    File.write("pyproject.toml", pyproject_content)
    print_info "Created pyproject.toml ✓"
  end

  def create_readme_if_missing(project_dir)
    return if File.exist?("README.md")

    return unless prompt_yes?("Do you want to create a basic README.md?")

    project_name = File.basename(project_dir)
    readme_content = <<~README
      # #{project_name}

      ## Setup

      This project uses `uv` for dependency management and `direnv` for automatic virtual environment activation.

      ### Prerequisites

      - [uv](https://github.com/astral-sh/uv)
      - [direnv](https://direnv.net/)

      ### Installation

      The development environment is already configured. Simply enter the directory and direnv will automatically activate the virtual environment.

      ```bash
      cd #{project_name}
      # Virtual environment is automatically activated by direnv
      ```

      ### Installing Dependencies

      ```bash
      uv pip install -r requirements.txt
      ```

    README

    File.write("README.md", readme_content)
    print_info "Created README.md ✓"
  end
end

# Ruby-specific setup strategy
class RubyStrategy
  include CommonHelpers
  include LanguageStrategy

  DEFAULT_VERSION = "3.3"

  def language_name
    "Ruby"
  end

  def default_version
    DEFAULT_VERSION
  end

  def detect_existing_project?
    File.exist?("Gemfile") || File.exist?("Gemfile.lock")
  end

  def check_language_requirements
    unless command_exists?("ruby")
      print_error "Ruby is not installed. Please install Ruby first."
      exit 1
    end

    unless command_exists?("bundle")
      print_error "Bundler is not installed. Please install it first:"
      puts "  gem install bundler"
      exit 1
    end
  end

  def create_venv(venv_dir, version)
    if Dir.exist?(venv_dir)
      print_warn "Virtual environment already exists at #{venv_dir}"
      return if !prompt_yes?("Do you want to recreate it?")

      print_info "Removing existing virtual environment..."
      FileUtils.rm_rf(venv_dir)
    end

    print_info "Creating virtual environment with Ruby #{version}..."
    system("ruby -m venv #{venv_dir}")
    print_info "Virtual environment created at #{venv_dir} ✓"
  rescue StandardError => e
    print_error "Failed to create virtual environment: #{e.message}"
    exit 1
  end

  def setup_language_specific(venv_dir)
    setup_bundler
  end

  def generate_venv_activation_line(venv_dir)
    "source #{venv_dir}/bin/activate.sh\n"
  end

  def create_project_files(project_dir, version)
    create_gemfile_if_missing(version)
    create_readme_if_missing(project_dir)
  end

  def generate_gitignore(venv_dir)
    <<~GITIGNORE
      # Ruby
      *.gem
      *.rbc
      .bundle/
      .gems/
      Gemfile.lock
      .ruby-version

      # Virtual environments
      #{venv_dir}/
      venv/
      env/
      ENV/

      # direnv
      .envrc
      .direnv/

      # Claude Code local settings (user-specific)
      .claude/

      # NOTE: .mcp.json is project config and should be committed

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
  end

  def summary_next_steps
    [
      "Install dependencies: bundle install",
      "Start coding!"
    ]
  end

  private

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

      # Add your gems here
    GEMFILE

    File.write("Gemfile", gemfile_content)
    print_info "Created Gemfile ✓"
  end

  def create_gemfile_if_missing(version)
    return if File.exist?("Gemfile")

    return unless prompt_yes?("Do you want to create a basic Gemfile?")

    create_basic_gemfile
  end

  def create_readme_if_missing(project_dir)
    return if File.exist?("README.md")

    return unless prompt_yes?("Do you want to create a basic README.md?")

    project_name = File.basename(project_dir)
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
end

# None strategy - for direnv/MCP setup only (no language-specific environment)
# Useful for JXA, shell scripts, configuration files, etc.
class NoneStrategy
  include CommonHelpers
  include LanguageStrategy

  def language_name
    "None (direnv/MCP setup only)"
  end

  def default_version
    nil
  end

  def detect_existing_project?
    false
  end

  def check_language_requirements
    print_info "No language requirements ✓"
  end

  def create_venv(venv_dir, version)
    # Nothing to do - no virtual environment needed
  end

  def setup_language_specific(venv_dir)
    # No language-specific setup needed
  end

  def generate_venv_activation_line(venv_dir)
    # No venv activation needed
    ""
  end

  def create_project_files(project_dir, version)
    create_readme_if_missing(project_dir)
  end

  def generate_gitignore(venv_dir)
    <<~GITIGNORE
      # Claude Code local settings (user-specific)
      .claude/

      # NOTE: .mcp.json is project config and should be committed

      # IDEs
      .vscode/
      .idea/
      *.swp
      *.swo
      *~

      # OS
      .DS_Store
      .AppleDouble
      .LSOverride

      # Environment variables
      .env
      .env.local

      # Logs
      *.log

      # Temporary files
      *.tmp
      *.bak
      *.backup
    GITIGNORE
  end

  def summary_next_steps
    [
      "Start coding!",
      "Use direnv for environment variable management"
    ]
  end

  private

  def create_readme_if_missing(project_dir)
    return if File.exist?("README.md")

    return unless prompt_yes?("Do you want to create a basic README.md?")

    project_name = File.basename(project_dir)
    readme_content = <<~README
      # #{project_name}

      ## Setup

      This project uses `direnv` for environment management.

      ### Prerequisites

      - [direnv](https://direnv.net/)

      ### Installation

      The environment is configured with direnv. Simply enter the directory and direnv will load the environment configuration.

      ```bash
      cd #{project_name}
      # Environment is automatically loaded by direnv
      ```

    README

    File.write("README.md", readme_content)
    print_info "Created README.md ✓"
  end
end

# Main setup orchestrator
class SetupEnv
  include CommonHelpers

  DEFAULT_VENV_DIR = ".venv"
  MCP_CONFIGS = ["work", "personal"].freeze
  LANGUAGES = {
    "python" => PythonStrategy,
    "ruby" => RubyStrategy,
    "none" => NoneStrategy
  }.freeze

  def initialize
    @language = nil
    @strategy = nil
    @venv_dir = DEFAULT_VENV_DIR
    @version = nil
    @mcp_config = ""
    @project_dir = "."
  end

  def run
    parse_arguments
    detect_or_prompt_language
    validate_and_set_mcp_config
    initialize_strategy
    setup_project_dir
    check_requirements
    execute_setup
    print_summary
  end

  private

  def parse_arguments
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: setup-env.rb [OPTIONS] [PROJECT_DIR]"
      opts.separator ""
      opts.separator "Sets up a development environment with direnv auto-activation."
      opts.separator ""
      opts.separator "Supports: Python (uv), Ruby (Bundler), None (direnv/MCP only)"
      opts.separator ""
      opts.separator "OPTIONS:"

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit 0
      end

      opts.on("-l", "--lang LANGUAGE", "--language LANGUAGE",
              "Language to setup: 'python', 'ruby', or 'none'") do |l|
        unless LANGUAGES.key?(l.downcase)
          print_error "Invalid language: #{l} (must be 'python', 'ruby', or 'none')"
          exit 1
        end
        @language = l.downcase
      end

      opts.on("-v", "--version VERSION",
              "Version to use (default: Python 3.13, Ruby 3.3)") do |v|
        @version = v
      end

      opts.on("-d", "--venv-dir DIR",
              "Virtual environment directory name (default: #{DEFAULT_VENV_DIR})") do |d|
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
      opts.separator "  #{File.basename($0)} --lang python              # Setup Python in current dir"
      opts.separator "  #{File.basename($0)} --lang ruby my-project     # Setup Ruby in ./my-project"
      opts.separator "  #{File.basename($0)} -l python -v 3.12          # Python 3.12"
      opts.separator "  #{File.basename($0)} --mcp work                 # Auto-detect lang + MCP"
      opts.separator ""
      opts.separator "LANGUAGE DETECTION:"
      opts.separator "  - If --lang is specified, uses that language"
      opts.separator "  - If pyproject.toml exists, assumes Python"
      opts.separator "  - If Gemfile exists, assumes Ruby"
      opts.separator "  - Otherwise, prompts for language selection"
      opts.separator ""
      opts.separator "MCP AUTO-DETECTION:"
      opts.separator "  - If --mcp is not specified, auto-detects from project location:"
      opts.separator "    - ~/Projects/* → work (GitHub Enterprise)"
      opts.separator "    - ~/Dev/* → personal (GitHub.com)"
      opts.separator "  - If explicit --mcp conflicts with location, shows warning"
      opts.separator ""
      opts.separator "REQUIREMENTS:"
      opts.separator "  - direnv: Environment switcher (https://direnv.net/)"
      opts.separator "  - For Python: uv (https://github.com/astral-sh/uv)"
      opts.separator "  - For Ruby: Ruby 3.0+ with Bundler"
      opts.separator "  - For None: Only direnv (useful for JXA, scripts, etc.)"
    end

    parser.parse!

    @project_dir = ARGV[0] || "."
  end

  def detect_or_prompt_language
    return if @language # CLI flag already specified

    detected = detect_language_from_files

    if detected.nil?
      # Detection failed, prompt user
      @language = prompt_language_selection
    elsif detected.size == 1
      # Single language detected
      @language = detected.first
      print_info "Detected language: #{@language}"
    else
      # Multiple languages detected - need explicit specification
      print_error "Multiple project types detected: #{detected.join(', ')}"
      print_error "Please specify language explicitly with --lang option"
      exit 1
    end
  end

  def detect_language_from_files
    detected = []
    detected << "python" if File.exist?("pyproject.toml")
    detected << "ruby" if File.exist?("Gemfile") || File.exist?("Gemfile.lock")
    detected.empty? ? nil : detected
  end

  def prompt_language_selection
    puts ""
    puts "Which language do you want to setup?"
    puts "  1) Python (with uv)"
    puts "  2) Ruby (with Bundler)"
    puts "  3) None (direnv/MCP setup only)"
    print "Enter choice [1-3]: "

    choice = $stdin.gets

    # Non-interactive mode: default to Python
    if choice.nil?
      print_warn "No input detected (non-interactive mode). Defaulting to Python."
      return "python"
    end

    choice = choice.chomp
    case choice
    when "1"
      "python"
    when "2"
      "ruby"
    when "3"
      "none"
    else
      print_error "Invalid choice: #{choice}"
      exit 1
    end
  end

  def infer_mcp_from_project_dir
    resolved_dir = File.expand_path(@project_dir)

    case resolved_dir
    when %r{^/Users/junya/Projects/}
      "work"
    when %r{^/Users/junya/Dev/}
      "personal"
    else
      nil
    end
  end

  def validate_and_set_mcp_config
    inferred = infer_mcp_from_project_dir

    # Case 1: User did not specify --mcp
    if @mcp_config.empty?
      if inferred
        @mcp_config = inferred
        print_info "Auto-detected MCP config from project location: #{inferred}"
      end
      return true
    end

    # Case 2: User specified --mcp, check for conflicts
    if inferred && @mcp_config != inferred
      resolved_dir = File.expand_path(@project_dir)
      print_warn "⚠️  MCP config mismatch detected!"
      print_warn "    Project location: #{resolved_dir}"
      print_warn "    Inferred from location: #{inferred}"
      print_warn "    You specified: #{@mcp_config}"
      puts ""

      return prompt_yes?("Continue with explicit setting?")
    end

    true
  end

  def initialize_strategy
    strategy_class = LANGUAGES[@language]
    @strategy = strategy_class.new

    # Set default version if not specified
    @version ||= @strategy.default_version
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

    unless command_exists?("direnv")
      print_error "direnv is not installed. Please install it first:"
      puts "  macOS: brew install direnv"
      puts "  Then add to your shell config: eval \"$(direnv hook bash)\" or eval \"$(direnv hook zsh)\""
      exit 1
    end

    @strategy.check_language_requirements
    print_info "All requirements satisfied ✓"
  end

  def execute_setup
    @strategy.create_venv(@venv_dir, @version)
    @strategy.setup_language_specific(@venv_dir)
    setup_direnv
    setup_mcp
    @strategy.create_project_files(@project_dir, @version)
    create_gitignore
  end

  def setup_mcp
    return if @mcp_config.empty?

    wrapper_script, server_name = mcp_config_paths

    unless File.exist?(wrapper_script)
      print_error "MCP wrapper script not found: #{wrapper_script}"
      return
    end

    print_info "Setting up project-local MCP configuration..."

    mcp_json_path = File.join(@project_dir, ".mcp.json")

    if File.exist?(mcp_json_path)
      begin
        existing_config = JSON.parse(File.read(mcp_json_path))
        if existing_config.dig("mcpServers", server_name)
          print_info "MCP server '#{server_name}' already configured ✓"
          return
        end
        return unless prompt_yes?("Add '#{server_name}' to existing .mcp.json?")
      rescue StandardError => e
        print_error "Failed to read existing .mcp.json: #{e.message}"
        return
      end
    else
      existing_config = { "mcpServers" => {} }
    end

    existing_config["mcpServers"][server_name] = {
      "command" => wrapper_script,
      "args" => [],
      "env" => {}
    }

    begin
      File.write(mcp_json_path, JSON.pretty_generate(existing_config))
      print_info "Created .mcp.json with '#{server_name}' server ✓"
    rescue StandardError => e
      print_error "Failed to write .mcp.json: #{e.message}"
    end
  end

  def mcp_config_paths
    scripts_dir = File.expand_path("~/Scripts/Shell")
    case @mcp_config
    when "work"
      ["#{scripts_dir}/mcp-github-work.sh", "github-work"]
    when "personal"
      ["#{scripts_dir}/mcp-github-personal.sh", "github-personal"]
    end
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

    # Language-specific venv activation
    content += @strategy.generate_venv_activation_line(@venv_dir)
    content += "\n"

    # GitHub tokens/usernames for MCP if configured
    unless @mcp_config.empty?
      content += "# GitHub API tokens and username for MCP\n"
      content += "# Note: API tokens are managed via Keychain (1Password → Keychain via mcp-github-setting.sh)\n"
      case @mcp_config
      when "work"
        content += 'export GITHUB_USERNAME="juny-s"' + "\n"
      when "personal"
        content += 'export GITHUB_USERNAME="switchdriven"' + "\n"
      end
    end

    content
  end

  def create_gitignore
    return if File.exist?(".gitignore")

    return unless prompt_yes?("Do you want to create a .gitignore file?")

    gitignore_content = @strategy.generate_gitignore(@venv_dir)

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
    @strategy.summary_next_steps.each { |step| puts "  - #{step}" }
    puts ""
    print_info "The environment will be automatically activated when you enter the directory."

    unless @mcp_config.empty?
      puts ""
      print_info "MCP Configuration:"
      puts "  - Type: #{@mcp_config}"
      server_desc = @mcp_config == 'work' ? 'github-work (GitHub Enterprise)' : 'github-personal (GitHub.com)'
      puts "  - Server: #{server_desc}"
      puts "  - Config file: .mcp.json (project-local, can be committed)"
      puts "  - Approval required on first use (per project)"
      puts ""
      print_info "Remember to commit .mcp.json to version control:"
      puts "  git add .mcp.json"
      puts "  git commit -m 'feat: add MCP configuration'"
    end
  end
end

# Run the setup
SetupEnv.new.run if __FILE__ == $0
