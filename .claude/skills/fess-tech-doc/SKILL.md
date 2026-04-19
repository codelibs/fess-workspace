---
name: fess-tech-doc
description: Use when creating, updating, or planning Fess technical articles — RST files under repos/fess-docs/ja/articles/ for the fess-docs site. Triggers include requests to write or draft a Fess article, design article structure, verify article technical accuracy against source code, or update the article index.
---

# Fess Technical Article Writing

## Workflow

### 1. Feature Research

Understand the Fess features to cover by reading source code — never write about features without verifying them.

**Where to look:**

- Admin actions: `repos/fess/src/main/java/org/codelibs/fess/app/web/admin/` — each subdirectory = one admin menu item
- Config properties: `repos/fess/src/main/resources/fess_config.properties` — runtime config keys and defaults
- API endpoints: `repos/fess/src/main/java/org/codelibs/fess/app/web/api/` — REST API implementations
- Crawler: `repos/fess-crawler/` — crawling behavior, supported protocols
- Data store plugins: `repos/fess-ds-*/` — each repo = one data source connector
- LLM plugins: `repos/fess-llm-*/` — RAG/AI integration (OpenAI, Gemini, Ollama)
- Webapp plugins: `repos/fess-webapp-*/` — web extensions (MCP server, etc.)
- Existing docs: `repos/fess-docs/ja/{version}/admin/`, `repos/fess-docs/ja/{version}/config/`

**Verification checklist:**

- Config property names exist in `fess_config.properties`
- Admin menu names match actual JSP/action class names
- API endpoint paths match `@Execute` annotations in source
- Plugin artifact IDs match actual repository names

### 2. Article Design

Before writing, decide:

- **Reader level**: 初心者 / 中級者 / 上級者 — determines depth and prerequisite assumptions
- **Scenario**: A concrete situation (organization type, data sources, pain point) that motivates the content
- **Feature scope**: Which Fess features are covered and how they connect
- **Length**: 150-350 lines RST. Shorter for focused topics, longer for cross-cutting scenarios

### 3. RST Writing

See `references/rst-conventions.md` for full syntax reference.

**Article template:**

```rst
============================================================
タイトル
============================================================

はじめに
========
(Why this topic matters. What the reader will achieve.)

対象読者
========
- Bullet points describing who should read this

必要な環境
==========
(Optional. Software versions, prerequisites.)

(Main content — scenario-driven sections)

まとめ
======
(4-5 bullet point takeaways)

参考資料
========
- `Link text <URL>`__
```

**Key RST patterns:**

- Tables: `.. list-table::` with `:header-rows: 1` and `:widths:`
- Code: `.. code-block:: java` (or yaml, bash, json, sql, javascript, xml, html, css)
- Shell commands: `::` literal block (indented 4 spaces, prefix with `$`)
- Images: `|imageN|` substitution, defined at file bottom
- Internal links: `:doc:`articles/filename`` 
- External links: `` `text <URL>`__ ``

### 4. Technical Accuracy Review

After writing, verify:

- Every config property name exists in source code
- Every admin menu path (e.g., ［クローラ］ > ［ウェブ］) matches actual UI
- Every API endpoint path is correct
- Plugin names match real artifact IDs (e.g., `fess-ds-slack`, not `fess-slack`)
- Fess version number in doc URLs matches latest stable in `repos/fess-docs/`

### 5. File Placement and Indexing

- Article: `repos/fess-docs/ja/articles/{name}.rst`
- Images: `repos/fess-docs/resources/images/ja/article/{name}/`
- Add `:doc:` reference to `repos/fess-docs/ja/articles.rst`

## Fess Technical Landscape

Key areas to draw from when writing articles:

| Area | Components |
|------|-----------|
| Crawling | Web crawl, file system (SMB/CIFS), data stores (15+ connectors) |
| Search | Full-text, fuzzy, semantic, vector/KNN, rank fusion, suggest |
| Access control | Roles, groups, labels, virtual hosts, LDAP, OIDC, SAML, tokens |
| Search quality | Synonyms, key-match, boost, related queries, stop words, Kuromoji dict |
| AI/LLM | RAG chat (OpenAI/Gemini/Ollama), MCP server, multimodal (CLIP) |
| Operations | Scheduler, backup, health API, logs, notifications, multi-instance |
| Integration | Search API (JSON), admin API, FSS (JS embed), themes, plugins |
| Infrastructure | Docker Compose, OpenSearch cluster, JVM tuning |

## Writing Style

- **Language**: Japanese, です・ます調
- **Tone**: Practical and concrete. Lead with the reader's problem, not the feature's existence
- **Bold**: For emphasis on key concepts and feature names at first mention
- **Inline code**: For config properties, CLI commands, API endpoints, file paths
- Explain "why" before "how" — motivation before procedure
- Include operational tips (scheduling, security, monitoring) where relevant
- Use comparison tables (`.. list-table::`) when presenting alternatives
