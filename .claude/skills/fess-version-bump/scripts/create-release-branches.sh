#!/usr/bin/env bash
# Create the maintenance release branch (e.g. 15.6.x) on every Fess target repo.
# Safe to run for the entire set in one pass — branch creation has no cross-repo deps.
#
# Usage:
#   scripts/create-release-branches.sh --release-branch 15.6.x [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

RELEASE_BRANCH=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-branch|-r) RELEASE_BRANCH="$2"; shift 2 ;;
    --dry-run)           DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,7p' "$0"; exit 0 ;;
    *) error "unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "${RELEASE_BRANCH}" ]]; then
  error "--release-branch is required (e.g. 15.6.x)"
  exit 2
fi

WS="$(require_workspace)"
info "workspace: ${WS}"
info "release branch: ${RELEASE_BRANCH} (dry-run=${DRY_RUN})"

created=0
skipped=0
failed=0

while IFS=$'\t' read -r repo branch; do
  path="${WS}/repos/${repo}"
  printf '\n=== %s (default: %s)\n' "${repo}" "${branch}"

  if [[ ! -d "${path}/.git" ]]; then
    warn "${repo}: not cloned, skipping"
    skipped=$((skipped+1)); continue
  fi

  cd "${path}"
  git fetch origin --quiet || true

  if git ls-remote --heads origin "${RELEASE_BRANCH}" | grep -q "refs/heads/${RELEASE_BRANCH}"; then
    info "${repo}: ${RELEASE_BRANCH} already on origin, skipping"
    skipped=$((skipped+1)); continue
  fi

  cur="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${cur}" != "${branch}" ]]; then
    if ! git checkout "${branch}" 2>&1; then
      error "${repo}: cannot checkout ${branch}"
      failed=$((failed+1)); continue
    fi
  fi

  local_head="$(git rev-parse HEAD)"
  remote_head="$(git rev-parse "origin/${branch}" 2>/dev/null || echo '')"
  if [[ -n "${remote_head}" && "${local_head}" != "${remote_head}" ]]; then
    warn "${repo}: ${branch} out of sync with origin, attempting --ff-only pull"
    git pull --ff-only origin "${branch}" || {
      error "${repo}: pull failed"
      failed=$((failed+1)); continue
    }
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] would create ${RELEASE_BRANCH} and push"
    continue
  fi

  git checkout -b "${RELEASE_BRANCH}"
  git push -u origin "${RELEASE_BRANCH}"
  git checkout "${branch}"
  ok "${repo}: ${RELEASE_BRANCH} created"
  created=$((created+1))
done < <(list_target_repos "${WS}")

printf '\n'
info "SUMMARY: created=${created} skipped=${skipped} failed=${failed}"
exit $(( failed > 0 ? 1 : 0 ))
