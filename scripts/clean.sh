#!/usr/bin/env bash
set -euo pipefail

# clean.sh - Clean build artifacts in repositories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Clean build artifacts in repos/ repositories.
Automatically detects each repository's build system and runs the appropriate clean command.

Options:
  --target          Quick clean: remove build output directories directly (no mvn/npm)
  --help, -h        Show this help message

Build system detection:
  pom.xml           → mvn clean
  package.json      → rm -rf node_modules coverage _site
  pyproject.toml    → rm -rf __pycache__ .pytest_cache dist build *.egg-info
  (other)           → skip

Examples:
  $(basename "$0")           # Clean all repos using build tools
  $(basename "$0") --target  # Quick clean: remove build output dirs directly

EOF
    exit 0
}

# Parse arguments
TARGET_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
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

# Collect repositories
repos=()
for dir in "${REPOS_DIR}"/*/; do
    [[ -d "${dir}" ]] && repos+=("$(basename "${dir}")")
done

if [[ ${#repos[@]} -eq 0 ]]; then
    log_info "No repositories found in ${REPOS_DIR}"
    exit 0
fi

# Clean a Maven repository using build output removal
clean_target_maven() {
    local repo_path="$1"
    local repo_name="$2"
    local target_dir="${repo_path}/target"
    if [[ -d "${target_dir}" ]]; then
        rm -rf "${target_dir}"
        log_success "Cleaned: ${repo_name}/target"
        return 0
    fi
    return 1
}

# Clean a Node.js repository using build output removal
clean_target_node() {
    local repo_path="$1"
    local repo_name="$2"
    local cleaned=false
    for artifact in node_modules coverage _site; do
        if [[ -d "${repo_path}/${artifact}" ]]; then
            rm -rf "${repo_path}/${artifact}"
            cleaned=true
        fi
    done
    if [[ "${cleaned}" == "true" ]]; then
        log_success "Cleaned: ${repo_name} (node artifacts)"
        return 0
    fi
    return 1
}

# Clean a Python repository using build output removal
clean_target_python() {
    local repo_path="$1"
    local repo_name="$2"
    local cleaned=false
    for artifact in __pycache__ .pytest_cache dist build; do
        if [[ -d "${repo_path}/${artifact}" ]]; then
            rm -rf "${repo_path}/${artifact}"
            cleaned=true
        fi
    done
    # Remove *.egg-info directories
    while IFS= read -r -d '' egg_dir; do
        rm -rf "${egg_dir}"
        cleaned=true
    done < <(find "${repo_path}" -maxdepth 2 -name "*.egg-info" -type d -print0 2>/dev/null)
    # Remove nested __pycache__ directories
    while IFS= read -r -d '' cache_dir; do
        rm -rf "${cache_dir}"
        cleaned=true
    done < <(find "${repo_path}" -name "__pycache__" -type d -print0 2>/dev/null)
    if [[ "${cleaned}" == "true" ]]; then
        log_success "Cleaned: ${repo_name} (python artifacts)"
        return 0
    fi
    return 1
}

if [[ "${TARGET_ONLY}" == "true" ]]; then
    print_header "Quick clean: removing build output directories"
    log_info "Found ${#repos[@]} repositories"

    clean_count=0
    for repo in "${repos[@]}"; do
        repo_path="${REPOS_DIR}/${repo}"
        if [[ -f "${repo_path}/pom.xml" ]]; then
            clean_target_maven "${repo_path}" "${repo}" && ((clean_count+=1))
        elif [[ -f "${repo_path}/package.json" ]]; then
            clean_target_node "${repo_path}" "${repo}" && ((clean_count+=1))
        elif [[ -f "${repo_path}/pyproject.toml" ]]; then
            clean_target_python "${repo_path}" "${repo}" && ((clean_count+=1))
        fi
    done

    log_info "Cleaned ${clean_count} repositories"
else
    print_header "Cleaning build artifacts"
    log_info "Found ${#repos[@]} repositories"

    clean_count=0
    skip_count=0
    fail_count=0

    for repo in "${repos[@]}"; do
        repo_path="${REPOS_DIR}/${repo}"

        if [[ -f "${repo_path}/pom.xml" ]]; then
            log_info "Cleaning ${repo} (maven)..."
            if (cd "${repo_path}" && mvn clean -q 2>&1); then
                log_success "Cleaned: ${repo}"
                ((clean_count+=1))
            else
                log_error "Failed to clean: ${repo}"
                ((fail_count+=1))
            fi
        elif [[ -f "${repo_path}/package.json" ]]; then
            log_info "Cleaning ${repo} (node)..."
            clean_target_node "${repo_path}" "${repo}" && ((clean_count+=1)) || {
                log_info "Nothing to clean: ${repo}"
                ((skip_count+=1))
            }
        elif [[ -f "${repo_path}/pyproject.toml" ]]; then
            log_info "Cleaning ${repo} (python)..."
            clean_target_python "${repo_path}" "${repo}" && ((clean_count+=1)) || {
                log_info "Nothing to clean: ${repo}"
                ((skip_count+=1))
            }
        else
            log_info "Skipping ${repo} (no known build system)"
            ((skip_count+=1))
        fi
    done

    echo ""
    log_info "Results: ${clean_count} cleaned, ${skip_count} skipped, ${fail_count} failed"
fi
