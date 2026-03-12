# fess-workspace

## Important: Source Code Location

**ALWAYS use source code in the `repos/` directory when reading, editing, or referencing Fess-related code.** Do not search outside this directory for Fess implementation details.

## Prerequisites

- Java 21+, Maven 3.8+, Git
- yq (`brew install yq` on macOS)
- Docker (optional, for integration tests)

## Workspace Commands

```bash
# Setup
./scripts/clone.sh all              # Clone all repositories
./scripts/build.sh all              # Build all (dependency order, skip tests)
./scripts/build.sh all --with-tests # Build all with tests
./scripts/build.sh all --clean      # Clean build

# Daily workflow
./scripts/sync.sh all               # Fetch and pull all repos
./scripts/status.sh                 # Show all repository status
./scripts/status.sh --short         # Compact output
./scripts/clean.sh --target         # Clean Maven target/ directories only
```

Build order: fess-parent -> fess-crawler -> fess-suggest -> fess -> plugins

## Code Reference

Primary repositories:

- `repos/fess/` - Main Fess application (LastaFlute + OpenSearch)
- `repos/fess-crawler/` - Web/File crawler
- `repos/fess-suggest/` - Suggest feature
- `repos/fess-parent/` - Maven parent POM
- `repos/fess-ds-*/` - Data store connectors (Slack, SharePoint, DB, etc.)
- `repos/fess-llm-*/` - LLM plugins (OpenAI, Ollama, Gemini)
- `repos/fess-webapp-*/` - Web application plugins

See `sets/*.yaml` for full repository listings (`all.yaml`, `core.yaml`, `plugins.yaml`).

## Coding Standards

### Java
- Follow existing Fess coding conventions
- Use LastaFlute patterns (Actions, Forms, Services, Helpers)
- Use `@Resource` for DI, `ComponentUtil.getXyzHelper()` for helpers
- Run `mvn formatter:format && mvn license:format` before committing

### Scripts
- Use `set -euo pipefail`
- Source `scripts/lib/common.sh`
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output
