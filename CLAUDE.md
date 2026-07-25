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
./scripts/build.sh all --offline    # Offline build (mvn -o)
./scripts/build.sh all --verbose    # Stream Maven output (default: logs/build/*.log)

# Daily workflow
./scripts/sync.sh all               # Fetch and pull all repos
./scripts/sync.sh all --fetch-only  # Fetch without pulling
./scripts/sync.sh all --force       # Pull over local changes (stash and apply)
./scripts/status.sh                 # Show all repository status
./scripts/status.sh --short         # Compact output
./scripts/clean.sh                 # Clean all repos (mvn clean, npm clean, etc.)
./scripts/clean.sh --target        # Quick clean: remove build output dirs directly
./scripts/test-integration.sh      # Run integration tests (requires Docker)
./scripts/release-branch.sh        # Create/manage release branches across repos
```

Build order (`build_order` in `sets/*.yaml`): libs (corelib, curl4j, java-saml, jcifs,
jhighlight, nekohtml, spnego, fess-parent) -> fesen-httpclient -> fess-crawler ->
fess-crawler-playwright -> fess-suggest -> fess -> plugins/themes -> fess-kopf ->
docker-fess -> fessctl -> fess-test-ui, fess-docs

## Cross-repo Build Tips

- `repos/fess` uses `<packaging>war</packaging>`. To install as jar for plugin compilation:
  1. Change `repos/fess/pom.xml` packaging to `jar`
  2. `cd repos/fess && mvn clean install -DskipTests`
  3. Revert packaging back to `war`
- Run `mvn formatter:format && mvn license:format` in each repo separately
- Custom repo sets: copy `sets/custom.yaml.example` to `sets/my-set.yaml`, then pass `my-set` to any script (e.g. `./scripts/build.sh my-set`)

## Gotchas

- **Default branch is `master`**, not `main` (`defaults.branch` in `sets/*.yaml`). `main` is a
  per-repo override - incl. fess-parent, fess-themes, java-saml, jcifs, fesen-httpclient,
  fess-crawler-playwright. `repos/fess` has no `main` branch at all.
- `FESS_WORKSPACE_GIT_SSH=true` switches clone/sync remotes from HTTPS to SSH.
- `build.sh` writes `logs/build/<repo>.log`; without `--verbose` Maven output goes only there.
  Check that file first when a build fails.
- `repos/`, `docs/`, `work/`, `logs/`, `target/` are gitignored - local scratch, not workspace
  source. Do not `git add` them.
- `repos/` may hold checkouts no longer listed in `sets/*.yaml` (e.g. some `fess-theme-*`); the
  scripts skip them silently, so they never sync or build.

## Code Reference

Repo naming: `fess` (app), `fess-crawler*` (crawlers), `fess-suggest`, `fess-parent` (dependency
BOM), `fess-ds-*` (data stores), `fess-llm-*`, `fess-webapp-*` (plugins), `fess-theme*` /
`fess-themes` (themes); the rest are CodeLibs libraries.

See `sets/*.yaml` for full repository listings (`all.yaml`, `core.yaml`, `plugins.yaml`).

Non-repo directories:

- `docs/` - Workspace-level notes and reports
- `work/` - Scratch/working directory

## Coding Standards

### Java
- Follow existing Fess coding conventions
- Use LastaFlute patterns (Actions, Forms, Services, Helpers)
- Use `@Resource` for DI, `ComponentUtil.getXyzHelper()` for helpers
- Run `mvn formatter:format && mvn license:format` before committing

### Scripts
- Use `set -euo pipefail`
- Source `scripts/lib/common.sh` (logging, helpers) and `scripts/lib/yaml_parser.sh` (set file parsing)
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output
