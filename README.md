# fess-workspace

A multi-repository development environment for [Fess](https://fess.codelibs.org/), managed by YAML set definitions.

## Overview

fess-workspace provides a unified development workflow for the Fess ecosystem:

- **Set-based management**: Define which repositories to work with via YAML files
- **Dependency-aware builds**: Automatically build in the correct order
- **Independent repositories**: Each repo is a full git clone (not submodules)
- **Claude Code optimized**: Includes CLAUDE.md for AI-assisted development

## Prerequisites

- Git
- Java 21+
- Maven 3.8+
- yq: `brew install yq`
- Docker (optional, for integration tests)

## Quick Start

```bash
# Clone this repository
git clone git@github.com:codelibs/fess-workspace.git
cd fess-workspace

# Clone core repositories
./scripts/clone.sh core

# Build all components
./scripts/build.sh core

# Check status
./scripts/status.sh
```

## Repository Structure

```
fess-workspace/
├── sets/                  # Set definitions
│   ├── core.yaml         # Core development set
│   ├── plugins.yaml      # Plugin development set
│   └── custom.yaml.example
├── scripts/
│   ├── clone.sh          # Clone repos from set
│   ├── build.sh          # Build in dependency order
│   ├── status.sh         # Show repo status
│   ├── sync.sh           # Fetch and pull updates
│   ├── clean.sh          # Remove repos
│   └── test-integration.sh
├── repos/                 # Cloned repositories (gitignored)
└── env/                   # Docker environment
```

## Available Sets

### core.yaml

Core Fess development:

| Repository | Build Order | Description |
|------------|-------------|-------------|
| fess-parent | 1 | Parent POM |
| fess-crawler | 2 | Web crawler |
| fess-suggest | 3 | Suggest feature |
| fess | 4 | Main application |

### plugins.yaml

Includes core plus data store plugins:

- fess-ds-db, fess-ds-csv, fess-ds-json
- fess-ds-office365, fess-ds-salesforce, fess-ds-slack
- fess-ds-box, fess-ds-dropbox, fess-ds-s3
- fess-ds-gsuite, fess-ds-atlassian, fess-ds-git

## Script Usage

### Clone

```bash
./scripts/clone.sh core           # Clone core set
./scripts/clone.sh plugins        # Clone plugins (includes core)
./scripts/clone.sh core --force   # Force re-clone
```

### Build

```bash
./scripts/build.sh core             # Build (skip tests)
./scripts/build.sh core --with-tests # Build with tests
./scripts/build.sh core --clean     # Clean build
./scripts/build.sh plugins          # Build all plugins
```

### Status

```bash
./scripts/status.sh           # Show all repo status
./scripts/status.sh --short   # Compact output
./scripts/status.sh --verbose # Include remote info
```

### Sync

```bash
./scripts/sync.sh             # Sync all repos
./scripts/sync.sh core        # Sync core set only
./scripts/sync.sh --fetch-only # Fetch without pull
```

### Clean

```bash
./scripts/clean.sh            # Remove all repos (confirms)
./scripts/clean.sh --yes      # No confirmation
./scripts/clean.sh --target   # Clean Maven target/ only
```

## Development Workflow

```bash
# Initial setup
./scripts/clone.sh core
./scripts/build.sh core

# Daily development
./scripts/sync.sh core          # Update to latest
cd repos/fess                   # Work in specific repo
git checkout -b feature/my-feature
# Make changes...
./scripts/build.sh core         # Verify build
git commit -m "Add feature"
git push origin feature/my-feature
# Create PR on GitHub
```

## Custom Sets

Create your own set for specific development needs:

```bash
cp sets/custom.yaml.example sets/custom.yaml
```

Edit `sets/custom.yaml`:

```yaml
name: custom
description: "My custom set"

defaults:
  remote_base: git@github.com:codelibs
  branch: master

repositories:
  - name: fess
    build_order: 1
  - name: fess-ds-db
    build_order: 2
```

Then:

```bash
./scripts/clone.sh custom
./scripts/build.sh custom
```

## HTTPS Alternative

If SSH access is not configured, use HTTPS. Edit the set file:

```yaml
defaults:
  # remote_base: git@github.com:codelibs
  remote_base: https://github.com/codelibs
```

## License

Apache License 2.0
