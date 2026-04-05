# Checklist: Configuration and Properties

Detailed verification rules for config properties, defaults, permissions, ports, technical descriptions, placeholders, validation, index names, admin UI, and deployment paths.

## A. Configuration Property Names

- Every property key in the doc must exist in one of the following sources:
  1. `fess_config.properties` — build-time configuration managed by `FessConfig.java` getters
  2. `Constants.java` — system property keys (e.g., `LDAP_PROVIDER_URL = "ldap.provider.url"`) accessed via `FessProp.java`'s `getSystemProperty()`/`setSystemProperty()` and stored in `system.properties`
  3. JVM system properties via direct `System.getProperty("key")` — not managed by `FessConfig` or `FessProp`. These are set via `-Dkey=value` in `fess.in.sh`/`fess.in.bat`. Grep for `System.getProperty` in the relevant package to find these. Common pattern: feature-toggle or searcher-selection properties (e.g., `rank.fusion.searchers`) that bypass the config framework entirely. These are easy to miss in docs since they don't appear in `fess_config.properties` or `Constants.java`.
- Distinguish which type a property belongs to: `fess_config.properties` properties have corresponding `FessConfig.java` getters with `get{PropertyName}()` pattern, while system properties are accessed via `getSystemProperty(Constants.KEY, default)` in `FessProp.java`. Direct `System.getProperty()` calls have no getter or constant — they must be found by grepping source code.
- Check for typos, outdated names, or incorrect prefixes.
- **Verify the referenced properties file is correct**: Docs may claim a property is in `fess_config.properties` when it actually belongs to:
  - `system.properties` — system properties accessed via `getSystemProperty()`/`setSystemProperty()` in `FessProp.java` and managed through the admin UI "General" settings
  - `fess_env.properties` — LastaFlute environment config (e.g., `mail.smtp.server.main.host.and.port`). Note the LastaFlute mail property format differs from standard JavaMail: it uses `mail.smtp.server.main.host.and.port=host:port` (single combined property), not separate `mail.smtp.host`/`mail.smtp.port`.
  - Log4j2 system properties with `fess.` prefix (e.g., `fess.log.notification.level`) — used in `log4j2.xml` via `${sys:fess.log.notification.level:-ERROR}` syntax
- **Check narrative text too, not just tables**: Property file references in troubleshooting sections, setup instructions, and example code blocks need the same verification as formal `list-table` entries. A common error is referencing `fess_config.properties` in a troubleshooting step when the actual file is `fess_env.properties` or the property is a system property.
- Watch for property key transformation patterns:
  - SAML: `saml.` prefix is stripped and `onelogin.saml2.` is prepended. So `saml.strict` maps to `onelogin.saml2.strict`, but `saml.security.strict` would incorrectly map to `onelogin.saml2.security.strict`.
  - Config override: Properties can be overridden via system properties with `Constants.FESS_CONFIG_PREFIX`.

## B. Default Values

- Compare every documented default against:
  1. `fess_config.properties` (explicit defaults)
  2. `FessConfig.java` (`DEFAULT_*` constants, getter fallback values)
  3. Java code (`getSystemProperty("key", "default")` patterns)
  4. Plugin-specific properties files (for `fess-llm-*`, `fess-ds-*` etc.)
