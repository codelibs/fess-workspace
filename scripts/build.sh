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

# Prepare log directory
LOG_DIR="${ROOT_DIR}/logs/build"
mkdir -p "${LOG_DIR}"

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

print_header "Build Configuration"
log_info "Maven command: mvn ${MVN_ARGS[*]}"
log_info "Tests: ${WITH_TESTS}"
log_info "Clean: ${CLEAN}"
log_info "Offline: ${OFFLINE}"
log_info "Log directory: ${LOG_DIR}"

# Count total repositories
total_count=$(yaml_get_unique_repos "${set_file}" | wc -l)

# Build repositories in order
print_header "Building repositories"

build_count=0
skip_count=0
error_count=0
built_repos=()
skipped_repos=()
failed_repos=()
overall_start=$(date +%s)
current=0

while IFS=$'\t' read -r build_order name branch remote skip_build; do
    [[ -z "${name}" ]] && continue

    ((current+=1))
    repo_path="${REPOS_DIR}/${name}"

    # Explicit skip via skip_build flag
    if [[ "${skip_build}" == "true" ]]; then
        log_info "[${current}/${total_count}] Skipping: ${name} (skip_build=true)"
        ((skip_count+=1))
        skipped_repos+=("${name}")
        continue
    fi

    if [[ ! -d "${repo_path}" ]]; then
        log_warn "[${current}/${total_count}] Skipping: ${name} (not cloned)"
        ((skip_count+=1))
        skipped_repos+=("${name}")
        continue
    fi

    if [[ ! -f "${repo_path}/pom.xml" ]]; then
        log_warn "[${current}/${total_count}] Skipping: ${name} (no pom.xml)"
        ((skip_count+=1))
        skipped_repos+=("${name}")
        continue
    fi

    local_log_file="${LOG_DIR}/${name}.log"
    start_time=$(date +%s)

    if [[ "${VERBOSE}" == "true" ]]; then
        echo ""
        log_info "[${current}/${total_count}] Building: ${name}"
        if (cd "${repo_path}" && mvn "${MVN_ARGS[@]}" 2>&1 | tee "${local_log_file}"); then
            elapsed=$(($(date +%s) - start_time))
            log_success "${name} (${elapsed}s)"
            ((build_count+=1))
            built_repos+=("${name}")
        else
            elapsed=$(($(date +%s) - start_time))
            log_error "Build failed: ${name} (${elapsed}s)"
            ((error_count+=1))
            failed_repos+=("${name}")
            echo "--- Full log: ${local_log_file} ---"
            die "Stopping build due to error in ${name}"
        fi
    else
        printf "[%d/%d] Building: %s ..." "${current}" "${total_count}" "${name}"
        if (cd "${repo_path}" && mvn "${MVN_ARGS[@]}" > "${local_log_file}" 2>&1); then
            elapsed=$(($(date +%s) - start_time))
            printf "\r\033[K"
            log_success "[${current}/${total_count}] ${name} (${elapsed}s)"
            ((build_count+=1))
            built_repos+=("${name}")
        else
            elapsed=$(($(date +%s) - start_time))
            printf "\r\033[K"
            log_error "[${current}/${total_count}] ${name} (${elapsed}s)"
            ((error_count+=1))
            failed_repos+=("${name}")
            echo ""
            echo "--- Last 20 lines of ${local_log_file} ---"
            tail -20 "${local_log_file}"
            echo "--- Full log: ${local_log_file} ---"
            die "Stopping build due to error in ${name}"
        fi
    fi

done < <(yaml_get_unique_repos "${set_file}")

# Summary
overall_elapsed=$(($(date +%s) - overall_start))

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " Build Summary"
echo "═══════════════════════════════════════════════════════════"

if [[ ${build_count} -gt 0 ]]; then
    log_success "Built:   ${build_count}  (total ${overall_elapsed}s)"
    for repo in "${built_repos[@]}"; do
        echo "           ${repo}"
    done
fi

if [[ ${skip_count} -gt 0 ]]; then
    log_warn "Skipped: ${skip_count}"
    for repo in "${skipped_repos[@]}"; do
        echo "           ${repo}"
    done
fi

if [[ ${error_count} -gt 0 ]]; then
    log_error "Failed:  ${error_count}"
    for repo in "${failed_repos[@]}"; do
        echo "           ${repo}"
        echo "           → ${LOG_DIR}/${repo}.log"
    done
fi

echo "═══════════════════════════════════════════════════════════"

if [[ ${error_count} -gt 0 ]]; then
    exit 1
fi

log_success "Build completed (${overall_elapsed}s)"
