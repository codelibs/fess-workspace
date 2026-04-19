---
name: fess-version-bump
description: Use when starting a new Fess development cycle in fess-workspace — bumping every Fess-related repository from one SNAPSHOT to the next (e.g. 15.6.1-SNAPSHOT to 15.7.0-SNAPSHOT). Triggers include "create 15.X.x release branches", "bump to 15.Y.0-SNAPSHOT", or any request to coordinate a workspace-wide version update across fess-parent and its child repositories.
---

# Fess Version Bump

## When this skill applies

The user works in the fess-workspace root (recognized by `sets/all.yaml` + `repos/` + `scripts/`) and wants to move every Fess-related repository from `<OLD>.X-SNAPSHOT` to `<NEW>-SNAPSHOT` (typically a minor-version bump that starts a new development cycle).

Before starting, collect these parameters:

- `OLD_MAJOR_MINOR` — e.g. `15.6` (the prefix on the current default-branch SNAPSHOT)
- `NEW_VERSION` — e.g. `15.7.0-SNAPSHOT` (the version the default branch moves to)
- `RELEASE_BRANCH` — e.g. `15.6.x` (derived: `${OLD_MAJOR_MINOR}.x`)

## Critical rule: PRs go out in dependency-ordered waves

Fess child repositories resolve `fess-parent` plus its `fess.version` / `crawler.version` / `crawler.playwright.version` / `suggest.version` properties against the Maven **snapshot** repository. A child-repo PR's CI fails with `Could not find artifact ...SNAPSHOT` if the upstream SNAPSHOT is not yet deployed.

Therefore, create PRs in five waves and **stop after each wave until the user confirms the merge and Maven snapshot deployment are complete**. Do not parallelize the waves.

```
Wave 1 : fess-parent                         (bumps project version + fess*.version properties)
Wave 2 : fess-suggest, fess-crawler          (independent of each other; both consumed by downstream)
Wave 3 : fess-crawler-playwright             (depends on fess-crawler)
Wave 4 : fess                                (depends on parent + suggest + crawler + crawler-playwright)
Wave 5 : every remaining plugin              (fess-ds-*, fess-llm-*, fess-theme-*, fess-webapp-*,
                                              fess-script-*, fess-ingest-*, fess-thumbnail-playwright)
```

After opening the PRs for a wave, tell the user which PRs are open, then **wait**. The user merges them and deploys SNAPSHOTs; they will signal when to proceed.

## Step 0: Scope & validation

1. Read `sets/all.yaml` to get the full list of tracked repositories and their default branches. Non-Fess repos (`corelib`, `curl4j`, `fesen-httpclient`, `java-saml`, `jcifs`, `jhighlight`, `nekohtml`, `spnego`) and docs/site-only repos (`docker-fess`, `fessctl`, `fess-kopf`, `fess-test-ui`, `fess-docs`) are out of scope — they follow their own release cadences.
2. Run `./scripts/status.sh --short` and verify every target repo is on its default branch with a clean tree. Dirty trees abort the workflow unless the user explicitly says to proceed; log them and ask.
3. Confirm the current project version of each target matches `${OLD_MAJOR_MINOR}.x-SNAPSHOT`. A small number of orphan repos may sit a patch behind (e.g. on `15.6.0-SNAPSHOT` while the rest are on `15.6.1-SNAPSHOT`) — they merge into `NEW_VERSION` here too, so include them.
4. Check `git ls-remote --heads origin ${RELEASE_BRANCH}` per repo. If it already exists, skip branch creation for that repo (do not attempt to recreate).

## Step 1: Create `${RELEASE_BRANCH}` on every target repo (parallel-safe)

Use `scripts/create-release-branches.sh` — it is safe to run for the entire set in one pass because branch creation has no cross-repo dependencies. The script fetches, verifies sync with origin, creates the branch from the current default-branch HEAD, pushes it, and returns to the default branch.

```bash
scripts/create-release-branches.sh --release-branch 15.6.x
```

## Step 2: Edit pom.xml versions on the default branch (do not commit yet)

Edit the working tree of each repo's default branch so the diff is ready for Step 3's wave-by-wave PR creation.

