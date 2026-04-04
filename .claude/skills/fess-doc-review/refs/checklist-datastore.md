# Checklist: Datastore Connectors

Detailed verification rules for data format claims, completeness, handler names, parameters, and script fields.

## H2. Data Format and Processing Behavior Claims

- When docs describe what input formats a connector supports (e.g., "reads JSON array files and JSONL files"), verify by reading the actual parsing implementation.
- **Line-by-line vs stream parsing**: Check whether the code reads input line-by-line (`BufferedReader.readLine()` + per-line parse) or uses a streaming parser (e.g., Jackson `JsonParser` with token iteration). Line-by-line readers cannot process multi-line formats like pretty-printed JSON arrays. Example: `JsonDataStore` uses `br.readLine()` + `objectMapper.readValue(line, Map.class)`, so it only supports JSONL (one JSON object per line), not JSON arrays (`[{...}, {...}]`).
- **Type expectations in parsing**: Check `readValue()` target types. `readValue(line, Map.class)` expects a JSON object on each line; a JSON array (`[...]`) would throw `JsonParseException`. Docs claiming array support when the parser expects objects are INCORRECT.
- **Silent failure vs hard failure**: Some parsers wrap individual line parsing in try-catch (continuing on error), while others fail on the first bad line. Check error handling to accurately describe behavior in troubleshooting sections.

## H5. "Common Parameter" Scope Verification

- When docs present parameters in a "共通パラメーター" (common parameters) table, verify that **every listed parameter actually exists in all connector classes** covered by that table. Grep each parameter name across all DataStore classes in the plugin.
- Common pattern: a parameter like `include_pattern` or `default_permissions` exists in most but not all connectors (e.g., present in OneDrive/SharePoint but absent from OneNote/Teams). Listing it as "common" is INCORRECT — move it to the per-connector additional parameters sections.
- To verify: for each parameter in the common table, grep `PARAM = "{param_name}"` across all DataStore classes in the plugin. If any class lacks the constant, the parameter is not truly common.

## J. Duplicate or Missing Entries

- Check for duplicate rows in RST `list-table` directives.
- **Duplicate content blocks**: Check for repeated code blocks or configuration sections within the same RST file. A common pattern is a section (e.g., "最小構成") that shows the same file path and content block twice due to copy-paste errors during doc authoring.
- Check for properties defined in source but missing from doc tables.
- **Properties in code examples but not in formal tables**: Also check for properties that appear only in code examples or troubleshooting sections within the doc without a corresponding formal `list-table` entry. These are easy to miss and should be added to the appropriate table.
- **Crawler client `client.` prefix convention**: In Fess's crawl configuration UI "設定パラメーター" field, parameters use a `client.` prefix (e.g., `client.endpoint`, `client.accessKey`). This prefix is stripped when passed to the crawler client's `getInitParameter()`. Docs should use the `client.` prefixed form since that is what users enter in the UI.
- **UI label files as property completeness cross-reference**: `fess_label_*.properties` contains labels for every configurable property exposed in the admin UI (e.g., `labels.entraid_permission_fields`, `labels.entraid_use_ds`). Grep the label file for the feature prefix (e.g., `labels.entraid_`) and compare the set of properties found against the doc's `list-table` entries. Any label present in the properties file but absent from the doc table is a candidate for a MISSING finding. This technique catches properties defined in `FessProp.java` or other secondary sources that are not in the primary authenticator/helper class.

## J1. Empty or Placeholder Sections

- Check for sections that appear complete (have a heading, description text, and code block) but contain **identical content to another section** in the same file. This is a common copy-paste error where a usage example was duplicated but never customized.
- **Detection pattern**: Compare code blocks across "使用例" (usage example) sections. If two sections have different headings but identical `::` code blocks (especially script blocks), the later one is likely a placeholder that was never filled in.
- Also check that the descriptive text before a code block actually matches what the code block demonstrates. A heading like "特定のフォルダのみをクロール" followed by a script with no filtering logic is a placeholder.

## J2. Plugin Handler Name and Parameter Completeness (Datastore / LLM / etc.)

