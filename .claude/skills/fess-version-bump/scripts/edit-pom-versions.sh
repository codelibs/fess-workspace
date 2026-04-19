#!/usr/bin/env bash
# Edit pom.xml versions across every Fess target repo (working tree only, no commit).
#
# - Updates the project <version> tag from <OLD>.N-SNAPSHOT to <NEW>
# - Updates <parent><artifactId>fess-parent</artifactId><version>...</version>
#   from <OLD>.N (released) or <OLD>.N-SNAPSHOT to <NEW>
# - For fess-parent itself, also updates <fess.version>, <crawler.version>,
#   <crawler.playwright.version>, <suggest.version> properties
# - For multi-module repos (fess-crawler), also updates <parent> references to
#   <artifactId>fess-crawler-parent</artifactId> in submodule pom.xml files
#
# The script requires -SNAPSHOT in the project <version> match so that
# 15.6.x numbers appearing inside <dependencies> are not rewritten.
#
# Usage:
#   scripts/edit-pom-versions.sh --old 15.6 --new 15.7.0-SNAPSHOT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

OLD_MM=""   # e.g. 15.6
NEW_VER=""  # e.g. 15.7.0-SNAPSHOT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --old) OLD_MM="$2"; shift 2 ;;
    --new) NEW_VER="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) error "unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "${OLD_MM}" || -z "${NEW_VER}" ]]; then
  error "--old (e.g. 15.6) and --new (e.g. 15.7.0-SNAPSHOT) are required"
  exit 2
fi
if [[ ! "${NEW_VER}" =~ -SNAPSHOT$ ]]; then
  warn "--new '${NEW_VER}' does not end in -SNAPSHOT; continuing anyway"
fi

WS="$(require_workspace)"

edit_one_pom() {
  local pom="$1"
  # 1) project <version> (SNAPSHOT only, so plain-version dependencies are untouched)
  perl -i -pe 's|<version>\Q'"${OLD_MM}"'\E\.[0-9]+-SNAPSHOT</version>|<version>'"${NEW_VER}"'</version>|' "${pom}"
  # 2) parent reference (fess-parent — released or snapshot)
  perl -i -0pe 's|(<artifactId>fess-parent</artifactId>\s*<version>)\Q'"${OLD_MM}"'\E\.[0-9]+(-SNAPSHOT)?(</version>)|${1}'"${NEW_VER}"'${3}|s' "${pom}"
  # 3) parent reference for multi-module sub-parent (fess-crawler-parent etc.)
  perl -i -0pe 's|(<artifactId>fess-[a-z-]+-parent</artifactId>\s*<version>)\Q'"${OLD_MM}"'\E\.[0-9]+(-SNAPSHOT)?(</version>)|${1}'"${NEW_VER}"'${3}|s' "${pom}"
}

edit_fess_parent_properties() {
  local pom="$1"
  # fess.version / crawler.version / crawler.playwright.version / suggest.version
  for prop in fess crawler crawler.playwright suggest; do
    perl -i -pe 's|(<'"${prop}"'\.version>)\Q'"${OLD_MM}"'\E\.[0-9]+(-SNAPSHOT)?(</'"${prop}"'\.version>)|${1}'"${NEW_VER}"'${3}|' "${pom}"
  done
}

touched_files=0
touched_repos=0

while IFS=$'\t' read -r repo branch; do
  path="${WS}/repos/${repo}"
  [[ -d "${path}/.git" ]] || { warn "${repo}: not cloned, skipping"; continue; }

  # Must be on default branch
  cd "${path}"
  cur="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${cur}" != "${branch}" ]]; then
    warn "${repo}: on '${cur}', expected '${branch}' — skipping (switch branch first)"
    continue
  fi

  # Find all pom.xml in the repo (multi-module safe)
  mapfile -t poms < <(find . -maxdepth 4 -name pom.xml -not -path '*/target/*' -not -path '*/node_modules/*' | sort)
  [[ ${#poms[@]} -gt 0 ]] || continue

  repo_changed=false
  for pom in "${poms[@]}"; do
    before="$(sha1sum "${pom}" | awk '{print $1}')"
    edit_one_pom "${pom}"
    if [[ "${repo}" == "fess-parent" && "${pom}" == "./pom.xml" ]]; then
      edit_fess_parent_properties "${pom}"
    fi
    after="$(sha1sum "${pom}" | awk '{print $1}')"
    if [[ "${before}" != "${after}" ]]; then
      touched_files=$((touched_files+1))
      repo_changed=true
      ok "${repo}: ${pom#./} edited"
    fi
  done
  [[ "${repo_changed}" == "true" ]] && touched_repos=$((touched_repos+1))
done < <(list_target_repos "${WS}")

printf '\n'
info "SUMMARY: repos_touched=${touched_repos} files_touched=${touched_files}"
info "Run 'git -C repos/<repo> diff pom.xml' to review changes. Nothing has been committed."