- **Hierarchical config with fallback**: LLM plugins use `getConfigWithFallback(primaryKey, fallbackKey)` pattern where properties resolve as `{prefix}.{promptType}.{param}` → `{prefix}.default.{param}` → hardcoded default in `applyDefaultParams()`. Docs must use the correct key level — a property like `rag.llm.ollama.top.p` is invalid if only `rag.llm.ollama.{promptType}.top.p` and `rag.llm.ollama.default.top.p` exist in code. Trace the `applyPromptTypeParams()` and `getConfigWithFallback()` methods in the plugin client class to verify the exact key patterns. Note: not all plugins use `getConfigWithFallback()` — some (e.g., Gemini) use `getOrDefault()` directly. Always check the actual plugin class.
- **LLM per-prompt-type defaults via `applyDefaultParams()`**: Each LLM plugin client class has an `applyDefaultParams(request, promptType)` method containing a switch statement with hardcoded defaults (temperature, max.tokens, thinking.budget) per prompt type. This is a critical source of truth for two checks: (1) **Prompt type completeness** — every case in the switch statement must appear in the doc's prompt type table (common miss: `queryregeneration`). (2) **Default value accuracy** — the hardcoded values in each case are the effective defaults when no config property is set. The call chain is: `applyPromptTypeParams()` reads config properties first → `applyDefaultParams()` fills in any remaining nulls with hardcoded values.
- **Undocumented configurable properties in plugin classes**: Scan all `getConfigInt()`, `getConfigLong()`, and `getOrDefault(getConfigPrefix() + ".*")` calls in the plugin client class AND the base class (`AbstractLlmClient`) to find every property that can be configured via `fess_config.properties`. Common undocumented categories: history limits (`history.max.chars`, `intent.history.max.messages`, `intent.history.max.chars`, `history.assistant.max.chars`, `history.assistant.summary.max.chars`), evaluation settings (`chat.evaluation.description.max.chars`), and concurrency (`concurrency.wait.timeout`). If a property is configurable in code but absent from the doc's settings table, report as MISSING.
- **Base class defaults inherited by all providers**: When checking defaults for plugin-level properties (e.g., `rag.llm.{provider}.max.concurrent.requests`), always check the base class (`AbstractLlmClient`) first. If a plugin subclass does not override the getter method, the base class default applies to ALL providers equally. A common doc error is claiming different defaults per provider when no override exists. Verify by grepping the plugin class for the method name — if absent, the base class value is authoritative.
- **Sentinel values with dynamic defaults**: When a property's default is a sentinel value (e.g., `-1`, `0`, `auto`), trace the consuming code to find the actual computed value. Common pattern: `if (value <= 0) { value = Runtime.getRuntime().availableProcessors() * N; }`. Docs saying just "default: -1" without explaining the effective behavior are incomplete — report as MISSING.
- **Cross-property minimum constraints**: A property's effective value may be clamped by another property (e.g., `rank.fusion.window_size` must be >= `paging.search.page.max.size * 2`). Check the `@PostConstruct` init method or validation code for `Math.max()`, conditional overrides, or warning logs that indicate such constraints. These are frequently undocumented — report as MISSING.
- **"Required" markers vs actual defaults**: When docs mark a property default as 「必須」「（必須）」or "required", verify whether the property actually has no default in code. System properties accessed via `getSystemProperty("key", "default")` always have a fallback value — even if that fallback is an empty string or a provider-specific URL (e.g., Google OAuth2 endpoints). If code provides any default, report the doc as INCORRECT. The fix should show the actual default and add a note that the user should configure their own value. Common pattern: SSO properties default to a specific provider's endpoints but docs claim "required" since users must set their own.
- **Admin UI configurability not mentioned**: When docs describe setting properties only by editing a file (e.g., `system.properties`), check whether those properties are also configurable via the admin UI. Trace `AdminGeneralAction.java` for `setSystemProperty("property.name", ...)` calls. If the property is UI-configurable but the doc only mentions file editing, report as MISSING. The fix should add a note about the admin UI alternative (e.g., 「管理画面の「システム > 全般」ページからも設定できます」).
- **Shared parameter classes and inherited defaults**: API endpoints may reuse shared `RequestParams` inner classes (e.g., `JsonRequestParams`) where defaults come from general config properties, not endpoint-specific settings. Example: scroll search reuses the same `getPageSize()` as regular search, so its default is `paging.search.page.size` (10), not a scroll-specific value. Always trace the actual `getPageSize()` / `getParameter()` implementation to find the real default and its max cap (e.g., `paging.search.page.max.size`). Docs claiming endpoint-specific defaults (e.g., "scroll default: 100") when the code uses shared general defaults should be reported as INCORRECT.

## E. Permission Format

- Fess uses `{role}`, `{user}`, `{group}` prefix format (e.g., `{role}guest`).
- Verify documented examples use this format, not bare names like `role_xxx`.
- Cross-reference: `role.search.user.prefix`, `role.search.group.prefix`, `role.search.role.prefix` in `fess_config.properties`.

## G. Port Numbers and URLs