- **Handler name verification**: Each plugin registers handlers in `fess_ds++.xml` (or `fess_llm++.xml`, etc.) as `<component>` entries. The handler name displayed in admin UI is the class's `getSimpleName()` (inherited from `AbstractDataStore.getName()`). Verify every handler name in the doc against the XML registration and class name.
- **Multiple handlers per plugin**: A single plugin may register multiple DataStore implementations (e.g., `fess-ds-elasticsearch` registers both `ElasticsearchDataStore` and `ElasticsearchListDataStore`; `fess-ds-dropbox` registers `DropboxDataStore` and `DropboxPaperDataStore`). Compare all `<component>` entries in the XML against the doc's handler name list to catch missing handlers.
- **Parameter completeness via `*_PARAM` constants**: Grep each DataStore class for `PARAM = "` to enumerate all accepted parameter names. Compare these against the doc's parameter table. Parameters present in code but absent from the doc should be reported as MISSING. Note that some advanced parameters (e.g., `skip_lines`, `ignore_empty_lines` in CSV) are commonly omitted from docs despite being valid.
- **Parameter naming style inconsistency across plugins**: Fess plugins do NOT follow a single naming convention. Example: `fess-ds-csv` uses `file_encoding` (snake_case) while `fess-ds-json` uses `fileEncoding` (camelCase). Always verify the exact string value of the `*_PARAM` constant — do not assume the naming style from one plugin applies to another. If a doc uses the wrong style (e.g., `file_encoding` for JSON), report as INCORRECT.
- **Parameter interaction, precedence, and error behavior**: When a connector accepts mutually exclusive or alternative parameters (e.g., `files` vs `directories`), verify that docs describe: (1) which parameter takes precedence if both are specified (trace the `if/else` or early-return logic in `getFileList()` or equivalent), (2) what error occurs if neither is specified (e.g., `DataStoreException`), and (3) whether the non-preferred parameter is silently ignored or causes a warning. Example: `JsonDataStore` checks `files` first; only if blank, checks `directories`. If both are blank, throws `DataStoreException`. This precedence/error behavior is commonly undocumented.
- **Parameters in usage examples and code blocks**: Parameter verification must not be limited to formal `list-table` entries. Also check parameters that appear in `::` code blocks within usage examples, troubleshooting sections, and permission configuration sections. A common error is documenting a fabricated parameter (e.g., `default_permissions`) in a usage example that does not exist in any `*_PARAM` constant or in the `AbstractDataStore` base class. Grep the parameter name across both the plugin source and `repos/fess/src/main/java/org/codelibs/fess/ds/` to confirm existence.
- **Authentication method verification**: When docs list supported authentication methods (e.g., "JWT or OAuth 2.0"), verify each claimed method against the actual implementation. Check how the API connection is created (e.g., `BoxDeveloperEditionAPIConnection.getAppEnterpriseConnection()` = JWT only, not OAuth). Docs claiming authentication methods not implemented in code should be reported as INCORRECT.
- **OAuth/API scope verification**: For cloud service connectors (G Suite, Microsoft 365, Box, etc.), verify that the OAuth scope documented for admin console/delegation setup **exactly matches** the scope the code actually requests in the JWT/OAuth flow. Grep the client class for `scope`, `withClaim("scope"`, or `SCOPES` to find the actual requested scope. A common error is docs recommending a more restrictive scope (e.g., `drive.readonly`) than what the code requests (e.g., `drive`), which causes authentication failures because the token request includes an unauthorized scope. If the documented scope differs from the code's requested scope, report as INCORRECT.
- **Base class inherited parameters**: In addition to plugin-specific `*_PARAM` constants, check for common parameters inherited from `AbstractDataStore` (e.g., `readInterval` — delay in milliseconds between processing each record). These base class parameters apply to all connectors but are frequently omitted from per-connector documentation. Grep `AbstractDataStore.java` for `paramMap.getAsString(` or `paramMap.containsKey(` to enumerate inherited parameters.
- **Plugin client/helper class parameters**: Many plugins have a shared client class (e.g., `Microsoft365Client.java`, `BoxClient.java`) that handles authentication and API communication. These classes often define additional parameters (`proxy_host`, `proxy_port`, `proxy_username`, `proxy_password`, `cache_size`, `max_content_length`, etc.) that are common to all connectors in the plugin but are NOT defined in the DataStore classes themselves. Always grep `*Client.java` and other helper classes in the plugin for `PARAM`, `getAsString(`, or constant declarations to find these parameters. Report as MISSING if they are absent from the doc.
- **Unused/dead constants**: Before documenting a parameter found as a constant, verify it is actually consumed by a `getAsString()`, `paramMap.get()`, or similar call. Constants defined but never referenced in any parameter-reading code are dead code and should NOT be added to documentation. Grep for the constant name (not the string value) to check for usage beyond the declaration line.
- **`*ListDataStore` variant check**: Many plugins register a `*ListDataStore` variant alongside the primary handler (e.g., `CsvListDataStore`, `ElasticsearchListDataStore`). These variants typically extend the base DataStore with: multi-threaded processing (`num_of_threads`), automatic file deletion after processing, and timestamp-based file filtering (`timestamp_margin`, default 10000ms). Always check `fess_ds++.xml` for `*ListDataStore` components and verify they are documented.
- **Overview doc vs repository completeness**: When reviewing overview/index documents (e.g., `ds-overview.rst`), list all `repos/fess-ds-*` directories and compare against the connectors documented. Undocumented repositories (excluding `fess-ds-example`) should be reported as MISSING. Note that some functionality may overlap (e.g., `fess-ds-sharepoint` is a legacy connector while `fess-ds-microsoft365` covers SharePoint via Graph API).

## J3. Datastore Script Field Verification

- Each DataStore connector puts data into `resultMap` with connector-specific key prefixes. These prefixes vary by connector type:
  - CSV: `data.*` (header column names or `cell1`, `cell2`, ...) plus `csvfile`, `csvfilename`
  - Database: `data.*` (SQL column labels)
  - JSON: `data.*` (JSON field names)
  - Box/Dropbox/Google Drive/OneDrive: `file.*`
  - Dropbox Paper: `paper.*`
  - Slack: `message.*`
  - Jira: `issue.*`
  - Confluence: `content.*`
  - Teams: `message.*`
  - Salesforce: `object.*`
  - Elasticsearch: `source.*` (from `_source`), plus `id`, `index`, `score`
  - Git: direct field names (`url`, `path`, `name`, `content`, `contentLength`, `timestamp`, `mimetype`, `author`)
  - OneNote: `notebook.*`
  - SharePoint DocLib: `doclib.*`
  - SharePoint List: `item.*`
  - SharePoint Page: `page.*`
- Verify that script examples in docs use the correct prefix by checking the `storeData()` implementation for the keys put into `resultMap` or `dataMap`.
- Some connectors also expose metadata fields (e.g., `csvfile`/`csvfilename` in CSV) that are useful but easily overlooked in documentation.
