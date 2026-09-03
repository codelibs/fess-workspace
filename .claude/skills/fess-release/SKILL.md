---
name: fess-release
description: Use when generating Fess GitHub release notes from a milestone.
---

# Fess Release Notes Generator

This skill generates curated release notes for Fess by fetching milestone data from GitHub, categorizing issues by labels, and creating a draft GitHub release.

## Prerequisites

- `gh` CLI authenticated with access to `codelibs/fess`
- A closed or open milestone matching the target version in `codelibs/fess`

## Workflow

### Step 1: Gather Version

Ask the user for the target version number if not already provided (e.g., "15.5.0").

Store it as `VERSION` for use throughout the workflow.

### Step 2: Fetch Previous Release Notes

Retrieve the most recent release to use as a format reference.

```bash
gh release view --repo codelibs/fess --json tagName,body | jq -r '.body'
```

Study the format, tone, and structure of the previous release notes carefully. The new release notes must follow the same style.

### Step 3: Find Milestone

Search for a milestone matching the version.

```bash
gh api repos/codelibs/fess/milestones --jq ".[] | select(.title == \"$VERSION\") | {number, title, open_issues, closed_issues}"
```

If no exact match is found, list all milestones and ask the user to confirm:

```bash
gh api repos/codelibs/fess/milestones?state=all --jq '.[] | "\(.number): \(.title) (open: \(.open_issues), closed: \(.closed_issues))"'
```

Store the milestone number as `MILESTONE_NUMBER`.

### Step 4: Fetch Closed Issues

Retrieve all closed issues and PRs for the milestone. Paginate if necessary.

```bash
gh api "repos/codelibs/fess/issues?milestone=$MILESTONE_NUMBER&state=closed&per_page=100" --jq '.[] | {number, title, labels: [.labels[].name], pull_request: (.pull_request != null)}'
```

If more than 100 issues, fetch additional pages:

```bash
gh api "repos/codelibs/fess/issues?milestone=$MILESTONE_NUMBER&state=closed&per_page=100&page=2" --jq '.[] | {number, title, labels: [.labels[].name], pull_request: (.pull_request != null)}'
```

### Step 5: Categorize Issues

Classify each issue based on its labels:

| Label | Category | Section |
|-------|----------|---------|
| `enhancement` | New Feature | Highlights |
| `improvement` | Improvement | Improvements (grouped by theme) |
| `bug` | Bug Fix | Bug Fixes |
| `task` | Internal Task | Generally omit unless user-facing |

**Thematic grouping for Improvements**: Group related improvements under theme headings such as:
- Search & Query
- Authentication & Security
- Crawling & Indexing
- Administration & Configuration
- Performance & Reliability
- API & Integration
- UI & Display

Only include theme headings that have actual items. Choose the most appropriate theme for each issue.

### Step 6: Synthesize Release Notes

**Do NOT simply list issue titles.** Instead, write curated, user-friendly descriptions:

- Rewrite technical issue titles into clear descriptions of what changed for users
- Combine related issues into single bullet points where appropriate
- Use active voice and focus on user benefit
- Keep descriptions concise but informative

#### Release Note Template

Follow this structure (adapt based on the previous release format from Step 2):

```markdown
We're pleased to announce the release of **Fess VERSION**.
[2-3 sentence summary highlighting the most important changes in this release]

## Highlights
- **Feature Name**
  Brief description of what this feature does and why it matters.

## Improvements
### Theme Name
- Description of improvement
- Description of improvement

### Another Theme
- Description of improvement

## Bug Fixes
- Description of what was fixed

---
We recommend upgrading to **Fess VERSION** to take advantage of [key benefits].

:scroll: [Documentation](https://fess.codelibs.org/)
:package: **Docker Image**: [GitHub Packages - codelibs/fess](https://github.com/codelibs/docker-fess/pkgs/container/fess)
:speech_balloon: **Community Forum**: [discuss.codelibs.org](https://discuss.codelibs.org/)

Thank you for using Fess!
```

**Notes on sections:**
- Omit "Highlights" if there are no `enhancement` labeled issues
- Omit "Bug Fixes" if there are no `bug` labeled issues
- Always include "Improvements" if there are `improvement` labeled issues

### Step 7: Review with User

Present the draft release notes to the user for review before creating the release. Ask if any changes are needed.

### Step 8: Create Draft Release

Once approved, create the draft release:

```bash
gh release create "fess-$VERSION" \
  --repo codelibs/fess \
  --title "Fess $VERSION" \
  --draft \
  --notes "RELEASE_NOTES_CONTENT"
```

**Important:**
- Always use `--draft` flag - never publish directly
- Tag format is `fess-X.X.X` (e.g., `fess-15.5.0`)
- Do NOT attach any assets (binaries are uploaded manually)
- Use a heredoc for multi-line notes to preserve formatting:

```bash
gh release create "fess-$VERSION" \
  --repo codelibs/fess \
  --title "Fess $VERSION" \
  --draft \
  --notes "$(cat <<'EOF'
RELEASE_NOTES_HERE
EOF
)"
```

### Step 9: Confirm

After creating the draft, provide the user with:
- The URL to the draft release on GitHub
- A reminder that assets need to be uploaded manually
- A reminder to review and publish when ready

### Step 10: Post-publication site check

Once the documentation for the new version is published, run `docs/site-noindex/verify.sh` and add
the new version to the list it checks. It asserts the publication matrix — which paths must stay
indexable and which must carry `noindex` — and the version list does not update itself, so a new
release silently goes unchecked until it is added.

`docs/site-noindex/` is a standalone git repository with no remote: it exists only in this
workspace and `docs/` is gitignored, so it is never restored by a clone. Its test suite must run
in the Debian container `run-tests.sh` starts; BSD `sed` on macOS cannot execute it.

## Error Handling

- If `gh` is not authenticated: instruct the user to run `gh auth login`
- If milestone not found: list available milestones and ask user to confirm
- If no closed issues found: warn the user and confirm whether to proceed
- If release tag already exists: warn and ask user how to proceed
