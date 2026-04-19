#!/usr/bin/env bash
# Create update-version-<new> branch, commit edited pom.xml files, push, and open
# a PR via gh for ONE WAVE of repositories.
#
# Usage:
#   scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT <repo> [<repo> ...]
#   scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT --remaining
#
# --remaining expands to every target repo whose pom.xml has pending working-tree
# changes AND has no PR yet for the update-version-<new> branch.
#
# The commit message and PR body are consistent across waves so future runs can
# reuse them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

NEW_VER=""
USE_REMAINING=false
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --new)       NEW_VER="$2"; shift 2 ;;
    --remaining) USE_REMAINING=true; shift ;;
    -h|--help)   sed -n '2,15p' "$0"; exit 0 ;;
    --) shift; REPOS+=("$@"); break ;;
    -*) error "unknown arg: $1"; exit 2 ;;
    *)  REPOS+=("$1"); shift ;;
  esac
done

if [[ -z "${NEW_VER}" ]]; then
  error "--new (e.g. 15.7.0-SNAPSHOT) is required"
  exit 2
fi

WS="$(require_workspace)"
UPDATE_BRANCH="update-version-${NEW_VER%-SNAPSHOT}"
COMMIT_MSG="Update version to ${NEW_VER}"
PR_TITLE="Update version to ${NEW_VER}"
PR_BODY="## Summary

Bump version for the ${NEW_VER%-SNAPSHOT} development cycle.

Depends on upstream Fess artifacts (\`fess-parent\`, and where applicable \`fess-suggest\`, \`fess-crawler\`, \`fess-crawler-playwright\`, \`fess\`) at \`${NEW_VER}\`, which must already be deployed to the Maven snapshot repository before CI runs here.

## Test plan

- [ ] CI build passes against \`${NEW_VER}\` upstreams"

# Expand --remaining into target list
if [[ "${USE_REMAINING}" == "true" ]]; then
  while IFS=$'\t' read -r repo branch; do
    path="${WS}/repos/${repo}"
    [[ -d "${path}/.git" ]] || continue
    cd "${path}"
    # has pending pom edits?
    if ! git diff --quiet -- '*pom.xml' 2>/dev/null; then
      # already open PR for update branch?
      if ! git ls-remote --heads origin "${UPDATE_BRANCH}" | grep -q "refs/heads/${UPDATE_BRANCH}"; then
        REPOS+=("${repo}")
      fi
    fi
  done < <(list_target_repos "${WS}")
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  warn "no repositories specified"
  exit 0
fi

info "update branch: ${UPDATE_BRANCH}"
info "wave: ${REPOS[*]}"

# Map repo -> default branch once
declare -A DEFAULT_BRANCH
while IFS=$'\t' read -r r b; do DEFAULT_BRANCH["${r}"]="${b}"; done < <(list_target_repos "${WS}")

ok=0; skipped=0; failed=0
results=()

for repo in "${REPOS[@]}"; do
  path="${WS}/repos/${repo}"
  base="${DEFAULT_BRANCH[${repo}]:-}"
  printf '\n=== %s (base=%s)\n' "${repo}" "${base}"

  if [[ -z "${base}" ]]; then
    error "${repo}: not in target set"
    failed=$((failed+1)); continue
  fi
  if [[ ! -d "${path}/.git" ]]; then
    warn "${repo}: not cloned"; skipped=$((skipped+1)); continue
  fi

  cd "${path}"
  cur="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${cur}" != "${base}" ]]; then
    if ! git checkout "${base}" 2>&1; then
      error "${repo}: cannot checkout ${base}"
      failed=$((failed+1)); continue
    fi
  fi

  if git diff --quiet -- '*pom.xml' 2>/dev/null; then
    warn "${repo}: no pom.xml changes to commit"
    skipped=$((skipped+1)); continue
  fi

  # Drop any stale local update branch
  if git show-ref --verify --quiet "refs/heads/${UPDATE_BRANCH}"; then
    git branch -D "${UPDATE_BRANCH}" >/dev/null 2>&1 || true
  fi

  if ! git checkout -b "${UPDATE_BRANCH}"; then
    error "${repo}: cannot create ${UPDATE_BRANCH}"
    failed=$((failed+1)); continue
  fi

  git add -u '*pom.xml'
  if git diff --cached --quiet; then
    warn "${repo}: nothing staged after git add"
    git checkout "${base}" >/dev/null 2>&1 || true
    git branch -D "${UPDATE_BRANCH}" >/dev/null 2>&1 || true
    skipped=$((skipped+1)); continue
  fi

  git commit -m "${COMMIT_MSG}"
  git push -u origin "${UPDATE_BRANCH}"

  pr_url="$(gh pr create --title "${PR_TITLE}" --body "${PR_BODY}" --base "${base}" --head "${UPDATE_BRANCH}" 2>&1)" || {
    if echo "${pr_url}" | grep -q "already exists"; then
      pr_url="$(gh pr view --head "${UPDATE_BRANCH}" --json url --jq .url 2>/dev/null || echo 'existing PR')"
      warn "${repo}: PR already existed (${pr_url})"
    else
      error "${repo}: gh pr create failed: ${pr_url}"
      git checkout "${base}" >/dev/null 2>&1 || true
      failed=$((failed+1)); continue
    fi
  }

  git checkout "${base}" >/dev/null 2>&1 || true
  ok "${repo}: ${pr_url}"
  results+=("${repo}: ${pr_url}")
  ok=$((ok+1))
done

printf '\n'
info "SUMMARY: ok=${ok} skipped=${skipped} failed=${failed}"
for line in "${results[@]}"; do printf '  %s\n' "${line}"; done
printf '\n'
info "WAIT: ask the user to merge and deploy the Maven snapshots for this wave before starting the next wave."
exit $(( failed > 0 ? 1 : 0 ))
