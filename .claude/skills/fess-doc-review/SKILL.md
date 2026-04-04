---
name: fess-doc-review
description: Review Fess documentation files (RST) against source code in repos/ to verify technical accuracy. Use when reviewing documentation for correctness, verifying config property names and defaults match source code, checking API endpoints and SSE events match implementation, or auditing docs before release. Triggers on requests like "review docs", "verify documentation", "check if docs match source", "doc review", or when pointing to specific RST files in fess-docs.
---

# Fess Documentation Review

Review RST documentation in `repos/fess-docs/` against source code in `repos/fess/` and plugin repositories to verify technical accuracy.

## Input

The user specifies target documentation files:
- A directory: `repos/fess-docs/ja/15.6/config/`
- Specific files: `repos/fess-docs/en/15.6/config/rag-chat.rst`
- A PR diff: `gh pr diff 123`

## Workflow

### 1. Identify Source of Truth

Read `refs/source-mapping.md` to map each doc file to its primary source code reference. This table covers all major topics: config properties, SSO, API, LLM/RAG, crawling, datastore connectors, search, LDAP, scripting, deployment, and more.

### 2. Load Relevant Checklists

Based on the doc topic, read the applicable checklist reference files. Always grep/read actual source — never assume correctness.

**Always load:**
- `refs/checklist-config.md` — Property names (A), crawler config parameters (A2), defaults (B), permissions (E), ports (G), technical descriptions (H), feature existence (H4), placeholders (H3), validation (I), index names (I2), admin UI (I3), deployment paths (I4)

**Load when relevant:**

| Doc Topic | Additional Ref | Sections |
|-----------|---------------|----------|
| API, RAG chat, streaming | `refs/checklist-api.md` | C: endpoints/HTTP methods, D: SSE events |
| Datastore connectors (`ds-*.rst`) | `refs/checklist-datastore.md` | H2: data format claims, J: missing/duplicate entries, J2: handler/parameter completeness, J3: script field prefixes |
| Scripting, scheduled jobs | `refs/checklist-scripting.md` | K2: script execution context, K3: job names/scripts, K4: Groovy syntax |
| Non-ja translations | `refs/checklist-cross-lang.md` | K: fabricated properties/capabilities, punctuation, directive/section consistency |
| Setup, install, JVM config, logs, Docker | `refs/checklist-infra.md` | F: JVM options, F1: Docker env var mapping, I4: deployment paths, I5: log file names, L: RST syntax, M: version consistency |

### 3. Execute Review

For each doc file:
1. Map to source files using the source-mapping table
2. Apply all loaded checklist items systematically
3. Record findings in the output format below

## Output Format

```markdown
## Documentation Review: {file_or_directory}

### Source References
- Primary: {source_file}:{lines}

### Findings

#### INCORRECT — {description}
- **File**: {doc_file}:{line}
- **Documented**: `{wrong_value}`
- **Source**: `{correct_value}` ({source_file}:{line})
- **Fix**: {description}

#### MISSING — {description}
- **File**: {doc_file}
- **Property**: `{property_name}` = `{default_value}`
- **Source**: {source_file}:{line}

#### DUPLICATE — {description}
- **File**: {doc_file}:{line1}, {line2}
- **Fix**: Remove duplicate at line {line2}

### Summary
| Category | Count |
|----------|-------|
| Verified | {n} |
| Incorrect | {n} |
| Missing | {n} |
| Duplicate | {n} |
| Cross-language | {checked/not_checked} |
```

## Parallelization

For large directories (>10 files), spawn parallel review agents grouped by topic. All workers read `refs/source-mapping.md` and `refs/checklist-config.md`. Additional refs per group:

| Worker Group | File Patterns | Additional Refs |
|---|---|---|
| Search settings | search-*.rst | (config only) |
| Crawler configuration | crawler-*.rst | (config only) |
| SSO/Security | sso-*.rst, security-*.rst, ldap-*.rst | (config only) |
| LLM/RAG | llm-*.rst, rag-*.rst | checklist-api.md, checklist-infra.md (F1: Docker env vars) |
| Admin operations | admin-*.rst | (config only) |
| Datastore connectors | ds-*.rst | checklist-datastore.md, checklist-scripting.md |
| Setup/Infrastructure | setup-*.rst, install-*.rst | checklist-infra.md |
| Cross-language | non-ja/ versions | checklist-cross-lang.md |

Each worker reads assigned doc files, cross-references against source, and reports findings. The coordinator merges results and applies fixes.
