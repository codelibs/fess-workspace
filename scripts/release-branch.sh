#!/usr/bin/env bash
set -euo pipefail

# release-branch.sh - Create release branches and update versions for repositories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/yaml_parser.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <set-name> --release-branch <branch> --new-version <version> [options]

Create release branches and PRs to update versions for next development cycle.

Arguments:
  set-name              Name of the set to process (e.g., ds-plugins, webapp-plugins)

Required Options:
  --release-branch, -r  Release branch name to create (e.g., 15.4.x)
  --new-version, -n     New version for main branch (e.g., 15.5.0-SNAPSHOT)

Options:
  --dry-run             Show what would be done without making changes
  --skip-existing       Skip repositories where release branch already exists (default)
  --force-version       Update version even if release branch already exists
  --verbose, -v         Show verbose output
  --help, -h            Show this help message

Examples:
  $(basename "$0") ds-plugins -r 15.4.x -n 15.5.0-SNAPSHOT
  $(basename "$0") webapp-plugins -r 15.4.x -n 15.5.0-SNAPSHOT --dry-run
  $(basename "$0") all -r 15.5.x -n 15.6.0-SNAPSHOT

Notes:
  - Repositories must be cloned first (use clone.sh)
  - GitHub CLI (gh) must be authenticated
  - Creates release branch from default branch (main/master)
  - Updates pom.xml project version and parent version
  - Creates PR for version update

EOF
    exit 0
}

# Parse arguments
DRY_RUN=false
VERBOSE=false
SKIP_EXISTING=true
FORCE_VERSION=false
SET_NAME=""
RELEASE_BRANCH=""
NEW_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release-branch|-r)
            RELEASE_BRANCH="$2"
            shift 2
            ;;
        --new-version|-n)
            NEW_VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-existing)
            SKIP_EXISTING=true
            shift
            ;;
        --force-version)
            FORCE_VERSION=true
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

# Validate required arguments
if [[ -z "${SET_NAME}" ]]; then
    log_error "Set name is required"
    usage
fi

if [[ -z "${RELEASE_BRANCH}" ]]; then
    log_error "--release-branch is required"
    usage
fi

if [[ -z "${NEW_VERSION}" ]]; then
    log_error "--new-version is required"
    usage
fi