- Fess default: `8080`
- OpenSearch HTTP: `9201` (Fess custom, not standard 9200)
- OpenSearch Transport: `9301`
- `search_engine.http.url` default: `http://localhost:9201`
- **Packaging vs zip defaults**: RPM/DEB packaging env (`src/packaging/common/env/fess`) sets `SEARCH_ENGINE_HTTP_URL=http://localhost:9200` (standard OpenSearch port), while `fess_config.properties` defaults to `http://localhost:9201` (Fess-bundled OpenSearch port). If docs describe port defaults, verify which distribution type is being referenced. Docs targeting zip/tar.gz users should show 9201; docs targeting RPM/DEB users should show 9200.

## G2. Scope of Applicability

- When docs claim a setting applies "system-wide", "application-wide", or to "all HTTP connections", verify the actual scope in source code:
  1. **`fess_config.properties` settings** (e.g., `http.proxy.*`) may only be consumed by specific components (e.g., crawler via `CrawlingConfig.initializeDefaultHttpProxy()`), not by all Fess subsystems. Trace the property's getter in `FessConfig.java` to find all call sites.
  2. **JVM system properties** (e.g., `-Dhttp.proxyHost` via `FESS_PROXY_HOST` env var) are truly JVM-wide and affect all Java HTTP clients including SSO, LLM, and external library connections.
  3. **`client.*` crawl config parameters** only apply to the specific crawl configuration where they are set, not globally.
- A common doc error is describing component-specific settings as "system-wide" or vice versa. If a doc uses scope words like 「全体」「すべて」「システム全体」, verify whether the setting truly has that scope.

## H. Technical Descriptions

- Verify algorithm descriptions (e.g., RRF formula) match implementation.
- Check behavior descriptions (e.g., "returns 429 when CPU >= threshold") against actual logic.
- Verify enum/mode values (e.g., `smart_summary`, `full`, `truncated`) match switch statements or constants.
- **External API type conversion**: Config values may be transformed before being sent to external APIs. Trace the request-building code (e.g., `buildRequestBody()`) to verify. Example: Ollama's `thinking.budget` (integer) is converted to a boolean `think` flag (`> 0` → `true`). If docs imply granular control but the code only supports on/off, report as INCORRECT.
- **LLM reasoning model parameter suppression**: LLM plugin clients define model-category methods (`isReasoningModel()`, `supportsTemperature()`, `useMaxCompletionTokens()`) that conditionally suppress or transform parameters based on the model name prefix (e.g., `o1`, `o3`, `o4`, `gpt-5`). Common patterns to verify: (1) **Temperature suppression** — `supportsTemperature()` returns `false` for reasoning models, so custom temperature values are silently ignored. If docs describe temperature as universally configurable without this caveat, report as INCORRECT. (2) **Token parameter switching** — `useMaxCompletionTokens()` selects between `max_tokens` and `max_completion_tokens` API parameters. Docs should note this is automatic. (3) **Token multiplier** — reasoning models may multiply `max_tokens` by `reasoning.token.multiplier` (default: 4) when no explicit value is set. (4) **Auto-applied reasoning_effort** — `applyDefaultParams()` may set `reasoning_effort` to `"low"` for simple prompt types (intent, evaluation, etc.) on reasoning models. If docs show the default as「未設定」for these prompt types, report as INCORRECT. Check each plugin's `buildRequestBody()` method and the `isReasoningModel()`/`supportsTemperature()`/`useMaxCompletionTokens()` methods for the model prefix list.
- **OpenSearch concept accuracy in descriptions**: Verify that property descriptions correctly identify the OpenSearch concept the property controls. Common confusions:
  - 「インデックス名」(index name) vs 「フィールド名」(field name) — e.g., `query.geo.fields` specifies field names, not index names
  - 「インデックス」(index) vs 「エイリアス」(alias) — e.g., `fess.search` is an alias, not an index
  - 「マッピング」(mapping) vs 「タイプ」(type)
  Trace the property usage in Java code to confirm what the value actually represents. Property names often contain hints (e.g., `*.fields` → field names), but always verify against the consuming code.

## H4. Feature Existence Verification

