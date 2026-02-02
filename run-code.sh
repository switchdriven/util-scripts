#!/usr/bin/env bash
set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Show help
show_help() {
    cat << EOF
Usage: run-code.sh [OPTIONS] [ARGUMENTS]

VS Code launcher with automatic proxy detection for Proxifier.

This script checks if Proxifier is running and adjusts proxy environment
variables accordingly before launching VS Code:
  - If Proxifier is running: Unsets proxy env vars (to avoid double proxying)
  - If Proxifier is not running: Uses existing proxy env vars

OPTIONS:
  --wrapper-help  Show this wrapper script's help message and exit
  -v, --verbose   Show detailed proxy detection information

ARGUMENTS:
  All other arguments are passed directly to the 'code' command
  (including --help to see VS Code's own help)

EXAMPLES:
  # Show wrapper script help
  ./run-code.sh --wrapper-help

  # Show VS Code's own help
  ./run-code.sh --help

  # Open current directory
  ./run-code.sh .

  # Open specific file
  ./run-code.sh /path/to/file.txt

  # Open with verbose output
  ./run-code.sh --verbose .

  # Add folder to workspace
  ./run-code.sh --add /path/to/folder

ENVIRONMENT VARIABLES:
  The following proxy variables are managed automatically:
    - ALL_PROXY
    - HTTP_PROXY
    - HTTPS_PROXY
    - NO_PROXY

BACKGROUND:
  When Proxifier is running, it intercepts all network traffic at the system
  level. If proxy environment variables are also set, Claude extensions may
  experience connection issues due to double proxying.

EOF
}

# Parse options
verbose=false
code_args=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wrapper-help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        *)
            code_args+=("$1")
            shift
            ;;
    esac
done

# Check if code command exists
if ! command -v code &> /dev/null; then
    print_error "VS Code 'code' command not found in PATH"
    echo "Please install VS Code command line tools:"
    echo "  1. Open VS Code"
    echo "  2. Press Cmd+Shift+P"
    echo "  3. Type 'shell command'"
    echo "  4. Select 'Install 'code' command in PATH'"
    exit 1
fi

# Check Proxifier status
if pgrep -x "Proxifier" > /dev/null; then
    # Proxifier is running
    print_info "Proxifier is running"

    if [[ "$verbose" == true ]]; then
        print_warning "Unsetting proxy environment variables to avoid double proxying"
        echo "  - ALL_PROXY"
        echo "  - HTTP_PROXY"
        echo "  - HTTPS_PROXY"
        echo "  - NO_PROXY"
    fi

    print_success "Launching VS Code without proxy env vars"

    # Launch VS Code without proxy environment variables
    # Set NO_PROXY=* to disable system proxy settings (PAC files, etc.)
    env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY NO_PROXY='*' code "${code_args[@]}"
else
    # Proxifier is not running
    print_info "Proxifier is not running"

    if [[ "$verbose" == true ]]; then
        if [[ -n "${ALL_PROXY:-}" ]] || [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
            print_info "Using existing proxy environment variables:"
            [[ -n "${ALL_PROXY:-}" ]] && echo "  - ALL_PROXY=${ALL_PROXY}"
            [[ -n "${HTTP_PROXY:-}" ]] && echo "  - HTTP_PROXY=${HTTP_PROXY}"
            [[ -n "${HTTPS_PROXY:-}" ]] && echo "  - HTTPS_PROXY=${HTTPS_PROXY}"
            [[ -n "${NO_PROXY:-}" ]] && echo "  - NO_PROXY=${NO_PROXY}"
        else
            print_info "No proxy environment variables set"
        fi
    fi

    print_success "Launching VS Code with current environment"

    # Launch VS Code with current environment (including proxy vars if set)
    code "${code_args[@]}"
fi
