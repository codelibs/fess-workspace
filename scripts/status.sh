#!/usr/bin/env bash
set -euo pipefail

# status.sh - Show status of all repositories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Show git status of all repositories in repos/ directory.

Options:
  --short, -s     Show compact output
  --verbose, -v   Show detailed output including remote info
  --help, -h      Show this help message

Examples:
  $(basename "$0")          # Show status of all repos
  $(basename "$0") --short  # Compact output

EOF
    exit 0
}

# Parse arguments
SHORT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --short|-s)
            SHORT=true
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
            die "Unexpected argument: $1"
            ;;
    esac
done

# Check if repos directory exists
if [[ ! -d "${REPOS_DIR}" ]]; then
    die "Repos directory not found: ${REPOS_DIR}"
fi

# Get list of repositories
repos=()
for dir in "${REPOS_DIR}"/*/; do
    [[ -d "${dir}/.git" ]] && repos+=("$(basename "${dir}")")
done

if [[ ${#repos[@]} -eq 0 ]]; then
    log_warn "No repositories found in ${REPOS_DIR}"
    log_info "Run ./scripts/clone.sh <set-name> to clone repositories"
    exit 0
fi

print_header "Repository Status"
log_info "Found ${#repos[@]} repositories"
echo ""

for repo in "${repos[@]}"; do
    repo_path="${REPOS_DIR}/${repo}"

    # Get git info
    branch=$(cd "${repo_path}" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    commit=$(cd "${repo_path}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    status=$(cd "${repo_path}" && git status --porcelain 2>/dev/null || true)

    # Check for uncommitted changes
    if [[ -n "${status}" ]]; then
        status_indicator="${COLOR_YELLOW}*${COLOR_RESET}"
        change_count=$(echo "${status}" | wc -l | tr -d ' ')
    else
        status_indicator="${COLOR_GREEN}✓${COLOR_RESET}"
        change_count=0
    fi

    # Check ahead/behind
    ahead_behind=""
    if git -C "${repo_path}" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
        ahead=$(git -C "${repo_path}" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
        behind=$(git -C "${repo_path}" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "0")
        if [[ "${ahead}" -gt 0 ]] || [[ "${behind}" -gt 0 ]]; then
            ahead_behind=" [↑${ahead} ↓${behind}]"
        fi
    fi

    if [[ "${SHORT}" == "true" ]]; then
        # Compact output
        echo -e "${status_indicator} ${repo}: ${branch} (${commit})${ahead_behind}"
    else
        # Standard output
        echo -e "${status_indicator} ${COLOR_BLUE}${repo}${COLOR_RESET}"
        echo "    Branch: ${branch}"
        echo "    Commit: ${commit}${ahead_behind}"

        if [[ "${VERBOSE}" == "true" ]]; then
            remote_url=$(git -C "${repo_path}" remote get-url origin 2>/dev/null || echo "no remote")
            echo "    Remote: ${remote_url}"
        fi

        if [[ -n "${status}" ]]; then
            echo -e "    ${COLOR_YELLOW}Changes: ${change_count} file(s)${COLOR_RESET}"
            if [[ "${VERBOSE}" == "true" ]]; then
                echo "${status}" | head -5 | sed 's/^/      /'
                if [[ ${change_count} -gt 5 ]]; then
                    echo "      ... and $((change_count - 5)) more"
                fi
            fi
        fi
        echo ""
    fi
done

# Summary
if [[ "${SHORT}" != "true" ]]; then
    print_separator
fi
