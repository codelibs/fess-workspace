# Checklist: Infrastructure, RST Syntax, and Versioning

Detailed verification rules for JVM options, deployment paths, RST syntax, and version consistency.

## E0. CLI Command and Script Verification

- When docs reference CLI commands (e.g., `./bin/fess-plugin install`, `./bin/fess-cli`), verify the script exists in `repos/fess/src/main/assemblies/files/`. The actual available scripts are: `fess`, `fess.bat`, `fess.in.sh`, `fess.in.bat`, `generate-thumbnail`, `service.bat`, and service executables. No `fess-plugin` or similar CLI tool exists — plugin management is admin UI only (`AdminPluginAction.java`).
- **Docker environment variable verification**: When docs reference Docker-specific env vars (e.g., `FESS_PLUGINS`, `FESS_AUTO_INSTALL`), verify they are consumed by the Docker entrypoint script or `fess.in.sh`. Fabricated env vars that look plausible are silently ignored at runtime. Check `fess.in.sh` for `${VAR_NAME:-default}` patterns to confirm support.
- **Installation method claims**: Fess plugin installation is available only via the admin UI ("システム" → "プラグイン"). Docs claiming alternative installation methods (CLI commands, Docker env vars, config file declarations) must be verified against source. If no implementation exists, report as INCORRECT (J4: fabricated feature).

## F0. Linux vs Windows Environment Variable Differences

- `fess.in.sh` (Linux) supports environment variable overrides with fallback defaults for many settings: `FESS_PORT`, `FESS_CONTEXT_PATH`, `FESS_HEAP_SIZE`, `FESS_MIN_MEM`, `FESS_MAX_MEM`, `FESS_PROXY_HOST`, `FESS_PROXY_PORT`, `FESS_NON_PROXY_HOSTS`, `SEARCH_ENGINE_HTTP_URL`, etc.
- `fess.in.bat` (Windows) **hardcodes** most of these values directly (e.g., `-Dfess.port=8080`, `-Dfess.context.path=/`) and does NOT read from corresponding environment variables. Exceptions: `FESS_PROXY_HOST`, `FESS_PROXY_PORT`, `FESS_NON_PROXY_HOSTS` ARE supported as env vars on Windows.
- **Dedicated env vars for common settings**: `fess.in.sh` provides dedicated environment variables with defaults for frequently changed settings. When docs describe how to change these settings, prefer referencing the dedicated env var over raw `FESS_JAVA_OPTS`:
  - `FESS_LOG_LEVEL` (default: `warn`) — sets `-Dfess.log.level`
  - `FESS_PORT` (default: `8080`) — sets `-Dfess.port`
  - `FESS_HEAP_SIZE`, `FESS_MIN_MEM`, `FESS_MAX_MEM` — heap settings
  - `SEARCH_ENGINE_HTTP_URL` — OpenSearch endpoint
- When docs describe "set environment variable X to change Y", verify whether the env var is actually read in both `fess.in.sh` AND `fess.in.bat`. If Linux-only, the doc must include a warning that Windows users need to edit `bin\fess.in.bat` directly.
- `service.bat` (Windows service) has its own hardcoded `FESS_PARAMS` that duplicates some settings from `fess.in.bat` — changes to `fess.in.bat` may not propagate to the service configuration.

## F1. Docker Environment Variable Mapping

- Docs may claim that Fess properties can be configured via Docker environment variables using an uppercase/underscore convention (e.g., `rag.llm.openai.api.key` → `RAG_LLM_OPENAI_API_KEY`). These mappings are NOT implemented in Java source code — they are handled by the Docker entrypoint script or LastaFlute's environment-to-property mapping framework.
- **Verification approach**: (1) Check the Docker entrypoint script in the Fess Docker image (typically `docker-entrypoint.sh` or similar) for explicit `sed`/`envsubst` patterns or property-file generation logic. (2) Check if LastaFlute's `lasta_di.properties` or similar framework configuration enables automatic env-var-to-property mapping. (3) If neither source confirms the mapping, report the env var claims as UNVERIFIABLE and flag for manual testing.
- **Common patterns to verify**: `RAG_LLM_NAME`, `RAG_CHAT_ENABLED`, `RAG_LLM_{PROVIDER}_API_KEY`, `RAG_LLM_{PROVIDER}_MODEL`. Also check whether `system.properties` entries (e.g., `rag.llm.name`) vs `fess_config.properties` entries (e.g., `rag.chat.enabled`) use different env-var mapping mechanisms.
- **docker-compose examples**: When docs provide `docker-compose.yml` snippets with environment variables, verify that all listed env vars are actually consumed. Fabricated env vars that look plausible but have no mapping will be silently ignored at runtime.

