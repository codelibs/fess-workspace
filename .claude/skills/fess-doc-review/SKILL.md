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

Map each doc file to its primary source reference:

| Doc Topic | Primary Source |
|-----------|---------------|
| Core config properties | `repos/fess/src/main/resources/fess_config.properties` |
| Config constants/defaults | `repos/fess/src/main/java/org/codelibs/fess/mylasta/direction/FessConfig.java` |
| Application constants | `repos/fess/src/main/java/org/codelibs/fess/Constants.java` |
| SSO (SAML) | `repos/fess/src/main/java/org/codelibs/fess/sso/saml/SamlAuthenticator.java` |
| SSO (OIDC) | `repos/fess/src/main/java/org/codelibs/fess/sso/oic/OicAuthenticator.java` |
| SSO (Entra ID) | `repos/fess/src/main/java/org/codelibs/fess/sso/entraid/EntraIdAuthenticator.java` |
| SSO (SPNEGO) | `repos/fess/src/main/java/org/codelibs/fess/sso/spnego/SpnegoAuthenticator.java` |
| API endpoints | `repos/fess/src/main/java/org/codelibs/fess/api/` |
| LLM/RAG chat | `repos/fess/src/main/java/org/codelibs/fess/llm/AbstractLlmClient.java` |
| LLM providers | `repos/fess-llm-ollama/`, `repos/fess-llm-openai/`, `repos/fess-llm-gemini/` |
| Crawling | `repos/fess/src/main/java/org/codelibs/fess/crawler/`, `repos/fess-crawler/` |
| Datastore connectors | `repos/fess-ds-*/` |
| Search/Query | `repos/fess/src/main/java/org/codelibs/fess/helper/SearchHelper.java`, `QueryHelper.java` |
| Index mappings | `repos/fess/src/main/resources/fess_indices/` |
| LDAP | `repos/fess/src/main/java/org/codelibs/fess/ldap/` |
| DI config | `repos/fess/src/main/resources/app.xml`, `fess.xml`, `fess_*.xml` |

### 2. Review Checklist

For each doc file, verify the following. Always grep/read actual source — never assume correctness.

#### A. Configuration Property Names
- Every property key in the doc must exist in `fess_config.properties` or relevant Java source.
- Check for typos, outdated names, or incorrect prefixes.
- Watch for property key transformation patterns:
  - SAML: `saml.` prefix is stripped and `onelogin.saml2.` is prepended. So `saml.strict` maps to `onelogin.saml2.strict`, but `saml.security.strict` would incorrectly map to `onelogin.saml2.security.strict`.
  - Config override: Properties can be overridden via system properties with `Constants.FESS_CONFIG_PREFIX`.

#### B. Default Values
- Compare every documented default against:
  1. `fess_config.properties` (explicit defaults)
  2. `FessConfig.java` (`DEFAULT_*` constants, getter fallback values)
  3. Java code (`getSystemProperty("key", "default")` patterns)
  4. Plugin-specific properties files (for `fess-llm-*`, `fess-ds-*` etc.)

#### C. API Endpoints and HTTP Methods
- Verify paths (e.g., `/api/v1/chat`) against path constants or `@Execute` annotations.
- Check supported HTTP methods.
- Verify request/response parameter names and types.

#### D. SSE Event Types
- For streaming APIs, verify event names against `sendSseEvent(writer, "eventName", ...)` calls.
- Check event payload fields match documentation.
- Confirm no documented events are missing from source, and no source events are missing from docs.

#### E. Permission Format
- Fess uses `{role}`, `{user}`, `{group}` prefix format (e.g., `{role}guest`).
- Verify documented examples use this format, not bare names like `role_xxx`.
- Cross-reference: `role.search.user.prefix`, `role.search.group.prefix`, `role.search.role.prefix` in `fess_config.properties`.

#### F. JVM Options and Memory Settings
- Compare documented JVM flags against `jvm.crawler.options`, `jvm.suggest.options`, `jvm.thumbnail.options` in `fess_config.properties`.
- Verify heap sizes (`-Xms`, `-Xmx`), metaspace, GC settings.
- Check environment variable names against shell/batch scripts.

#### G. Port Numbers and URLs
- Fess default: `8080`
- OpenSearch HTTP: `9201` (Fess custom, not standard 9200)
- OpenSearch Transport: `9301`
- `search_engine.http.url` default: `http://localhost:9201`

#### H. Technical Descriptions
- Verify algorithm descriptions (e.g., RRF formula) match implementation.
- Check behavior descriptions (e.g., "returns 429 when CPU >= threshold") against actual logic.
- Verify enum/mode values (e.g., `smart_summary`, `full`, `truncated`) match switch statements or constants.

#### I. Index and Field Names
- Verify OpenSearch index names (e.g., `fess.search`, `fess_config`, `fess_log`).
- Check field names match index mapping definitions in `fess_indices/`.

#### J. Duplicate or Missing Entries
- Check for duplicate rows in RST `list-table` directives.
- Check for properties defined in source but missing from doc tables.

#### K. Cross-language Consistency
- Property names and default values must be identical across all languages (`de/`, `en/`, `es/`, `fr/`, `ja/`, `ko/`, `zh-cn/`).
- Only descriptions/explanations should differ between languages.
- When a fix is found, check if the same issue exists in other language versions.

#### L. RST Syntax
- `list-table` column counts and alignment.
- Code block syntax (`::`  or `.. code-block::`).
- Cross-references (`:doc:`, `:ref:`) point to existing targets.
- `|Fess|` substitution used consistently.

#### M. Version Consistency
- Version numbers in examples, JAR filenames, and URLs match the doc version (e.g., `15.6`).
- Plugin JAR naming convention: `fess-{type}-{name}-{version}.jar`.

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

For large directories (>10 files), spawn parallel review agents grouped by topic:
- Search settings (search-*.rst)
- Crawler configuration (crawler-*.rst)
- SSO/Security (sso-*.rst, security-*.rst, ldap-*.rst)
- LLM/RAG (llm-*.rst, rag-*.rst)
- Admin operations (admin-*.rst)
- Datastore connectors (datastore/*.rst)
- Setup/Infrastructure (setup-*.rst)

Each worker reads assigned doc files, cross-references against source, and reports findings. The coordinator merges results and applies fixes.
