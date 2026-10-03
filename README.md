# fess-workspace

A multi-repository development environment for [Fess](https://fess.codelibs.org/), the open-source
enterprise search server, and its surrounding CodeLibs ecosystem. Repositories are described in YAML
"set" files and managed with a handful of Bash scripts.

## Overview

- **Set-based management** — YAML files under `sets/` declare which repositories to clone and build
- **Dependency-aware builds** — `build_order` drives the Maven build sequence across repositories
- **Independent checkouts** — every repository is a full git clone under `repos/` (not submodules)
- **Whole-ecosystem coverage** — core, libraries, data store connectors, LLM/webapp plugins, themes, Docker, CLI
- **AI-assisted development** — `CLAUDE.md` plus project agents and skills under `.claude/`

## Prerequisites

- **Git**
- **Java 21+** — required to build Fess components
- **Maven 3.8+**
- **yq** — YAML processor used by the scripts (`brew install yq` on macOS)
- **Docker** (optional) — for integration tests and containerized development
- **GitHub CLI (`gh`)** (optional) — required only by `scripts/release-branch.sh`

## Quick Start

```bash
git clone https://github.com/codelibs/fess-workspace.git
cd fess-workspace

./scripts/clone.sh all       # Clone (or update) every repository in the "all" set
./scripts/build.sh all       # Build in dependency order, skipping tests
./scripts/status.sh          # Show git status for every checkout
```

Cloning defaults to HTTPS. Export `FESS_WORKSPACE_GIT_SSH=true` to use SSH remotes instead
(`remote_base_ssh` in the set file).

## Layout

```
fess-workspace/
├── sets/                     # Repository set definitions
│   ├── all.yaml             # Complete ecosystem (56 repositories)
│   ├── core.yaml            # Core components only
│   ├── plugins.yaml         # core.yaml + data store / theme plugins
│   └── custom.yaml.example  # Template for custom sets
├── scripts/
│   ├── clone.sh             # Clone or update repositories from a set
│   ├── build.sh             # Build a set in dependency order
│   ├── sync.sh              # Fetch and pull updates
│   ├── status.sh            # Show git status of every checkout
│   ├── clean.sh             # Clean build artifacts
│   ├── release-branch.sh    # Create release branches and version-bump PRs
│   ├── test-integration.sh  # Integration test entry point
│   └── lib/
│       ├── common.sh        # Logging, paths, prerequisite checks
│       └── yaml_parser.sh   # Set-file parsing (yq), include resolution
├── repos/                   # Cloned repositories (gitignored)
├── logs/build/              # Per-repository Maven build logs (gitignored)
├── work/                    # Scratch/working directory (gitignored)
├── docs/                    # Workspace-level notes and reports (gitignored)
├── CLAUDE.md                # Instructions for AI-assisted development
└── AGENTS.md                # Symlink to CLAUDE.md
```

## Sets

### `all.yaml` — complete ecosystem

#### CodeLibs Libraries (`build_order` 1–2)

| Repository | Branch | Description |
|------------|--------|-------------|
| **corelib** | main | Core utility library |
| **curl4j** | main | cURL-like Java HTTP client |
| **java-saml** | main | Java SAML toolkit (SSO) |
| **jcifs** | main | CIFS/SMB client library in pure Java |
| **jhighlight** | main | Source code syntax highlighter |
| **nekohtml** | main | HTML parser and tag balancer |
| **spnego** | main | Integrated Windows Authentication (SSO) |
| **fess-parent** | main | Maven parent POM / dependency management |
| **fesen-httpclient** | main | HTTP client for OpenSearch |

#### Core Components (`build_order` 3–6)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-crawler** | main | Crawler framework |
| **fess-crawler-playwright** | main | Playwright-based browser crawler component |
| **fess-suggest** | main | Suggestion / auto-completion library |
| **fess** | main | The Fess search server web application |

#### Data Store Connectors (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-ds-atlassian** | main | Confluence / Jira |
| **fess-ds-box** | main | Box |
| **fess-ds-csv** | main | CSV files |
| **fess-ds-db** | main | Relational databases via JDBC |
| **fess-ds-dropbox** | main | Dropbox |
| **fess-ds-git** | main | Git repositories |
| **fess-ds-gsuite** | main | Google Workspace |
| **fess-ds-json** | main | JSON files |
| **fess-ds-microsoft365** | main | Microsoft 365 (OneDrive, Teams, SharePoint, …) |
| **fess-ds-salesforce** | main | Salesforce |
| **fess-ds-sharepoint** | main | On-premise SharePoint |
| **fess-ds-slack** | main | Slack |
| **fess-ds-wikipedia** | main | Wikipedia dumps |
| **fess-ds-example** | main | Template for new data store plugins |

#### LLM Plugins (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-llm-ollama** | main | Ollama chat / embedding integration |
| **fess-llm-openai** | main | OpenAI chat / embedding integration |
| **fess-llm-gemini** | main | Google Gemini chat / embedding integration |
| **fess-llm-bedrock** | main | Amazon Bedrock chat / embedding integration |

#### Storage Plugins (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-storage-s3** | main | Amazon S3 and S3-compatible object storage (`storage.type=s3`, `s3:` crawling) |
| **fess-storage-gcs** | main | Google Cloud Storage (`storage.type=gcs`, `gcs:` crawling) |

#### SSO Plugins (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-sso-saml** | main | SAML 2.0 (`sso.type=saml`) |
| **fess-sso-spnego** | main | Integrated Windows Authentication (`sso.type=spnego`) |
| **fess-sso-entraid** | main | Microsoft Entra ID (`sso.type=entraid`, and the legacy `aad`) |
| **fess-sso-oidc** | main | OpenID Connect — the type is `sso.type=oic`, not `oidc` |

Both groups carry features that were part of the Fess distribution up to 15.8. From 15.9 core keeps
only the extension point — `SsoManager` resolving `<sso.type>Authenticator`, `StorageClientFactory`
resolving `<storage.type>StorageClient` — and the implementation, plus the SDK it needs, ships as
one of these plugins. `fess-storage-*` additionally registers the matching `s3:` / `gcs:` crawler
client through `crawlerClientCreator`; that client class itself stays in `fess-crawler`.

#### WebApp and Other Plugins (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-webapp-classic-api** | main | Classic search API |
| **fess-webapp-v1-api** | main | v1 REST API |
| **fess-webapp-mcp** | main | Model Context Protocol server |
| **fess-webapp-multimodal** | main | CLIP-based multimodal (image) search |
| **fess-webapp-bangs** | main | DuckDuckGo-style `!bang` redirects to external search sites |
| **fess-webapp-example** | main | Template for new webapp plugins |
| **fess-thumbnail-playwright** | main | Playwright-based thumbnail generation |
| **fess-script-groovy** | main | Groovy script engine |
| **fess-script-ognl** | main | OGNL script engine |
| **fess-script-example** | main | Template for new script engines |
| **fess-ingest-example** | main | Template for new ingest processors |

#### Themes (`build_order` 10)

| Repository | Branch | Description |
|------------|--------|-------------|
| **fess-theme-simple** | main | Simple UI theme (Maven plugin) |
| **fess-themes** | main | Static theme collection (`skip_build`) |

#### Tools and Infrastructure

| Repository | Branch | Order | Description |
|------------|--------|-------|-------------|
| **fess-kopf** | main | 20 | OpenSearch admin UI (Vue 3 / Vite) |
| **docker-fess** | main | 30 | Official Docker images and Compose files |
| **fessctl** | main | 40 | Python CLI for the Fess Admin API |
| **fess-test-ui** | main | 99 | Playwright/Python UI test suite (`skip_build`) |
| **homebrew-tap** | main | 99 | Homebrew tap for CodeLibs tools (`skip_build`) |
| **fess-docs** | main | 99 | Documentation sources (`skip_build`) |

`build.sh` only runs Maven. Repositories without a `pom.xml` — `fess-kopf`, `docker-fess`,
`fessctl`, plus the four `skip_build` entries — are reported as skipped and must be built with their
own toolchain (npm, uv/pip, docker).

### `core.yaml`

Minimal set for core development: `fess-parent`, `fess-crawler`, `fess-crawler-playwright`,
`fess-suggest`, `fess`, `docker-fess`, `fess-docs`.

### `plugins.yaml`

`includes: core.yaml` plus data store connectors (`fess-ds-db`, `-csv`, `-json`, `-office365`,
`-salesforce`, `-slack`, `-box`, `-dropbox`, `-s3`, `-gsuite`, `-atlassian`, `-gitbucket`, `-git`)
and `fess-theme-simple`. It covers data stores only — the LLM, webapp, script, storage and SSO
plugins are in `all.yaml`.

## Script Reference

### `clone.sh <set> [options]`

Clones every repository in the set. For an existing checkout it fetches, switches to the configured
branch (stashing uncommitted changes first) and fast-forwards — falling back to
`git reset --hard origin/<branch>` when a fast-forward is not possible.

| Option | Effect |
|--------|--------|
| `--force`, `-f` | Remove the existing directory and re-clone |
| `--verbose`, `-v` | Verbose output |

### `build.sh <set> [options]`

Runs `mvn install` per repository in ascending `build_order`, and **stops at the first failure**.

| Option | Effect |
|--------|--------|
| `--with-tests` | Run tests (`mvn install`) |
| `--skip-tests` | Skip tests — the default (`-DskipTests`) |
| `--clean` | `mvn clean install` |
| `--offline` | Offline build (`mvn -o`) |
| `--verbose`, `-v` | Stream Maven output as well as logging it |

Output goes to `logs/build/<repo>.log`. Without `--verbose` that file is the only place Maven output
lands — check it first when a build fails.

### `sync.sh [set] [options]`

Fetches (`--all --prune`) and pulls. With no set name it syncs every checkout under `repos/`.
Repositories with local changes are skipped unless `--force` is given.

| Option | Effect |
|--------|--------|
| `--fetch-only` | Fetch without pulling |
| `--force` | Stash local changes, pull, then pop the stash |
| `--verbose`, `-v` | Verbose output |

### `status.sh [options]`

Git status for every checkout under `repos/`: branch, short commit, ahead/behind counts and the
number of modified files. Takes no set name.

| Option | Effect |
|--------|--------|
| `--short`, `-s` | One line per repository |
| `--verbose`, `-v` | Also show the remote URL and a sample of changed files |

### `clean.sh [options]`

Removes build artifacts (it does **not** delete repositories). The build system is detected per
repository: `pom.xml` → `mvn clean`; `package.json` → remove `node_modules`, `coverage`, `_site`;
`pyproject.toml` → remove `__pycache__`, `.pytest_cache`, `dist`, `build`, `*.egg-info`.

| Option | Effect |
|--------|--------|
| `--target` | Quick clean — delete output directories directly, without invoking mvn/npm |

### `release-branch.sh <set> -r <branch> -n <version> [options]`

Creates a release branch in each repository of the set and opens a PR bumping the main branch to the
next development version. Requires cloned repositories and an authenticated `gh`.

| Option | Effect |
|--------|--------|
| `--release-branch`, `-r` | Release branch to create (e.g. `15.8.x`) — required |
| `--new-version`, `-n` | New main-branch version (e.g. `15.9.0-SNAPSHOT`) — required |
| `--dry-run` | Report what would happen without changing anything |
| `--skip-existing` | Skip repositories that already have the release branch (default) |
| `--force-version` | Bump the version even when the release branch exists |
| `--verbose`, `-v` | Verbose output |

### `test-integration.sh [options]`

Integration test entry point. Brings up `env/docker-compose.yml` when present and checks for built
Fess artifacts. The actual test commands are still a placeholder.

| Option | Effect |
|--------|--------|
| `--skip-docker` | Do not start Docker services |
| `--verbose`, `-v` | Verbose output |

Every script also accepts `--help` / `-h`.

## Build Notes

Build order: libraries (`corelib`, `curl4j`, `java-saml`, `jcifs`, `jhighlight`, `nekohtml`,
`spnego`, `fess-parent`) → `fesen-httpclient` → `fess-crawler` → `fess-crawler-playwright` →
`fess-suggest` → `fess` → plugins and themes → `fess-kopf` → `docker-fess` → `fessctl` →
`fess-test-ui` / `fess-docs`.

- **Building a Fess binary requires `mvn antrun:run` before `mvn package`.** The antrun plugin has no
  `<executions>`/`<phase>`, so the normal lifecycle never triggers it. It downloads DBFlute, modules,
  plugins, kopf and the `WEB-INF/env/*/lib` jars. Skipping it still produces a bootable WAR/ZIP, but
  every child-process job (crawler, thumbnail, suggest, chunk) dies at DI container initialization
  with `NoClassDefFoundError: jakarta/annotation/PostConstruct`.
- `repos/fess` uses `<packaging>war</packaging>`. To install it as a jar for plugin compilation,
  temporarily switch the packaging to `jar`, run `mvn clean install -DskipTests`, then revert.
- **A `fess-sso-*` or `fess-storage-*` plugin has to match the Fess minor version it is installed
  into.** Up to 15.8 core declares the four authenticators in its own `fess_sso++.xml`, and LastaDi
  merges every `++` file on the class path, so a 15.9 SSO plugin on an older war registers the same
  component name twice: the container still initializes and the lookup then throws
  `TooManyRegistrationComponentException`.
- Run `mvn formatter:format && mvn license:format` in each repository before committing.

## Custom Sets

```bash
cp sets/custom.yaml.example sets/my-set.yaml
```

```yaml
name: my-set
description: "Custom development set"

defaults:
  remote_base: https://github.com/codelibs
  remote_base_ssh: git@github.com:codelibs
  branch: main

# Optional: pull in another set
includes:
  - core.yaml

repositories:
  - name: fess-ds-slack
    build_order: 10

  # Per-repository branch override
  - name: fess-webapp-mcp
    branch: feature/my-feature
    build_order: 10

  # Fork or arbitrary remote
  - name: my-fess-fork
    remote: https://github.com/myuser/fess.git
    build_order: 6

  # Present in repos/ but not built
  - name: fess-docs
    build_order: 99
    skip_build: true
```

Then pass the set name to any script:

```bash
./scripts/clone.sh my-set
./scripts/build.sh my-set
```

Includes are resolved recursively, circular includes are ignored, and duplicate repositories are
de-duplicated before sorting by `build_order`.

## Gotchas

- **The default branch is `main` for every repository.** `master` was renamed to `main` across
  the workspace, so no per-repository override is needed — see the branch columns above. Each
  renamed repository keeps its pre-rename tip on an `old_master` branch.
- `repos/`, `logs/`, `work/`, `docs/` and `target/` are gitignored local scratch, not workspace
  source. Do not `git add` them.
- `repos/` may contain checkouts that are no longer listed in any set — after a repository is
  dropped from `sets/*.yaml`, its clone stays behind. The scripts skip such directories
  silently, so they never sync or build; remove them by hand.
- `plugins.yaml` still lists `fess-ds-office365`, `fess-ds-s3` and `fess-ds-gitbucket`, which are not
  part of `all.yaml`; clone them only if those upstream repositories still exist.

## AI-Assisted Development

`CLAUDE.md` (and its `AGENTS.md` symlink) documents the workspace conventions. The `.claude/`
directory ships project agents (`fess-developer`, `fess-troubleshooter`, `lastaflute-expert`,
`dbflute-expert`, `opensearch-expert`) and skills covering configuration, i18n, testing, release,
documentation review, dependency updates and live-server verification.

## Tech Stack

- **Java 21+** / **Maven 3.8+** — build system
- **OpenSearch** — search backend
- **LastaFlute** / **DBFlute** — web application framework and ORM
- **Playwright** — browser-based crawling, thumbnails and UI tests
- **Vue 3** / **Vite** — fess-kopf admin UI
- **Python** — fessctl and the UI test suite
- **Docker** — containerization and integration testing

## Contributing

Work happens in the individual repositories under `repos/`, each of which has its own contribution
guidelines. For changes to this workspace itself:

1. Create a feature branch
2. Make your change
3. Open a pull request against `main`

## License

Apache License 2.0
