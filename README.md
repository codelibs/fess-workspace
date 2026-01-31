# fess-workspace

A comprehensive multi-repository development environment for [Fess](https://fess.codelibs.org/) enterprise search server, managed through YAML set definitions.

## Overview

fess-workspace provides a unified development workflow for the entire Fess ecosystem:

- **Set-based management**: Define which repositories to work with via YAML files
- **Dependency-aware builds**: Automatically build in the correct order
- **Independent repositories**: Each repo is a full git clone (not submodules)
- **Comprehensive coverage**: Includes all Fess components, plugins, and extensions
- **Claude Code optimized**: Includes CLAUDE.md for AI-assisted development

## Prerequisites

- **Git**: Version control
- **Java 21+**: Required for building Fess components
- **Maven 3.8+**: Build tool
- **yq**: YAML processor (`brew install yq` on macOS)
- **Docker** (optional): For integration tests and containerized development

## Quick Start

```bash
# Clone this workspace
git clone git@github.com:codelibs/fess-workspace.git
cd fess-workspace

# Clone all repositories (recommended)
./scripts/clone.sh all

# Build all components
./scripts/build.sh all

# Check status
./scripts/status.sh
```

## Repository Structure

```
fess-workspace/
├── sets/                     # Repository set definitions
│   ├── all.yaml             # Complete ecosystem (recommended)
│   ├── core.yaml            # Core development only
│   ├── plugins.yaml         # Core + plugins
│   └── custom.yaml.example  # Template for custom sets
├── scripts/                 # Management scripts
│   ├── clone.sh            # Clone repositories from set
│   ├── build.sh            # Build in dependency order
│   ├── status.sh           # Show repository status
│   ├── sync.sh             # Fetch and pull updates
│   ├── clean.sh            # Remove repositories
│   └── lib/common.sh       # Shared utilities
├── repos/                   # Cloned repositories (gitignored)
└── CLAUDE.md               # AI development instructions
```

## Available Sets

### all.yaml (Recommended Default)

The complete Fess development ecosystem with all components, plugins, and tools:

#### Core Components
| Repository | Description |
|------------|-------------|
| **fess-parent** | Maven parent POM with shared configuration |
| **fess-crawler** | Web crawler engine for document collection |
| **fess-crawler-playwright** | Modern browser-based crawler using Playwright |
| **fess-suggest** | Search suggestion and auto-completion features |
| **fess** | Main Fess search application |

#### Data Store Connectors
| Repository | Description |
|------------|-------------|
| **fess-ds-atlassian** | Confluence and Jira connector |
| **fess-ds-box** | Box cloud storage connector |
| **fess-ds-csv** | CSV file data source |
| **fess-ds-db** | Database connector (JDBC) |
| **fess-ds-dropbox** | Dropbox cloud storage connector |
| **fess-ds-elasticsearch** | Elasticsearch data source |
| **fess-ds-example** | Example data source template |
| **fess-ds-git** | Git repository crawler |
| **fess-ds-gsuite** | Google Workspace (G Suite) connector |
| **fess-ds-json** | JSON file data source |
| **fess-ds-microsoft365** | Microsoft 365 / Office 365 connector |
| **fess-ds-salesforce** | Salesforce CRM connector |
| **fess-ds-sharepoint** | Microsoft SharePoint connector |
| **fess-ds-slack** | Slack workspace connector |
| **fess-ds-wikipedia** | Wikipedia content crawler |

#### Extensions and Plugins
| Repository | Description |
|------------|-------------|
| **fess-ingest-example** | Example ingest processor |
| **fess-script-example** | Example script implementations |
| **fess-script-ognl** | OGNL scripting support |
| **fess-theme-codesearch** | Code search theme |
| **fess-theme-simple** | Simple UI theme |
| **fess-thumbnail-playwright** | Thumbnail generation using Playwright |

#### Web Applications
| Repository | Description |
|------------|-------------|
| **fess-webapp-classic-api** | Classic API interface |
| **fess-webapp-example** | Example web application |
| **fess-webapp-mcp** | Model Context Protocol integration |
| **fess-webapp-multimodal** | Multimodal search interface |
| **fess-webapp-semantic-search** | Semantic search capabilities |

#### Infrastructure and Tools
| Repository | Description |
|------------|-------------|
| **fess-kopf** | Elasticsearch/OpenSearch admin interface |
| **docker-fess** | Docker containerization |
| **fess-docs** | Documentation (build skipped) |

### core.yaml

Minimal set for core Fess development:
- fess-parent, fess-crawler, fess-crawler-playwright, fess-suggest, fess, docker-fess, fess-docs

### plugins.yaml

Core components plus essential data store plugins:
- Includes all from core.yaml
- Adds key data store connectors (DB, CSV, JSON, Office365, etc.)
- Includes theme and webapp plugins

## Script Usage

### Clone Repositories

```bash
./scripts/clone.sh all              # Clone all repositories (recommended)
./scripts/clone.sh core             # Clone core components only
./scripts/clone.sh plugins          # Clone core + plugins
./scripts/clone.sh all --force      # Force re-clone existing repos
```

### Build Projects

```bash
./scripts/build.sh all              # Build all (skip tests)
./scripts/build.sh all --with-tests # Build all with tests
./scripts/build.sh all --clean      # Clean build
./scripts/build.sh core             # Build core components only
```

**Build Order**: Projects build automatically in dependency order (fess-parent → fess-crawler → fess-suggest → fess → plugins)

### Repository Management

```bash
./scripts/status.sh                 # Show all repository status
./scripts/status.sh --short         # Compact output
./scripts/status.sh --verbose       # Include remote information

./scripts/sync.sh all               # Sync all repositories
./scripts/sync.sh core              # Sync core set only  
./scripts/sync.sh --fetch-only      # Fetch without pulling

./scripts/clean.sh                  # Remove all repos (with confirmation)
./scripts/clean.sh --yes            # Skip confirmation
./scripts/clean.sh --target         # Clean Maven target/ directories only
```

## Development Workflow

### Initial Setup

```bash
# Clone workspace
git clone git@github.com:codelibs/fess-workspace.git
cd fess-workspace

# Set up complete environment
./scripts/clone.sh all
./scripts/build.sh all
```

### Daily Development

```bash
# Update to latest
./scripts/sync.sh all

# Work on specific component
cd repos/fess
git checkout -b feature/my-enhancement

# Make changes...
# Build and test
cd ../../
./scripts/build.sh all --with-tests

# Commit and create PR
cd repos/fess
git commit -m "Add new feature"
git push origin feature/my-enhancement
# Create pull request on GitHub
```

### Feature Development

```bash
# Create feature branch in target repository
cd repos/fess-ds-slack
git checkout -b feature/improved-api

# Develop feature...
# Test locally
mvn test

# Build entire ecosystem to ensure compatibility
cd ../../ 
./scripts/build.sh all

# Submit changes
cd repos/fess-ds-slack
git push origin feature/improved-api
```

## Custom Development Sets

Create custom sets for specific development needs:

```bash
cp sets/custom.yaml.example sets/my-project.yaml
```

Edit `sets/my-project.yaml`:

```yaml
name: my-project
description: "Custom set for specific project needs"

defaults:
  remote_base: git@github.com:codelibs
  branch: master

repositories:
  - name: fess
    build_order: 1
  - name: fess-ds-slack  
    build_order: 2
  - name: fess-theme-simple
    build_order: 3
```

Use your custom set:

```bash
./scripts/clone.sh my-project
./scripts/build.sh my-project
```

## HTTPS Alternative

If SSH access is not configured, switch to HTTPS. Edit any set file:

```yaml
defaults:
  # remote_base: git@github.com:codelibs  # SSH (commented out)
  remote_base: https://github.com/codelibs  # HTTPS
```

## Integration Testing

```bash
# Run integration tests (requires Docker)
./scripts/test-integration.sh

# Test specific components
cd repos/fess
mvn integration-test
```

## Troubleshooting

### Common Issues

**Build Failures**: Ensure build order is respected. Use `./scripts/build.sh all --clean` for fresh build.

**Missing Dependencies**: Verify yq is installed (`brew install yq` on macOS).

**Clone Errors**: Check SSH keys or switch to HTTPS in set configuration.

**Memory Issues**: Increase Maven memory: `export MAVEN_OPTS="-Xmx2g -XX:MaxMetaspaceSize=512m"`

### Getting Help

```bash
./scripts/clone.sh --help
./scripts/build.sh --help
./scripts/status.sh --help
```

## Tech Stack

- **Java 21+** / **Maven 3.8+**: Build system
- **OpenSearch**: Search engine backend
- **LastaFlute**: Web application framework
- **Playwright**: Modern web crawling
- **Docker**: Containerization and testing

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`  
5. Open a Pull Request

## License

Apache License 2.0
