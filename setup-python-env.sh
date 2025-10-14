#!/usr/bin/env bash

# setup-python-env.sh
# Sets up a Python project with uv virtual environment and direnv auto-activation

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
VENV_DIR=".venv_uv"
PYTHON_VERSION="3.13"
MCP_CONFIG=""  # Can be "work", "personal", or empty (no MCP)

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [PROJECT_DIR]

Sets up a Python development environment with uv and direnv.

OPTIONS:
    -h, --help              Show this help message
    -v, --python-version    Python version to use (default: ${PYTHON_VERSION})
    -d, --venv-dir          Virtual environment directory name (default: ${VENV_DIR})
    -m, --mcp               MCP configuration to use: "work" or "personal" (default: none)

ARGUMENTS:
    PROJECT_DIR             Directory to setup (default: current directory)

EXAMPLES:
    $(basename "$0")                           # Setup in current directory
    $(basename "$0") my-project                # Setup in ./my-project
    $(basename "$0") --python-version 3.12     # Use Python 3.12
    $(basename "$0") --mcp work                # Setup with work GitHub MCP config

REQUIREMENTS:
    - uv: Python package installer (https://github.com/astral-sh/uv)
    - direnv: Environment switcher (https://direnv.net/)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--python-version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        -d|--venv-dir)
            VENV_DIR="$2"
            shift 2
            ;;
        -m|--mcp)
            MCP_CONFIG="$2"
            if [[ "$MCP_CONFIG" != "work" && "$MCP_CONFIG" != "personal" ]]; then
                print_error "Invalid MCP config: $MCP_CONFIG (must be 'work' or 'personal')"
                exit 1
            fi
            shift 2
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

# Set project directory (default to current directory)
PROJECT_DIR="${PROJECT_DIR:-.}"

# Check if required tools are installed
check_requirements() {
    print_info "Checking requirements..."

    if ! command -v uv &> /dev/null; then
        print_error "uv is not installed. Please install it first:"
        echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi

    if ! command -v direnv &> /dev/null; then
        print_error "direnv is not installed. Please install it first:"
        echo "  macOS: brew install direnv"
        echo "  Then add to your shell config: eval \"\$(direnv hook bash)\" or eval \"\$(direnv hook zsh)\""
        exit 1
    fi

    print_info "All requirements satisfied ✓"
}

# Create project directory if it doesn't exist
setup_project_dir() {
    if [[ ! -d "$PROJECT_DIR" ]]; then
        print_info "Creating project directory: ${PROJECT_DIR}"
        mkdir -p "$PROJECT_DIR"
    fi

    cd "$PROJECT_DIR"
    PROJECT_DIR="$(pwd)" # Get absolute path
    print_info "Working in: ${PROJECT_DIR}"
}

# Create virtual environment with uv
create_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        print_warn "Virtual environment already exists at ${VENV_DIR}"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing virtual environment..."
            rm -rf "$VENV_DIR"
        else
            print_info "Skipping virtual environment creation"
            return 0
        fi
    fi

    print_info "Creating virtual environment with Python ${PYTHON_VERSION}..."
    uv venv "$VENV_DIR" --python "$PYTHON_VERSION"
    print_info "Virtual environment created at ${VENV_DIR} ✓"
}

# Setup MCP configuration using claude mcp add command
setup_mcp() {
    if [[ -z "$MCP_CONFIG" ]]; then
        print_info "No MCP configuration specified, skipping MCP setup"
        return 0
    fi

    # Check if claude CLI is available
    if ! command -v claude &> /dev/null; then
        print_error "claude CLI is not installed. MCP setup requires Claude Code."
        print_info "Please install Claude Code first: https://claude.ai/download"
        return 1
    fi

    # Determine wrapper script path and server name
    local wrapper_script
    local server_name
    local scripts_dir="$HOME/Scripts/Shell"

    if [[ "$MCP_CONFIG" == "work" ]]; then
        wrapper_script="${scripts_dir}/run-github-mcp-work.sh"
        server_name="github-work"
    elif [[ "$MCP_CONFIG" == "personal" ]]; then
        wrapper_script="${scripts_dir}/run-github-mcp-personal.sh"
        server_name="github-personal"
    else
        print_error "Invalid MCP config: $MCP_CONFIG"
        return 1
    fi

    # Check if wrapper script exists
    if [[ ! -f "$wrapper_script" ]]; then
        print_error "MCP wrapper script not found: ${wrapper_script}"
        return 1
    fi

    # Check if MCP server is already configured
    if claude mcp list | grep -q "$server_name"; then
        print_info "MCP server '${server_name}' is already configured ✓"
        return 0
    fi

    # Add MCP server using claude CLI
    print_info "Adding MCP server '${server_name}'..."
    if claude mcp add --transport stdio "$server_name" -- "$wrapper_script"; then
        print_info "MCP server '${server_name}' added successfully ✓"
    else
        print_error "Failed to add MCP server '${server_name}'"
        return 1
    fi
}

