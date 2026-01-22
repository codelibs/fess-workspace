#!/usr/bin/env bash
set -euo pipefail

# build.sh - Build repositories in dependency order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/yaml_parser.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <set-name> [options]

Build repositories defined in a set YAML file in dependency order.

Arguments:
  set-name    Name of the set to build (e.g., core, plugins)

Options:
  --with-tests       Run tests during build (mvn install)
  --skip-tests       Skip tests (default, mvn install -DskipTests)
  --clean            Clean before build (mvn clean install)
  --offline          Build in offline mode (mvn -o)
  --verbose, -v      Show verbose Maven output
  --help, -h         Show this help message

Examples:
  $(basename "$0") core                 # Build core (skip tests)
  $(basename "$0") core --with-tests    # Build core with tests
  $(basename "$0") core --clean         # Clean build
  $(basename "$0") plugins              # Build all plugins

EOF
    exit 0
}

# Parse arguments
SET_NAME=""
WITH_TESTS=false
CLEAN=false
OFFLINE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-tests)
            WITH_TESTS=true
            shift
            ;;
        --skip-tests)
            WITH_TESTS=false
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --offline)
            OFFLINE=true
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
require_cmd mvn

# Get set file
set_file=$(get_set_file "${SET_NAME}")
log_info "Using set: ${SET_NAME} (${set_file})"

# Build Maven arguments
MVN_ARGS=("install")

if [[ "${CLEAN}" == "true" ]]; then
    MVN_ARGS=("clean" "install")
fi

if [[ "${WITH_TESTS}" != "true" ]]; then
    MVN_ARGS+=("-DskipTests")
fi

if [[ "${OFFLINE}" == "true" ]]; then
    MVN_ARGS+=("-o")
fi

if [[ "${VERBOSE}" != "true" ]]; then
    MVN_ARGS+=("-q")
fi

print_header "Build Configuration"
log_info "Maven command: mvn ${MVN_ARGS[*]}"
log_info "Tests: ${WITH_TESTS}"
log_info "Clean: ${CLEAN}"
log_info "Offline: ${OFFLINE}"

# Build repositories in order
print_header "Building repositories"

build_count=0
skip_count=0
error_count=0

while IFS=$'\t' read -r build_order name branch remote skip_build; do
    [[ -z "${name}" ]] && continue

    repo_path="${REPOS_DIR}/${name}"

    echo ""
    log_info "[${build_order}] Building: ${name}"

    # Explicit skip via skip_build flag
    if [[ "${skip_build}" == "true" ]]; then
        log_info "Skipping ${name} (skip_build=true)"
        ((skip_count++))
        continue
    fi

    if [[ ! -d "${repo_path}" ]]; then
        log_warn "Repository not found: ${repo_path} (run clone.sh first)"
        ((skip_count++))
        continue
    fi

    if [[ ! -f "${repo_path}/pom.xml" ]]; then
        log_warn "No pom.xml found in ${name}, skipping"
        ((skip_count++))
        continue
    fi

    if (cd "${repo_path}" && mvn "${MVN_ARGS[@]}"); then
        log_success "Built: ${name}"
        ((build_count++))
    else
        log_error "Build failed: ${name}"
        ((error_count++))
        die "Stopping build due to error in ${name}"
    fi

done < <(yaml_get_unique_repos "${set_file}")

# Summary
print_header "Summary"
log_info "Built: ${build_count}"
log_info "Skipped: ${skip_count}"
if [[ ${error_count} -gt 0 ]]; then
    log_error "Errors: ${error_count}"
    exit 1
fi

log_success "Build completed"