For `fess-parent/pom.xml`, update:

- The project `<version>` tag
- The `<fess.version>`, `<crawler.version>`, `<crawler.playwright.version>`, `<suggest.version>` properties (all four)

For every child repo `pom.xml`, update:

- The project `<version>` tag (the one at the top of the file, not the one inside `<parent>`)
- The `<version>` inside the `<parent>` block that references `fess-parent`

**Multi-module repos:** `fess-crawler` has `fess-crawler/pom.xml`, `fess-crawler-lasta/pom.xml`, `fess-crawler-opensearch/pom.xml` as submodules with a `fess-crawler-parent` parent reference. Update those submodule `<parent><version>` entries too. When a new multi-module Fess repo appears, discover it with `find repos/<repo> -maxdepth 3 -name pom.xml -not -path '*/target/*'`.

Use `scripts/edit-pom-versions.sh`:

```bash
scripts/edit-pom-versions.sh --old 15.6 --new 15.7.0-SNAPSHOT
```

The script leaves all changes as uncommitted working-tree edits so they can be verified with `git diff` before Step 3 commits anything.

## Step 3: Dependency-ordered PR waves

**Between every wave, report the opened PR URLs to the user and stop. Do not start the next wave until the user confirms merges + Maven snapshot deployment.**

`scripts/create-version-pr.sh` does one wave at a time. It accepts a whitespace-separated list of repo names, creates the `update-version-${NEW_VERSION%-SNAPSHOT}` branch, stages every modified `pom.xml` (including submodules), commits, pushes, and opens a PR via `gh pr create`.

### Wave 1 — fess-parent

```bash
scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT fess-parent
```

Wait for: merge + SNAPSHOT uploaded to the Maven snapshot repo.

### Wave 2 — fess-suggest, fess-crawler

```bash
scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT fess-suggest fess-crawler
```

Wait for: both merged + SNAPSHOTs uploaded.

### Wave 3 — fess-crawler-playwright

```bash
scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT fess-crawler-playwright
```

Wait for: merge + SNAPSHOT uploaded.

### Wave 4 — fess

```bash
scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT fess
```

Wait for: merge + SNAPSHOT uploaded.

### Wave 5 — plugins (all remaining targets)

This is everything else tracked by `sets/all.yaml` that still has a pending edit. The script prints the full set via `--remaining`, or pass the list explicitly.

```bash
scripts/create-version-pr.sh --new 15.7.0-SNAPSHOT --remaining
```

## Step 4: Verify

Run `scripts/verify-versions.sh --old 15.6 --new 15.7.0-SNAPSHOT`. It confirms, for each target:

- `origin/${RELEASE_BRANCH}` exists
- Every `pom.xml` under the repo now has `<version>${NEW_VERSION}</version>`
- No `<version>${OLD_MAJOR_MINOR}.*</version>` remains in any `pom.xml`

A non-zero exit code lists the failing repo and file.

## Guardrails & common mistakes

- **Never open Wave N+1 PRs before Wave N is merged and deployed.** Child-repo CI will fail on missing snapshots and churn reviewer attention.
- **Do not use `fess-workspace/scripts/release-branch.sh` for this workflow.** That existing script bundles branch-creation and PR creation, and processes every repo in one pass — it cannot express the dependency-ordered wave pattern that this skill enforces.
- **The sed/perl replacement for the project `<version>` must require `-SNAPSHOT`** (e.g. `<version>15.6.[0-9]+-SNAPSHOT</version>`). Without that suffix requirement, dependency versions inside `<dependencies>` or plugin configs that happen to equal the old release get rewritten and break the build.
- **The `fess-parent` reference in child repos is normally a released version (no `-SNAPSHOT`), not a snapshot.** The parent-reference replacement must accept both `15.6.0` and `15.6.0-SNAPSHOT` to cover repos that missed the previous point release.
- **Include orphan repos.** A few repos (typically `fess-ds-example`, `fess-ingest-example`, `fess-script-example`, `fess-webapp-example`) lag one patch behind. They still belong in the bump.
- **`fess-ds-elasticsearch` was removed from `sets/all.yaml`.** Trust the set file, not the directory listing.
