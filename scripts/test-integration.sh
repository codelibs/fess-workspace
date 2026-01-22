#!/usr/bin/env bash
set -euo pipefail

# test-integration.sh - Run integration tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Run integration tests for Fess.

Options:
  --skip-docker     Skip Docker service startup
  --verbose, -v     Show verbose output
  --help, -h        Show this help message

Prerequisites:
  - Docker and Docker Compose (unless --skip-docker)
  - Built Fess artifacts (run build.sh first)

Examples:
  $(basename "$0")               # Run integration tests
  $(basename "$0") --skip-docker # Skip Docker setup

EOF
    exit 0
}

# Parse arguments
SKIP_DOCKER=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-docker)
            SKIP_DOCKER=true
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

print_header "Integration Tests"

# Start Docker services if available
if [[ "${SKIP_DOCKER}" != "true" ]]; then
    if [[ -f "${ROOT_DIR}/env/docker-compose.yml" ]]; then
        log_info "Starting Docker services..."
        if command -v docker &>/dev/null; then
            (cd "${ROOT_DIR}/env" && docker compose up -d)
            log_success "Docker services started"
        else
            log_warn "Docker not found, skipping service startup"
        fi
    else
        log_info "No docker-compose.yml found in env/, skipping service startup"
    fi
fi

# Run integration tests
log_info "Running smoke tests..."

# Check if Fess is built
if [[ -d "${REPOS_DIR}/fess/target" ]]; then
    log_info "Fess build artifacts found"
else
    log_warn "Fess build artifacts not found. Run './scripts/build.sh core' first."
fi

# Placeholder for actual integration test commands
# Add your test commands here:
# - Run crawler against a sample site
# - Verify indexed documents
# - Call Fess API/health endpoints
# - Run end-to-end tests

# Example: Check if Fess can be started
# if [[ -f "${REPOS_DIR}/fess/target/fess-*.zip" ]]; then
#     log_info "Found Fess distribution package"
# fi

log_success "Integration tests completed"
log_info "Note: Add your specific integration test commands to this script"
