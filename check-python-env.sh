#!/usr/bin/env bash

# check-python-env.sh
# Script to find and identify Python virtual environments recursively

set -euo pipefail

# Color codes
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m' # No Color

# Global counters
uv_count=0
venv_count=0
total_count=0

# Disable colors if requested
USE_COLOR=true

# Print usage
print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Find and identify Python virtual environments recursively.

OPTIONS:
    -h, --help          Show this help message
    -d, --depth N       Maximum depth for recursive search (default: unlimited)
    --no-color          Disable colored output

ARGUMENTS:
    DIRECTORY           Directory to search (default: current directory)

EXAMPLES:
    $(basename "$0")                    # Search current directory
    $(basename "$0") ~/Projects         # Search specific directory
    $(basename "$0") -d 2 ~/Projects    # Search with max depth of 2

DETECTED ENVIRONMENT TYPES:
    - uv: Virtual environments created by 'uv' (contains pyvenv.cfg with uv marker)
    - venv/virtualenv: Standard Python virtual environments
EOF
}

# Print colored message
print_msg() {
    local color="$1"
    shift
    if [[ "$USE_COLOR" == "true" ]]; then
        printf "${color}%s${NC}\n" "$*"
    else
        printf "%s\n" "$*"
    fi
}

# Detect virtual environment type
detect_venv_type() {
    local venv_dir="$1"
    local pyvenv_cfg="${venv_dir}/pyvenv.cfg"

    # Check if pyvenv.cfg exists
    if [[ ! -f "$pyvenv_cfg" ]]; then
        return 1
    fi

    # Check for uv-specific markers
    if grep -q "uv = " "$pyvenv_cfg" 2>/dev/null || \
       grep -qE "(UV_PYTHON|created by uv)" "$pyvenv_cfg" 2>/dev/null; then
        printf "uv"
        return 0
    fi

    # If pyvenv.cfg exists but no uv markers, it's a standard venv
    printf "venv"
    return 0
}

# Get Python version from virtual environment
get_python_version() {
    local venv_dir="$1"
    local pyvenv_cfg="${venv_dir}/pyvenv.cfg"

    # Try to get version from pyvenv.cfg first (faster)
    if [[ -f "$pyvenv_cfg" ]]; then
        local version

        # Try "version = " format (standard venv)
        version=$(grep -E "^version = " "$pyvenv_cfg" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
        if [[ -n "$version" ]]; then
            printf "%s" "$version"
            return 0
        fi

        # Try "version_info = " format (uv)
        version=$(grep -E "^version_info = " "$pyvenv_cfg" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
        if [[ -n "$version" ]]; then
            printf "%s" "$version"
            return 0
        fi
    fi

    # Fallback
    printf "unknown"
    return 0
}

# Check if directory is a virtual environment
is_venv() {
    local dir="$1"

    # Check for common virtual environment markers
    if [[ -f "${dir}/pyvenv.cfg" ]] && [[ -d "${dir}/bin" ]]; then
        return 0
    fi

    return 1
}

# Main search function
search_venvs() {
    local search_dir="$1"
    local max_depth="${2:-}"

    print_msg "$BOLD$BLUE" "Searching for Python virtual environments in: $search_dir"

    # Build find command arguments
    local -a find_args=("$search_dir")

    # Add depth limit if specified
    if [[ -n "$max_depth" ]]; then
        find_args+=("-maxdepth" "$max_depth")
    fi

    # Look for pyvenv.cfg files
    find_args+=("-type" "f" "-name" "pyvenv.cfg" "-print")

    # Execute find and process results
    while IFS= read -r pyvenv_file; do
        [[ -z "$pyvenv_file" ]] && continue

        local venv_dir
        venv_dir=$(dirname "$pyvenv_file")

        if ! is_venv "$venv_dir"; then
            continue
        fi

        local venv_type
        venv_type=$(detect_venv_type "$venv_dir")

        local python_version
        python_version=$(get_python_version "$venv_dir")

        # Print virtual environment info in one line
        case "$venv_type" in
            uv)
                print_msg "$CYAN" "  [uv]   $venv_dir (Python $python_version)"
                ((uv_count++)) || true
                ;;
            venv)
                print_msg "$GREEN" "  [venv] $venv_dir (Python $python_version)"
                ((venv_count++)) || true
                ;;
            *)
                print_msg "$YELLOW" "  [unknown] $venv_dir (Python $python_version)"
                ;;
        esac

        ((total_count++)) || true

    done < <(find "${find_args[@]}" 2>/dev/null || true)
}

# Print summary
print_summary() {
    if [[ $total_count -eq 0 ]]; then
        print_msg "$YELLOW" "No Python virtual environments found."
    else
        if [[ "$USE_COLOR" == "true" ]]; then
            printf "${BOLD}Found %d environments: ${CYAN}%d uv${NC}, ${GREEN}%d venv${NC}\n" "$total_count" "$uv_count" "$venv_count"
        else
            printf "Found %d environments: %d uv, %d venv\n" "$total_count" "$uv_count" "$venv_count"
        fi
    fi
}

# Main function
main() {
    local search_dir="."
    local max_depth=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -d|--depth)
                max_depth="$2"
                shift 2
                ;;
            --no-color)
                USE_COLOR=false
                shift
                ;;
            -*)
                print_msg "$RED" "Error: Unknown option: $1"
                printf "\n"
                print_usage
                exit 1
                ;;
            *)
                search_dir="$1"
                shift
                ;;
        esac
    done

    # Validate search directory
    if [[ ! -d "$search_dir" ]]; then
        print_msg "$RED" "Error: Directory not found: $search_dir"
        exit 1
    fi

    # Convert to absolute path
    search_dir=$(cd "$search_dir" && pwd)

    # Search for virtual environments
    search_venvs "$search_dir" "$max_depth"

    # Print summary
    print_summary
}

# Run main function
main "$@"
