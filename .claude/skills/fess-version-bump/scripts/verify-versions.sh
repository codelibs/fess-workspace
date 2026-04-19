#!/usr/bin/env bash
# Verify that every target repo has (a) the release branch on origin and
# (b) all pom.xml files bumped to the new version with no stale old references.
#
# Usage:
#   scripts/verify-versions.sh --old 15.6 --new 15.7.0-SNAPSHOT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

OLD_MM=""
NEW_VER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --old) OLD_MM="$2"; shift 2 ;;
    --new) NEW_VER="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) error "unknown arg: $1"; exit 2 ;;
  esac
done

[[ -n "${OLD_MM}" && -n "${NEW_VER}" ]] || { error "--old and --new required"; exit 2; }

WS="$(require_workspace)"
RELEASE_BRANCH="${OLD_MM}.x"

pass=0; fail=0

printf '%-32s %-8s %-8s %s\n' "REPO" "REL_BR" "POM_OK" "DETAIL"
printf -- '-%.0s' {1..90}; printf '\n'

while IFS=$'\t' read -r repo branch; do
  path="${WS}/repos/${repo}"
  cd "${path}"

  # Release branch present?
  if git ls-remote --heads origin "${RELEASE_BRANCH}" | grep -q "refs/heads/${RELEASE_BRANCH}"; then
    br=YES
  else
    br=NO
  fi

  # Any pom.xml still at OLD_MM.* ?  (|| true to tolerate SIGPIPE from head/grep exit 1)
  stale="$({ find . -name pom.xml -not -path '*/target/*' -not -path '*/node_modules/*' -print0 \
    | xargs -0 grep -l "<version>${OLD_MM}\." 2>/dev/null || true; } | tr '\n' ' ')"
  # Any pom.xml with the new version?
  has_new="$({ find . -name pom.xml -not -path '*/target/*' -not -path '*/node_modules/*' -print0 \
    | xargs -0 grep -l "<version>${NEW_VER}</version>" 2>/dev/null || true; } | wc -l | tr -d ' ')"

  pom_ok=YES
  detail=""
  if [[ "${br}" != "YES" ]]; then pom_ok=NO; detail="no ${RELEASE_BRANCH}"; fi
  if [[ -n "${stale}" ]]; then pom_ok=NO; detail="stale: ${stale}"; fi
  if [[ "${has_new}" -lt 1 ]]; then pom_ok=NO; detail="no ${NEW_VER} found"; fi

  if [[ "${pom_ok}" == "YES" && "${br}" == "YES" ]]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
  fi
  printf '%-32s %-8s %-8s %s\n' "${repo}" "${br}" "${pom_ok}" "${detail}"
done < <(list_target_repos "${WS}")

printf '\n'
info "PASS=${pass} FAIL=${fail}"
exit $(( fail > 0 ? 1 : 0 ))