- When docs describe a feature as usable (e.g., "use parameter X to do Y"), verify that **both** the parameter-receiving code **and** the feature-executing code exist. A parameter being parsed does not mean the feature is fully implemented.
- **Sort fields**: Fess whitelists sortable fields in `QueryFieldConfig.java` (`sortFields` array, initialized from `score`, `filename`, `created`, `content_length`, `last_modified`, `timestamp`, `click_count`, `favorite_count` + `query.additional.sort.fields`). If a doc claims a sort key (e.g., `sort=location.distance`), verify it appears in this whitelist or has a dedicated `SortBuilder` implementation. Geo distance sorting requires `GeoDistanceSortBuilder` — grep for it to confirm existence.
- **Request parameters → behavior**: For parameters documented as triggering specific behavior (filtering, sorting, aggregation), trace the full code path: (1) parameter extraction, (2) query/sort builder construction, (3) inclusion in the search request. If any link is missing, report as INCORRECT.
- **Common pattern**: AI-generated or speculative documentation may describe OpenSearch capabilities that Fess does not expose. Always verify against Fess's Java code, not OpenSearch's general documentation.

## H3. Placeholder and Format Patterns in Property Values

- Filter properties (e.g., `ldap.account.filter`, `ldap.group.filter`, `ldap.admin.user.filter`) use placeholder patterns. The correct placeholder depends on how the value is consumed in Java code:
  - `String.format()` → requires `%s` (e.g., `ldap.group.filter=(member=%s)`)
  - `MessageFormat.format()` → requires `{0}` (rare in Fess)
- Always trace the property value to the Java method that processes it to confirm the correct placeholder format.
- Common pattern: grep for the property's constant name in the implementation class and check how the value is used (e.g., `String.format(groupFilter, s)` confirms `%s`).

## A2. Crawler Config Parameters (`client.*`)

- Docs describing the "設定パラ���ーター" (Config Parameters) field in crawl config forms use `client.*` prefixed parameters. These are stripped of the `client.` prefix by `ParameterUtil.createConfigParameterMap()` and passed to the crawler client's init parameters.
- Every `client.*` parameter in docs must exist in one of:
  1. `CrawlingConfig.Param.Client` constants (`repos/fess/src/main/java/org/codelibs/fess/opensearch/config/exentity/CrawlingConfig.java`) — Fess-level parameters
  2. `HcHttpClient` property constants (`repos/fess-crawler/fess-crawler/src/main/java/org/codelibs/fess/crawler/client/http/HcHttpClient.java`) — crawler client parameters
  3. `AbstractCrawlerClient` property constants — base client parameters (e.g., `maxContentLength`)
- **Fess-level parameter conversion**: Some `client.*` parameters are consumed and transformed by Fess before reaching the crawler client. Example: `client.proxyUsername` and `client.proxyPassword` are converted to a `UsernamePasswordCredentials` object by `WebConfig.java` and stored as `proxyCredentials`. These appear in `Param.Client` but NOT in `HcHttpClient` constants.
- **JVM-level vs client-level**: Some settings that look like they could be `client.*` parameters are actually JVM system properties. Example: `nonProxyHosts` is NOT a `client.*` parameter — it must be set via `-Dhttp.nonProxyHosts` or the `FESS_NON_PROXY_HOSTS` environment variable in `fess.in.sh`. If docs describe JVM-level settings as `client.*` parameters, report as INCORRECT.

## I0. Admin UI Setting Persistence Claims

- When docs claim that a setting changed via the admin UI "persists after restart" or "is saved permanently", verify the actual persistence mechanism:
  1. **Persisted**: The setting is stored via `fessConfig.setSystemProperty()` followed by `fessConfig.storeSystemProperties()` — written to `system.properties` on disk
  2. **Runtime-only**: The setting uses `System.setProperty()`, `Configurator.setLevel()`, or similar in-memory mechanisms — lost on restart
- **Execution order matters**: In `AdminGeneralAction`, `storeSystemProperties()` is called at a specific point. Settings applied AFTER that call (e.g., `systemHelper.setLogLevel()` at line 312, after `storeSystemProperties()` at line 306) are runtime-only even though other settings on the same page ARE persisted.
- If a runtime-only setting is documented as persistent, report as INCORRECT. The fix should clarify that the setting reverts to the startup default (e.g., `FESS_LOG_LEVEL` in `fess.in.sh`) after restart.
- To verify: trace the admin Action's update method and check whether the specific field is included in the `setSystemProperty()` calls before `storeSystemProperties()`.

## I. Input Validation and Sanitization Rules

