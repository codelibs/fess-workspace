#!/usr/bin/env bash
set -euo pipefail

# clean.sh - Clean up cloned repositories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Remove cloned repositories from repos/ directory.

Options:
  --yes, -y         Skip confirmation prompt
  --target          Clean only Maven target directories (keep source)
  --help, -h        Show this help message

Examples:
  $(basename "$0")           # Remove all repos (with confirmation)
  $(basename "$0") --yes     # Remove all repos (no confirmation)
  $(basename "$0") --target  # Clean Maven target/ dirs only

EOF
    exit 0
}

# Parse arguments
YES=false
TARGET_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            YES=true
            shift
            ;;
        --target)
            TARGET_ONLY=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            die "Unexpected argument: $1"
            ;;
    esac
done

# Check if repos directory exists
if [[ ! -d "${REPOS_DIR}" ]]; then
    log_info "Repos directory does not exist: ${REPOS_DIR}"
    exit 0
fi

# Count repositories
repos=()
for dir in "${REPOS_DIR}"/*/; do
    [[ -d "${dir}" ]] && repos+=("$(basename "${dir}")")
done

if [[ ${#repos[@]} -eq 0 ]]; then
    log_info "No repositories found in ${REPOS_DIR}"
    exit 0
fi

if [[ "${TARGET_ONLY}" == "true" ]]; then
    print_header "Cleaning Maven target directories"
    log_info "Found ${#repos[@]} repositories"

    clean_count=0
    for repo in "${repos[@]}"; do
        target_dir="${REPOS_DIR}/${repo}/target"
        if [[ -d "${target_dir}" ]]; then
            rm -rf "${target_dir}"
            log_success "Cleaned: ${repo}/target"
            ((clean_count++))
        fi
    done

    log_info "Cleaned ${clean_count} target directories"
else
    print_header "Clean repositories"
    log_info "Found ${#repos[@]} repositories to remove:"
    for repo in "${repos[@]}"; do
        echo "  - ${repo}"
    done
    echo ""

    if [[ "${YES}" != "true" ]]; then
        if ! confirm "Remove all repositories?"; then
            log_info "Aborted"
            exit 0
        fi
    fi

    log_info "Removing repositories..."
    rm -rf "${REPOS_DIR:?}"/*

    log_success "All repositories removed"
fi