## F. JVM Options and Memory Settings

- Compare documented JVM flags against `jvm.crawler.options`, `jvm.suggest.options`, `jvm.thumbnail.options` in `fess_config.properties`.
- Verify heap sizes (`-Xms`, `-Xmx`), metaspace, GC settings.
- Check environment variable names (`FESS_HEAP_SIZE`, `FESS_MIN_MEM`, `FESS_MAX_MEM`, etc.) and their defaults against:
  - Linux: `repos/fess/src/main/assemblies/files/fess.in.sh`
  - Windows: `repos/fess/src/main/assemblies/files/fess.in.bat`
  - Package: `repos/fess/src/packaging/common/env/fess`

## I4. Deployment and File Paths

- When docs reference deployment file paths (e.g., `app/WEB-INF/conf/system.properties`, `/etc/fess/`), verify against:
  1. `src/main/assemblies/common-bin.xml` — defines directory structure for zip/tar.gz distributions
  2. `src/packaging/rpm/packaging.properties`, `src/packaging/deb/packaging.properties` — package-specific paths (RPM uses `/etc/sysconfig/fess`, DEB uses `/etc/default/fess` for env files)
  3. `ResourceUtil.java` — runtime path resolution hierarchy: Docker (`/opt/fess`) → system property (`FESS_CONF_PATH`) → default (`WEB-INF/conf`)
- Verify that documented paths for both zip-install and RPM/DEB-install variants are accurate for their respective deployment methods.
- **Classpath resources vs conf dir in RPM/DEB**: `packaging.fess.conf.dir=/etc/fess` is for Fess application configuration files (`system.properties`, etc.). Java classpath resources (e.g., `log4j2.xml`, `fess_config.properties`) are deployed to `${packaging.fess.lib.dir}/classes/` = `/usr/share/fess/lib/classes/` (see `pom.xml` `<prefix>${packaging.fess.lib.dir}/classes</prefix>`). A common doc error is placing classpath resources under `/etc/fess/` — verify the actual packaging target in `pom.xml` for each file type.

## I5. Log File Names

- Fess spawns separate JVM processes for crawling, suggest, and thumbnail generation. Each process sets `-Dfess.log.name` via `ExecJob.getLogName()`, which returns `"fess-" + getExecuteType()` (hyphen-separated, NOT underscore).
- Correct log file names:
  - Crawler: `fess-crawler.log` (NOT `fess_crawler.log`)
  - Suggest: `fess-suggest.log`
  - Thumbnail: `fess-thumbnail.log`
  - Main Fess: `fess.log`
- Source: `ExecJob.getLogName()` (`repos/fess/src/main/java/org/codelibs/fess/job/ExecJob.java`), log4j2.xml uses `${sys:fess.log.name:-fess}.log`
- Additional log files defined in `log4j2.xml` appenders (not sub-process logs):
  - `audit.log` — audit log (authentication, admin operations)
  - `searchlog.log` — search log
  - `fess-llm.log` — LLM/RAG chat log
  - `fess-urls.log` — crawler URL stats log (crawler process only, defined in `WEB-INF/env/crawler/resources/log4j2.xml`)
- Log directory: `${log.file.basedir}` — resolves to `/var/log/fess/` for RPM/DEB, `logs/` for zip/tar.gz
- Log4j2 property names: docs must use the actual property names from `log4j2.xml` (e.g., `${log.file.basedir}`, NOT `${log.dir}`; `${domain.name}`, NOT hardcoded filenames)
- When docs reference log file paths, verify both the file name (hyphen convention) and directory path (deployment-specific).

## L. RST Syntax

- `list-table` column counts and alignment.
- Code block syntax (`::`  or `.. code-block::`).
- Cross-references (`:doc:`, `:ref:`) point to existing targets.
- `|Fess|` substitution used consistently.
- **Numbered list continuity**: Check that RST numbered lists (`1.`, `2.`, `3.`, ...) have no skipped or duplicated numbers. A common copy-paste error is sequences like `1. 2. 4.` (skipping 3) or `1. 2. 2.` (duplicating 2). RST auto-numbering with `#.` avoids this, but most Fess docs use explicit numbers.

## M. Version Consistency

- Version numbers in examples, JAR filenames, and URLs match the doc version (e.g., `15.6`).
- Plugin JAR naming convention: `fess-{type}-{name}-{version}.jar`.
