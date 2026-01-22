#!/usr/bin/env bash
# common.sh - Shared functions for fess-workspace scripts

# Colors for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPOS_DIR="${ROOT_DIR}/repos"
SETS_DIR="${ROOT_DIR}/sets"

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Exit with error message
die() {
    log_error "$@"
    exit 1
}

# Check if a command exists
require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        die "Required command not found: ${cmd}"
    fi
}

# Check prerequisites
check_prerequisites() {
    require_cmd git
    require_cmd yq
    require_cmd mvn
}

# Check if yq is available
check_yq() {
    if ! command -v yq &>/dev/null; then
        die "yq is required but not installed. Install with: brew install yq"
    fi
}

# Ensure repos directory exists
ensure_repos_dir() {
    mkdir -p "${REPOS_DIR}"
}

# Get the set file path
get_set_file() {
    local set_name="$1"
    local set_file="${SETS_DIR}/${set_name}.yaml"

    if [[ ! -f "${set_file}" ]]; then
        die "Set file not found: ${set_file}"
    fi

    echo "${set_file}"
}

# Check if a repository directory exists
repo_exists() {
    local repo_name="$1"
    [[ -d "${REPOS_DIR}/${repo_name}/.git" ]]
}

# Get repository path
get_repo_path() {
    local repo_name="$1"
    echo "${REPOS_DIR}/${repo_name}"
}

# Print a separator line
print_separator() {
    echo "─────────────────────────────────────────────────────────────"
}

# Print section header
print_header() {
    echo ""
    print_separator
    echo -e "${COLOR_BLUE}$*${COLOR_RESET}"
    print_separator
}

# Confirm action with user
confirm() {
    local message="${1:-Continue?}"
    read -r -p "${message} [y/N] " response
    [[ "${response}" =~ ^[Yy]$ ]]
}

# Parse command line for common flags
parse_common_flags() {
    FORCE=false
    VERBOSE=false

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
            *)
                shift
                ;;
        esac
    done
}