# Validate version format
if [[ ! "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT$ ]]; then
    log_warn "Version '${NEW_VERSION}' doesn't match expected format (X.Y.Z-SNAPSHOT)"
fi

# Check prerequisites
check_yq
require_cmd gh
require_cmd perl

# Check gh auth
if ! gh auth status &>/dev/null; then
    die "GitHub CLI is not authenticated. Run: gh auth login"
fi

# Get set file
set_file=$(get_set_file "${SET_NAME}")
log_info "Using set: ${SET_NAME} (${set_file})"
log_info "Release branch: ${RELEASE_BRANCH}"
log_info "New version: ${NEW_VERSION}"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY RUN mode - no changes will be made"
fi

# Extract version prefix for matching (e.g., "15.4" from "15.5.0-SNAPSHOT")
VERSION_MAJOR_MINOR=$(echo "${NEW_VERSION}" | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
CURRENT_VERSION_PATTERN=$(echo "${RELEASE_BRANCH}" | sed 's/\.x$//')

log_info "Current version pattern: ${CURRENT_VERSION_PATTERN}.x"
log_info "New version major.minor: ${VERSION_MAJOR_MINOR}"

# Counters
branch_created=0
pr_created=0
skipped=0
error_count=0

print_header "Processing repositories"

# Get default branch for a repository
get_default_branch() {
    local repo_path="$1"
    pushd "${repo_path}" > /dev/null

    if git show-ref --verify --quiet refs/heads/main; then
        echo "main"
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
    else
        echo "main"  # fallback
    fi

    popd > /dev/null
}

# Check if remote branch exists
remote_branch_exists() {
    local repo_path="$1"
    local branch="$2"
    pushd "${repo_path}" > /dev/null
    git ls-remote --heads origin "${branch}" | grep -q "${branch}"
    local result=$?
    popd > /dev/null
    return ${result}
}

# Process a single repository
process_repo() {
    local name="$1"
    local repo_path="${REPOS_DIR}/${name}"

    echo ""
    log_info "Processing: ${name}"

    # Check if repo exists
    if [[ ! -d "${repo_path}" ]]; then
        log_warn "Skipping ${name}: directory does not exist (run clone.sh first)"
        ((skipped+=1))
        return 0
    fi

    # Check if it's a git repo
    if [[ ! -d "${repo_path}/.git" ]]; then
        log_warn "Skipping ${name}: not a git repository"
        ((skipped+=1))
        return 0
    fi

    # Check if pom.xml exists
    if [[ ! -f "${repo_path}/pom.xml" ]]; then
        log_warn "Skipping ${name}: no pom.xml found"
        ((skipped+=1))
        return 0
    fi

    local default_branch
    default_branch=$(get_default_branch "${repo_path}")

    # Check if release branch already exists
    if remote_branch_exists "${repo_path}" "${RELEASE_BRANCH}"; then
        if [[ "${SKIP_EXISTING}" == "true" && "${FORCE_VERSION}" == "false" ]]; then
            log_warn "Skipping ${name}: ${RELEASE_BRANCH} branch already exists"
            ((skipped+=1))
            return 0
        fi
        log_info "${RELEASE_BRANCH} branch already exists, will only update version"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY RUN] Would create ${RELEASE_BRANCH} branch from ${default_branch}"
        log_info "[DRY RUN] Would update pom.xml to ${NEW_VERSION}"
        log_info "[DRY RUN] Would create PR for version update"
        ((branch_created+=1))
        ((pr_created+=1))
        return 0
    fi

    pushd "${repo_path}" > /dev/null

    # Fetch latest
    git fetch origin

    # Step 1: Create and push release branch (if not exists)
    if ! remote_branch_exists "${repo_path}" "${RELEASE_BRANCH}"; then
        log_info "Creating ${RELEASE_BRANCH} branch from ${default_branch}"
        git checkout "${default_branch}"
        git pull origin "${default_branch}"
        git checkout -b "${RELEASE_BRANCH}"
        git push -u origin "${RELEASE_BRANCH}"
        ((branch_created+=1))
        log_success "Created branch: ${RELEASE_BRANCH}"
    fi

    # Step 2: Create version update branch
    local update_branch="update-version-${NEW_VERSION%%-SNAPSHOT}"
    log_info "Creating ${update_branch} branch"

    git checkout "${default_branch}"
    git pull origin "${default_branch}"

    # Remove local branch if exists
    if git show-ref --verify --quiet "refs/heads/${update_branch}"; then
        git branch -D "${update_branch}"
    fi

    git checkout -b "${update_branch}"

    # Step 3: Update pom.xml versions
    log_info "Updating pom.xml versions to ${NEW_VERSION}"

    # Update project version (X.Y.Z-SNAPSHOT -> NEW_VERSION)
    sed -i '' "s|<version>${CURRENT_VERSION_PATTERN}\.[0-9]*-SNAPSHOT</version>|<version>${NEW_VERSION}</version>|" pom.xml

    # Update parent version (fess-parent X.Y.Z -> NEW_VERSION without -SNAPSHOT for release, or with for snapshot)
    # Handle both released parent (15.4.0) and snapshot parent (15.4.0-SNAPSHOT)
    perl -i -0pe "s|(<artifactId>fess-parent</artifactId>\\s*<version>)${CURRENT_VERSION_PATTERN}\\.[0-9]+(-SNAPSHOT)?|\${1}${NEW_VERSION}|s" pom.xml

    # Step 4: Commit and push
    if git diff --quiet pom.xml; then
        log_warn "No changes to pom.xml, skipping commit"
        git checkout "${default_branch}"
        popd > /dev/null
        return 0
    fi

    git add pom.xml
    git commit -m "Update version to ${NEW_VERSION}"
    git push -u origin "${update_branch}"

    # Step 5: Create PR
    log_info "Creating PR"
    local pr_url
    pr_url=$(gh pr create \
        --title "Update version to ${NEW_VERSION}" \
        --body "Update version for next development cycle" \
        --base "${default_branch}" \
        --head "${update_branch}" 2>&1) || {
        # PR might already exist
        if echo "${pr_url}" | grep -q "already exists"; then
            log_warn "PR already exists for ${update_branch}"
        else
            log_error "Failed to create PR: ${pr_url}"
            ((error_count+=1))
            popd > /dev/null
            return 1
        fi
    }

    if [[ -n "${pr_url}" ]] && [[ "${pr_url}" =~ ^https:// ]]; then
        log_success "Created PR: ${pr_url}"
        ((pr_created+=1))
    fi

    # Return to default branch
    git checkout "${default_branch}"

    popd > /dev/null

    log_success "Done: ${name}"
}

# Read repos and process
while IFS=$'\t' read -r build_order name branch remote skip_build; do
    [[ -z "${name}" ]] && continue

    if ! process_repo "${name}"; then
        log_error "Failed to process: ${name}"
    fi

done < <(yaml_get_unique_repos "${set_file}")

# Summary
print_header "Summary"
log_info "Release branches created: ${branch_created}"
log_info "PRs created: ${pr_created}"
log_info "Skipped: ${skipped}"
log_info "Errors: ${error_count}"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY RUN - no actual changes were made"
fi

if [[ ${error_count} -gt 0 ]]; then
    log_error "Completed with errors"
    exit 1
fi

log_success "Release branch creation completed"
