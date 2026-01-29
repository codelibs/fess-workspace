# fess-workspace

Multi-repository development environment for Fess enterprise search server.

## Structure

```
sets/          # Repository set definitions (YAML)
scripts/       # Management scripts
repos/         # Clone destination (gitignored)
```

## Code Reference

When reading or editing Fess-related code, always refer to repositories in the `repos/` directory:

- `repos/fess/` - Main Fess application
- `repos/fess-crawler/` - Crawler
- `repos/fess-suggest/` - Suggest feature
- `repos/fess-parent/` - Maven parent POM

## Build

```bash
./scripts/clone.sh core           # Clone repositories
./scripts/build.sh core           # Build (skip tests)
./scripts/build.sh core --with-tests  # Build with tests
./scripts/status.sh               # Check status
./scripts/sync.sh core            # Sync to latest
```

### Build Order (Core)

1. fess-parent (Maven parent POM)
2. fess-crawler (Crawler)
3. fess-suggest (Suggest)
4. fess (Main app)

## Tech Stack

- Java 21 / Maven
- OpenSearch (search backend)
- LastaFlute (web framework)

## Coding Standards

### Java
- Follow existing Fess coding conventions
- Use LastaFlute patterns

### Scripts
- Use `set -euo pipefail`
- Source `scripts/lib/common.sh`
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output
