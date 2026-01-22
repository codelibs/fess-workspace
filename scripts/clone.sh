#!/usr/bin/env bash
set -euo pipefail

# clone.sh - Clone repositories from a set definition

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/yaml_parser.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <set-name> [options]

Clone repositories defined in a set YAML file.
For existing repositories, switches to the specified branch and pulls latest changes.

Arguments:
  set-name    Name of the set to clone (e.g., core, plugins)

Options:
  --force, -f     Remove existing repositories before cloning
  --verbose, -v   Show verbose output
  --help, -h      Show this help message

Examples:
  $(basename "$0") core           # Clone or update core repositories
  $(basename "$0") plugins        # Clone or update plugin repositories (includes core)
  $(basename "$0") core --force   # Force re-clone (removes existing)

EOF
    exit 0
}

# Parse arguments
FORCE=false
VERBOSE=false
SET_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
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

if [[ -z "${SET_NAME}" ]]; then
    log_error "Set name is required"
    usage
fi

# Check prerequisites
check_yq

# Get set file
set_file=$(get_set_file "${SET_NAME}")
log_info "Using set: ${SET_NAME} (${set_file})"

# Ensure repos directory exists
ensure_repos_dir

# Get unique repositories with includes resolved
print_header "Cloning/Updating repositories"

clone_count=0
update_count=0
skip_count=0
error_count=0

# Read repos into array
while IFS=$'\t' read -r build_order name branch remote skip_build; do
    [[ -z "${name}" ]] && continue

    repo_path="${REPOS_DIR}/${name}"

    echo ""
    log_info "Repository: ${name}"
    log_info "  Remote: ${remote}"
    log_info "  Branch: ${branch}"

    if [[ -d "${repo_path}" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            log_warn "Removing existing repository: ${repo_path}"
            rm -rf "${repo_path}"
        else
            # Update existing repository: check branch and pull latest
            log_info "Updating existing repository: ${name}"

            pushd "${repo_path}" > /dev/null

            # Verify it's a git repository
            if ! git rev-parse --git-dir > /dev/null 2>&1; then
                log_error "Not a git repository: ${repo_path}"
                ((error_count++))
                popd > /dev/null
                continue
            fi

            # Get current branch
            current_branch=$(git rev-parse --abbrev-ref HEAD)

            # Fetch latest from remote
            if ! git fetch origin; then
                log_error "Failed to fetch from remote: ${name}"
                ((error_count++))
                popd > /dev/null
                continue
            fi

            # Switch branch if different
            if [[ "${current_branch}" != "${branch}" ]]; then
                log_info "Switching branch: ${current_branch} -> ${branch}"

                # Stash uncommitted changes if any
                if ! git diff --quiet || ! git diff --cached --quiet; then
                    log_warn "Uncommitted changes detected, stashing..."
                    git stash push -m "Auto-stashed by clone.sh"
                fi

                # Checkout branch (create from remote if doesn't exist locally)
                if git show-ref --verify --quiet "refs/heads/${branch}"; then
                    git checkout "${branch}"
                else
                    git checkout -b "${branch}" "origin/${branch}"
                fi
            fi

            # Pull latest (fast-forward only, or reset if that fails)
            if ! git pull --ff-only origin "${branch}" 2>/dev/null; then
                log_warn "Fast-forward failed, resetting to origin/${branch}"
                git reset --hard "origin/${branch}"
            fi

            popd > /dev/null

            log_success "Updated: ${name} (${branch})"
            ((update_count++))
            continue
        fi
    fi

    log_info "Cloning..."
    if git clone --branch "${branch}" "${remote}" "${repo_path}"; then
        log_success "Cloned: ${name}"
        ((clone_count++))
    else
        log_error "Failed to clone: ${name}"
        ((error_count++))
    fi

done < <(yaml_get_unique_repos "${set_file}")

# Summary
print_header "Summary"
log_info "Cloned: ${clone_count}, Updated: ${update_count}, Skipped: ${skip_count}, Errors: ${error_count}"
if [[ ${error_count} -gt 0 ]]; then
    log_error "Clone completed with errors"
    exit 1
fi

log_success "Clone completed"
