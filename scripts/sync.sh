#!/usr/bin/env bash
set -euo pipefail

# sync.sh - Sync repositories to latest remote

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/yaml_parser.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [set-name] [options]

Fetch and pull latest changes for repositories.

Arguments:
  set-name    Name of the set to sync (optional, syncs all if not specified)

Options:
  --fetch-only      Only fetch, don't pull
  --force           Force pull even with local changes (stash and apply)
  --verbose, -v     Show verbose output
  --help, -h        Show this help message

Examples:
  $(basename "$0")              # Sync all repositories
  $(basename "$0") core         # Sync core set repositories
  $(basename "$0") --fetch-only # Only fetch updates

EOF
    exit 0
}

# Parse arguments
SET_NAME=""
FETCH_ONLY=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fetch-only)
            FETCH_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            if [[ -z "${SET_NAME}" ]]; then
                SET_NAME="$1"
            else
                die "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

# Check if repos directory exists
if [[ ! -d "${REPOS_DIR}" ]]; then
    die "Repos directory not found: ${REPOS_DIR}"
fi

# Build list of repos to sync
repos=()

if [[ -n "${SET_NAME}" ]]; then
    # Sync repos from set
    check_yq
    set_file=$(get_set_file "${SET_NAME}")
    log_info "Syncing set: ${SET_NAME}"

    while IFS=$'\t' read -r build_order name branch remote; do
        [[ -z "${name}" ]] && continue
        if [[ -d "${REPOS_DIR}/${name}/.git" ]]; then
            repos+=("${name}")
        fi
    done < <(yaml_get_unique_repos "${set_file}")
else
    # Sync all repos
    log_info "Syncing all repositories"
    for dir in "${REPOS_DIR}"/*/; do
        [[ -d "${dir}/.git" ]] && repos+=("$(basename "${dir}")")
    done
fi

if [[ ${#repos[@]} -eq 0 ]]; then
    log_warn "No repositories found to sync"
    exit 0
fi

print_header "Syncing ${#repos[@]} repositories"

sync_count=0
skip_count=0
error_count=0

for repo in "${repos[@]}"; do
    repo_path="${REPOS_DIR}/${repo}"

    echo ""
    log_info "Syncing: ${repo}"

    # Fetch
    if [[ "${VERBOSE}" == "true" ]]; then
        git -C "${repo_path}" fetch --all --prune
    else
        git -C "${repo_path}" fetch --all --prune --quiet
    fi

    if [[ "${FETCH_ONLY}" == "true" ]]; then
        log_success "Fetched: ${repo}"
        ((sync_count++))
        continue
    fi

    # Check for local changes
    status=$(git -C "${repo_path}" status --porcelain 2>/dev/null || true)
    if [[ -n "${status}" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            log_warn "Stashing local changes..."
            git -C "${repo_path}" stash push -m "sync.sh auto-stash"
            stashed=true
        else
            log_warn "Local changes detected, skipping pull (use --force to stash)"
            ((skip_count++))
            continue
        fi
    else
        stashed=false
    fi

    # Pull
    if git -C "${repo_path}" pull --ff-only; then
        log_success "Synced: ${repo}"
        ((sync_count++))
    else
        log_warn "Pull failed (non-fast-forward), trying rebase..."
        if git -C "${repo_path}" pull --rebase; then
            log_success "Synced (rebased): ${repo}"
            ((sync_count++))
        else
            log_error "Sync failed: ${repo}"
            ((error_count++))
        fi
    fi

    # Pop stash if we stashed
    if [[ "${stashed}" == "true" ]]; then
        log_info "Restoring stashed changes..."
        git -C "${repo_path}" stash pop || log_warn "Stash pop failed, changes remain in stash"
    fi

done

# Summary
print_header "Summary"
log_info "Synced: ${sync_count}"
log_info "Skipped: ${skip_count}"
if [[ ${error_count} -gt 0 ]]; then
    log_error "Errors: ${error_count}"
    exit 1
fi

log_success "Sync completed"
