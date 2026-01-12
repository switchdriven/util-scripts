#!/usr/bin/env bash

# Backup directories to tar.gz archives with timestamp
# Usage: backup.sh <directory_path> [backup_base_dir]

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default paths
readonly DEFAULT_BACKUP_BASE_DIR="${HOME}/Backup/Archives"
readonly TIMESTAMP=$(date +%Y%m%d)

# Functions (定義を先に)
print_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <directory_path> [backup_base_dir]

Backup a directory to a tar.gz file with timestamp (<dir_name>-YYYYMMDD.tar.gz).

Arguments:
  directory_path     Path to directory to backup (required)
  backup_base_dir    Base directory for backups (default: \$HOME/Backup/Archives)

Options:
  --force, -f              Overwrite existing backup without confirmation
  --no-dereference         Store symlinks as-is instead of following them (default: follows symlinks)
  --help                   Show this help message

Examples:
  $(basename "$0") ~/Obsidian                         # Backup to ~/Backup/Archives/Obsidian-20240115.tar.gz
  $(basename "$0") ~/Documents ~/MyBackups            # Backup to ~/MyBackups/Documents-20240115.tar.gz
  $(basename "$0") --force ~/Obsidian                 # Overwrite without asking
  $(basename "$0") --no-dereference ~/Obsidian        # Store symlinks without following them
  $(basename "$0") --help                             # Show help

Environment variables:
  DEBUG              Set to 1 for verbose output

EOF
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Parse arguments
TARGET_PATH=""
BACKUP_BASE_DIR="${DEFAULT_BACKUP_BASE_DIR}"
FORCE=0
DEREFERENCE=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            print_help
            exit 0
            ;;
        --force|-f)
            FORCE=1
            shift
            ;;
        --no-dereference)
            DEREFERENCE=0
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_PATH" ]]; then
                TARGET_PATH="$1"
            else
                BACKUP_BASE_DIR="$1"
            fi
            shift
            ;;
    esac
done

# Check if target path is provided
if [[ -z "$TARGET_PATH" ]]; then
    log_error "Directory path is required"
    echo
    print_help
    exit 1
fi

# Validate target path
if [[ ! -d "$TARGET_PATH" ]]; then
    log_error "Directory does not exist: $TARGET_PATH"
    exit 1
fi

# Resolve to absolute path and get basename
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
readonly DIR_NAME="$(basename "$TARGET_PATH")"

debug "Target path: $TARGET_PATH"
debug "Directory name: $DIR_NAME"
debug "Backup base directory: $BACKUP_BASE_DIR"
debug "Timestamp: $TIMESTAMP"
debug "Dereference symlinks: $DEREFERENCE"

# Create backup directory if it doesn't exist
if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
    log_info "Creating backup directory: $BACKUP_BASE_DIR"
    mkdir -p "$BACKUP_BASE_DIR" || {
        log_error "Failed to create backup directory"
        exit 1
    }
fi

# Prepare archive name
readonly ARCHIVE_NAME="${DIR_NAME}-${TIMESTAMP}.tar.gz"
readonly ARCHIVE_PATH="${BACKUP_BASE_DIR}/${ARCHIVE_NAME}"

# Check if backup already exists today
if [[ -f "$ARCHIVE_PATH" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        log_info "Removing existing backup (--force)"
    else
        log_warn "Backup already exists for today: $ARCHIVE_PATH"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Backup cancelled"
            exit 0
        fi
        log_info "Removing existing backup"
    fi
    rm "$ARCHIVE_PATH"
fi

# Perform backup
log_info "Starting backup of $TARGET_PATH..."
if (cd "$TARGET_PATH" && tar $([ $DEREFERENCE -eq 1 ] && echo "--dereference") --format=pax --no-xattrs -czf "$ARCHIVE_PATH" .); then
    readonly FILE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    log_success "Backup completed: $ARCHIVE_PATH ($FILE_SIZE)"

    # Show recent backups for this directory
    log_info "Recent backups of $DIR_NAME:"
    ls -lhS "$BACKUP_BASE_DIR" | grep "^-.*${DIR_NAME}-.*\.tar\.gz$" | head -5 | awk '{print "  " $9 " (" $5 ")"}'
else
    log_error "Backup failed"
    rm -f "$ARCHIVE_PATH"
    exit 1
fi