# Setup direnv configuration
setup_direnv() {
    local envrc_file=".envrc"
    local temp_file="${envrc_file}.tmp"
    local needs_update=false

    # Start building the new .envrc content
    {
        # Add Python venv activation
        echo "source ${VENV_DIR}/bin/activate"
        echo ""

        # Add GitHub tokens if MCP is configured
        if [[ -n "$MCP_CONFIG" ]]; then
            echo "# GitHub API tokens for MCP"
            if [[ "$MCP_CONFIG" == "work" ]]; then
                echo 'export GITHUB_WORK_TOKEN=$(op read "op://Personal/GitHubEnt For MCP/token")'
            elif [[ "$MCP_CONFIG" == "personal" ]]; then
                echo 'export GITHUB_PERSONAL_TOKEN=$(op read "op://Personal/GitHub For MCP/token")'
            fi
        fi
    } > "$temp_file"

    # Check if .envrc exists and compare
    if [[ -f "$envrc_file" ]]; then
        # Check if the content is different
        if ! cmp -s "$envrc_file" "$temp_file"; then
            print_warn ".envrc already exists"
            echo "Current content:"
            cat "$envrc_file" | sed 's/^/  /'
            echo ""
            echo "New content:"
            cat "$temp_file" | sed 's/^/  /'
            echo ""
            read -p "Do you want to replace it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mv "$temp_file" "$envrc_file"
                print_info "Replaced .envrc ✓"
                needs_update=true
            else
                rm "$temp_file"
                print_info "Keeping existing .envrc"
                return 0
            fi
        else
            rm "$temp_file"
            print_info ".envrc already up to date ✓"
            return 0
        fi
    else
        mv "$temp_file" "$envrc_file"
        print_info "Created .envrc ✓"
        needs_update=true
    fi

    # Allow direnv
    if [[ "$needs_update" == true ]]; then
        print_info "Allowing direnv for this directory..."
        direnv allow
        print_info "direnv configured ✓"
    fi
}

# Create basic Python project structure (optional)
create_project_structure() {
    if [[ ! -f "pyproject.toml" ]]; then
        read -p "Do you want to create a basic pyproject.toml? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local project_name
            project_name=$(basename "$PROJECT_DIR")

            cat > pyproject.toml << EOF
[project]
name = "${project_name}"
version = "0.1.0"
description = ""
readme = "README.md"
requires-python = ">=${PYTHON_VERSION}"
dependencies = []

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
EOF
            print_info "Created pyproject.toml ✓"
        fi
    fi

    if [[ ! -f "README.md" ]]; then
        read -p "Do you want to create a basic README.md? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            local project_name
            project_name=$(basename "$PROJECT_DIR")

            cat > README.md << EOF
# ${project_name}

## Setup

This project uses \`uv\` for dependency management and \`direnv\` for automatic virtual environment activation.

### Prerequisites

- [uv](https://github.com/astral-sh/uv)
- [direnv](https://direnv.net/)

### Installation

The development environment is already configured. Simply enter the directory and direnv will automatically activate the virtual environment.

\`\`\`bash
cd ${project_name}
# Virtual environment is automatically activated by direnv
\`\`\`

### Installing Dependencies

\`\`\`bash
uv pip install -r requirements.txt
\`\`\`

EOF
            print_info "Created README.md ✓"
        fi
    fi
}

# Add .gitignore if it doesn't exist
create_gitignore() {
    if [[ ! -f ".gitignore" ]]; then
        read -p "Do you want to create a .gitignore file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Virtual environments
${VENV_DIR}/
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

EOF
            print_info "Created .gitignore ✓"
        fi
    fi
}

# Main execution
main() {
    print_info "Starting Python environment setup..."
    echo

    check_requirements
    setup_project_dir
    create_venv
    setup_mcp
    setup_direnv
    create_project_structure
    create_gitignore

    echo
    print_info "========================================="
    print_info "Setup completed successfully! 🎉"
    print_info "========================================="
    echo
    print_info "Next steps:"
    echo "  1. cd ${PROJECT_DIR}"
    echo "  2. Install dependencies: uv pip install <package>"
    echo "  3. Start coding!"
    echo
    print_info "The virtual environment will be automatically activated when you enter the directory."
    if [[ -n "$MCP_CONFIG" ]]; then
        echo
        print_info "MCP Configuration:"
        echo "  - Config: ${MCP_CONFIG}"
        if [[ "$MCP_CONFIG" == "work" ]]; then
            echo "  - Server: github-work (GitHub Enterprise)"
        elif [[ "$MCP_CONFIG" == "personal" ]]; then
            echo "  - Server: github-personal (GitHub.com)"
        fi
        echo "  - Check status: claude mcp list"
    fi
}

# Run main function
main
