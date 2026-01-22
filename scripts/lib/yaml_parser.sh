#!/usr/bin/env bash
# yaml_parser.sh - YAML parsing functions using yq

# Source common functions if not already loaded
if [[ -z "${ROOT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

# Get set name from YAML file
yaml_get_set_name() {
    local set_file="$1"
    yq -r '.name // ""' "${set_file}"
}

# Get set description
yaml_get_set_description() {
    local set_file="$1"
    yq -r '.description // ""' "${set_file}"
}

# Get default remote base URL
yaml_get_remote_base() {
    local set_file="$1"
    yq -r '.defaults.remote_base // "git@github.com:codelibs"' "${set_file}"
}

# Get default branch
yaml_get_default_branch() {
    local set_file="$1"
    yq -r '.defaults.branch // "master"' "${set_file}"
}

# Get list of included set files
yaml_get_includes() {
    local set_file="$1"
    yq -r '.includes[]?' "${set_file}" 2>/dev/null || true
}

# Get repository count
yaml_get_repo_count() {
    local set_file="$1"
    yq -r '.repositories | length' "${set_file}"
}

# Get repository name at index
yaml_get_repo_name() {
    local set_file="$1"
    local index="$2"
    yq -r ".repositories[${index}].name // \"\"" "${set_file}"
}

# Get repository branch (falls back to default)
yaml_get_repo_branch() {
    local set_file="$1"
    local index="$2"
    local default_branch
    default_branch=$(yaml_get_default_branch "${set_file}")
    yq -r ".repositories[${index}].branch // \"${default_branch}\"" "${set_file}"
}

# Get repository build order
yaml_get_repo_build_order() {
    local set_file="$1"
    local index="$2"
    yq -r ".repositories[${index}].build_order // 99" "${set_file}"
}

# Get repository remote URL (override or default)
yaml_get_repo_remote() {
    local set_file="$1"
    local index="$2"
    local repo_name
    local remote_base

    repo_name=$(yaml_get_repo_name "${set_file}" "${index}")
    remote_override=$(yq -r ".repositories[${index}].remote // \"\"" "${set_file}")

    if [[ -n "${remote_override}" ]]; then
        echo "${remote_override}"
    else
        remote_base=$(yaml_get_remote_base "${set_file}")
        echo "${remote_base}/${repo_name}.git"
    fi
}

# Get all repositories as JSON array (for processing)
yaml_get_all_repos_json() {
    local set_file="$1"
    yq -o=json '.repositories // []' "${set_file}"
}

# Get repositories sorted by build order
# Output format: build_order|name|branch|remote|skip_build
yaml_get_repos_by_build_order() {
    local set_file="$1"
    local remote_base
    local default_branch

    remote_base=$(yaml_get_remote_base "${set_file}")
    default_branch=$(yaml_get_default_branch "${set_file}")

    yq -r "
        .repositories[]? |
        [
            (.build_order // 99),
            .name,
            (.branch // \"${default_branch}\"),
            (.remote // \"${remote_base}/\" + .name + \".git\"),
            (.skip_build // false)
        ] | @tsv
    " "${set_file}" | sort -t$'\t' -k1 -n
}

# Process set file with includes (recursive)
# Returns combined list of unique repos in build order
yaml_process_set_with_includes() {
    local set_file="$1"
    local processed_files="${2:-}"
    local set_dir

    set_dir=$(dirname "${set_file}")

    # Prevent circular includes
    if echo "${processed_files}" | grep -q "${set_file}"; then
        return
    fi
    processed_files="${processed_files}:${set_file}"

    # Process includes first
    local includes
    includes=$(yaml_get_includes "${set_file}")

    for include in ${includes}; do
        local include_path="${set_dir}/${include}"
        if [[ -f "${include_path}" ]]; then
            yaml_process_set_with_includes "${include_path}" "${processed_files}"
        else
            log_warn "Include file not found: ${include_path}"
        fi
    done

    # Output repos from this file
    yaml_get_repos_by_build_order "${set_file}"
}

# Get unique repositories from set (including includes)
# Output: sorted unique list by build order
yaml_get_unique_repos() {
    local set_file="$1"
    yaml_process_set_with_includes "${set_file}" "" | sort -t$'\t' -k1 -n -k2 -u | sort -t$'\t' -k1 -n
}