- When docs describe a configuration value format, trace the parsing code to check for:
  1. **Character sanitization**: `replaceAll()`, `matches()`, or regex filters that silently remove or reject characters (e.g., `replaceAll("[^a-zA-Z0-9_]", "")` restricting to alphanumeric and underscores)
  2. **Reserved/forbidden values**: Conditional checks that silently reject specific values (e.g., `if ("admin".equalsIgnoreCase(value))` filtering out reserved names)
  3. **Length limits**: `substring()`, `StringUtils.truncate()`, or explicit length checks
- These restrictions are frequently undocumented. If found in code but absent from docs, report as MISSING.
- Common locations: `FessProp.java` (property parsing), Helper classes (value processing), Form classes (validation annotations)

## I2. Index and Field Names

- Verify OpenSearch index names (e.g., `fess.search`, `fess_config`, `fess_log`).
- Check field names match index mapping definitions in `fess_indices/`.
- **Index prefix structure**: `fess_config`, `fess_user`, `fess_log` are not single indices but prefixes with multiple sub-indices (e.g., `fess_config.web_config`, `fess_config.scheduled_job`, `fess_user.user`, `fess_user.role`, `fess_user.group`, `fess_log.search_log`, `fess_log.click_log`). Docs listing these as single flat indices are inaccurate.
- **Search index naming**: The search document index uses `fess.{timestamp}` pattern with `Constants.DOCUMENT_INDEX_SUFFIX_PATTERN = "yyyyMMddHHmmssSSS"` (millisecond precision). New indices are created on **index rebuild** (not daily). `fess.search` and `fess.update` are aliases pointing to the current timestamped index. See `SearchEngineClient.generateNewIndexName()`.
- **Plugin vs index confusion**: `configsync` is an OpenSearch plugin (providing `/_configsync/file` etc.), not an index. Watch for docs that incorrectly list OpenSearch plugin features as indices.

## I3. Admin UI Navigation Paths

- When docs describe step-by-step admin UI workflows (e.g., "Navigate to X → Y"), verify the corresponding admin Action class exists at `repos/fess/src/main/java/org/codelibs/fess/app/web/admin/`.
  - Pattern: menu item "Feature" → check for `admin/{feature}/Admin{Feature}Action.java`
  - Example: "Crawler" → "Web" → verify `admin/webconfig/AdminWebconfigAction.java` exists
- **Features embedded in other pages**: Some features do not have a dedicated admin page but exist as fields within another page's form. Example: "Virtual Host" is not a standalone admin page — it is a field in crawl configuration forms (Web Config, File Config, Data Config). If a doc claims a dedicated page exists for such a feature, report as INCORRECT and describe the actual UI location.
- **Form field verification**: When docs say "set X in the Y field", verify the field exists in the corresponding `CreateForm.java` / `EditForm.java` class. This catches docs that reference non-existent UI fields.

## I4. Deployment and File Paths

- When docs reference deployment file paths (e.g., `app/WEB-INF/conf/system.properties`, `/etc/fess/`), verify against:
  1. `src/main/assemblies/common-bin.xml` — defines directory structure for zip/tar.gz distributions
  2. `src/packaging/rpm/packaging.properties`, `src/packaging/deb/packaging.properties` — package-specific paths (RPM uses `/etc/sysconfig/fess`, DEB uses `/etc/default/fess` for env files)
  3. `ResourceUtil.java` — runtime path resolution hierarchy: Docker (`/opt/fess`) → system property (`FESS_CONF_PATH`) → default (`WEB-INF/conf`)
- Verify that documented paths for both zip-install and RPM/DEB-install variants are accurate for their respective deployment methods.
- **Source code paths vs installed paths**: Docs must reference **installed** paths, not Maven source tree paths. Files under `src/main/resources/` are packaged into `app/WEB-INF/classes/` at build time. If a doc references `src/main/resources/...`, report as INCORRECT and fix to `app/WEB-INF/classes/...`. Common examples:
  - `src/main/resources/fess_config.properties` → `app/WEB-INF/classes/fess_config.properties`
  - `src/main/resources/fess_thumbnail.xml` → `app/WEB-INF/classes/fess_thumbnail.xml`
  - `src/main/resources/fess_indices/fess/doc.json` → `app/WEB-INF/classes/fess_indices/fess/doc.json`
  - Similarly, `src/main/webapp/WEB-INF/...` maps to `app/WEB-INF/...`
  - Phrases like 「ソースコード上では」should also be removed or rewritten, since docs describe the deployed system, not the source tree.
