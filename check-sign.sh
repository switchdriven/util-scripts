#!/usr/bin/env bash
# Validate digital signatures in a PDF file using pyHanko, and show the
# certificate chain details (Subject/Issuer/Serial/validity/signature
# algorithm) in Japanese.
# Requires pyHanko installed in $HOME/Scripts/.venv.

set -euo pipefail

readonly PYTHON="$HOME/Scripts/.venv/bin/python3"
readonly SCRIPT="$HOME/Dev/util-scripts/check-sign.py"

print_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <pdf_file>

Validate digital signatures in a PDF file using pyHanko, and show the
certificate chain details in Japanese.

Arguments:
  pdf_file    Path to the PDF file to validate (required)

Options:
  --help, -h  Show this help message

Examples:
  $(basename "$0") document.pdf
  $(basename "$0") ~/Documents/signed.pdf

EOF
}

# Parse arguments
PDF_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            print_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            PDF_FILE="$1"
            shift
            ;;
    esac
done

if [[ -z "$PDF_FILE" ]]; then
    echo "Error: PDF file is required" >&2
    echo
    print_help
    exit 1
fi

if [[ ! -f "$PDF_FILE" ]]; then
    echo "Error: File not found: $PDF_FILE" >&2
    exit 1
fi

exec "$PYTHON" "$SCRIPT" "$PDF_FILE"
