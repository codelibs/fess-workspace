#!/usr/bin/env bash
# Shared helpers for fess-version-bump scripts.
# Source this file; it expects the fess-workspace root directory.

set -euo pipefail

# --- Workspace detection -----------------------------------------------------

find_workspace() {
  local dir="${1:-$PWD}"
  while [[ "${dir}" != "/" ]]; do
    if [[ -f "${dir}/sets/all.yaml" && -d "${dir}/repos" && -d "${dir}/scripts" ]]; then
      printf '%s\n' "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

require_workspace() {
  local ws
  if ! ws="$(find_workspace)"; then
    echo "ERROR: Not inside fess-workspace (need sets/all.yaml + repos/ + scripts/)." >&2
    exit 1
  fi
  printf '%s\n' "${ws}"
}

# --- Target repository list --------------------------------------------------
# Emit "<repo>\t<default-branch>" lines for every Fess-related Maven repo
# listed in sets/all.yaml that has a pom.xml on disk.
#
# Excludes repos whose version is maintained independently of the main Fess
# release cadence (corelib, curl4j, fesen-httpclient, java-saml, jcifs,
# jhighlight, nekohtml, spnego) and docs-only / site-only repos.

list_target_repos() {
  local ws="$1"
  local set_file="${ws}/sets/all.yaml"

  # Uses yq to emit TSV of name + branch, filtered by directory existence and pom.xml presence.
  yq -r '
    .defaults.branch as $defbr
    | .repositories[]
    | select(.skip_build != true)
    | [.name, (.branch // $defbr)]
    | @tsv
  ' "${set_file}" |
  while IFS=$'\t' read -r name branch; do
    case "${name}" in
      corelib|curl4j|fesen-httpclient|java-saml|jcifs|jhighlight|nekohtml|spnego) continue ;;
      docker-fess|fessctl|fess-kopf|fess-test-ui|fess-docs) continue ;;
    esac
    if [[ -f "${ws}/repos/${name}/pom.xml" ]]; then
      printf '%s\t%s\n' "${name}" "${branch}"
    fi
  done
}

# --- Logging ------------------------------------------------------------------

log()   { printf '[%s] %s\n' "${1}" "${2}" >&2; }
info()  { log INFO  "$*"; }
warn()  { log WARN  "$*"; }
error() { log ERROR "$*"; }
ok()    { log OK    "$*"; }
