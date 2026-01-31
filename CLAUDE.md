# fess-workspace

## Important: Source Code Location

**ALWAYS use source code in the `repos/` directory when reading, editing, or referencing Fess-related code.** Do not search outside this directory for Fess implementation details.

## Code Reference

Primary repositories for development:

- `repos/fess/` - Main Fess application
- `repos/fess-crawler/` - Web/File crawler
- `repos/fess-suggest/` - Suggest feature
- `repos/fess-parent/` - Maven parent POM

See `sets/*.yaml` for full repository listings.

## Coding Standards

### Java
- Follow existing Fess coding conventions
- Use LastaFlute patterns

### Scripts
- Use `set -euo pipefail`
- Source `scripts/lib/common.sh`
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output

## Quick Reference

For build commands, prerequisites, and detailed workflows, see [README.md](README.md).
