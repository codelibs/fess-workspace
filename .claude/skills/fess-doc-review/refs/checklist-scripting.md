# Checklist: Scripting and Scheduled Jobs

Detailed verification rules for script execution context, scheduled job names, and Groovy syntax.

## K2. Script Execution Context and Available Objects

- When docs list "available objects" or "built-in variables" for scripting, verify that each object is actually injected in the claimed context. Script binding objects vary by execution context:
  - **All contexts**: `container` (DI container) — injected by `GroovyEngine.evaluate()` via `bindingMap.put("container", SingletonLaContainerFactory.getContainer())`
  - **Scheduled jobs**: `executor` (`JobExecutor` instance) — injected by `ScriptExecutor.execute()` via `params.put("executor", this)`. Enables job shutdown support.
  - **Data store scripts**: connector-specific data record (key prefix varies by connector — see `checklist-datastore.md` J3 for details), plus custom params from `DataStoreParams` — injected by the data store's `storeData()` implementation
  - **Boost matching**: document field map — injected by `DocBoostMatcher.matches()`/`getValue()`
  - **Path mapping**: URL and related params — injected by `PathMappingHelper`
- To verify: trace each `ScriptEngine.evaluate(template, paramMap)` call site and check what keys are added to `paramMap` before the call. Each call site may inject different objects.
- Common doc error: listing an object (e.g., `executor`) as universally available when it is only injected in one specific context (scheduled jobs). Or omitting context-specific objects entirely.
- **Missing binding object documentation**: When a doc provides a scripting guide or tutorial (e.g., Groovy scripting guide), verify it documents which objects are available in each execution context. A guide that only mentions `container` without explaining `executor` (for scheduled jobs) or connector-specific variables (for data stores) is incomplete. Check for a table or section that maps contexts to available objects.

## K2b. Scheduler Scripts vs Crawler Config Scripts

- Fess has two distinct "script" concepts that docs frequently confuse:
  1. **Scheduler job scripts** — Groovy scripts in the Scheduler admin page (「システム」→「スケジューラー」). These call job class methods like `container.getComponent("crawlJob").logLevel("info").webConfigIds(...)...`. Methods like `logLevel()`, `webConfigIds()`, `fileConfigIds()`, `dataConfigIds()`, `jobExecutor()` are on `ExecJob` subclasses (`CrawlJob`, `SuggestJob`, `GenerateThumbnailJob`).
  2. **Crawler config scripts** — Field-level scripts in crawl configuration pages (Web/File/Data Config). These handle path mapping, data transformation, and field value computation during crawling.
- When docs describe changing job behavior (log level, target config IDs, execution parameters), the correct location is the **scheduler job script**, NOT the crawler config script.
- Common error: docs say "open crawler config → Script tab → add `logLevel("DEBUG")`" when `logLevel()` is a `CrawlJob` method only callable from the scheduler script.
- To verify: check if the method exists on the job class (`ExecJob` and subclasses) vs on crawler/transformer classes.

## K3. Scheduled Job Names and Scripts

- When docs reference a scheduled job by name (e.g., "Index Export Job"), verify the exact `name` field in `fess_indices/fess_config.scheduled_job/scheduled_job.bulk`. Job names displayed in the Scheduler UI come from this bulk data, not from class names.
- **Groovy script examples must match Java API**: Docs often include Groovy script examples for customizing scheduled jobs. Verify these scripts against the actual Java class API:
  1. Check that method names exist on the job class (e.g., `query()` vs `setQuery()`)
  2. Verify parameter types match — a method taking `QueryBuilder` cannot accept a plain `String`
  3. Confirm the method-chaining pattern matches (builder pattern with `return this` vs setter-style `void` methods)
  4. Compare doc examples against the default script in `scheduled_job.bulk` for style consistency
- Common error pattern: docs show `job.property = "value"` (Groovy property access) when the class has no public field or setter, only a builder-style method like `property(Type value)` returning `this`.

## K4. Script Syntax Language Verification

- The default script engine is Groovy (`Constants.DEFAULT_SCRIPT = "groovy"`). Doc script examples must use valid Groovy syntax, not JavaScript.
- Common JavaScript-to-Groovy errors found in docs:
  - `array.map(function(x) { return x.name; })` → Groovy: `array.collect { it.name }`
  - `value || "default"` (JS returns first truthy) → Groovy: `value ?: "default"` (Elvis operator)
  - `parseFloat(str)` / `parseInt(str)` → Groovy: `str as Float` / `str as Integer` (or `Float.parseFloat(str)` / `Integer.parseInt(str)`)
  - `# comment` → Groovy: `// comment` (hash comments are not valid Groovy; use `//` for line comments or `/* */` for block comments)
  - Multi-line if-blocks setting multiple fields → In datastore scripts, each field is an independent expression evaluated by `convertValue()`. Use per-field ternary operators: `url=condition ? value : null`
- This is especially common in datastore connector docs where script examples show advanced usage patterns. Verify all script code blocks against Groovy syntax rules.
- **Datastore scripts are per-field single expressions**: In datastore script configuration, each line (e.g., `url=file.url`) is evaluated independently by `convertValue()` in `AbstractDataStore`. This means multi-line control structures like `if (...) { url=...; title=...; }` are **invalid** — each field must be a self-contained expression. The correct pattern for conditional values is a ternary per field: `url=condition ? file.url : null`. If docs show multi-line if-blocks wrapping multiple field assignments in datastore scripts, report as INCORRECT and suggest either per-field ternary expressions or the appropriate parameter-based filtering (e.g., `supported_mimetypes` for MIME type filtering).
- **`import` and `def` in datastore scripts**: `import` statements and multi-line `def` variable declarations are also invalid in per-field datastore scripts for the same reason — each line is an independent `field=expression` mapping. Lines like `import java.text.SimpleDateFormat` or `def sdf = ...` would be parsed as separate (malformed) mappings, not as a preamble to the next field expression. The fix is to inline everything using FQCN: `lastModified=new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").parse(data.date_string)`. Note: `import` and `def` are valid in **scheduled job scripts**, which are evaluated as full Groovy scripts — this restriction only applies to datastore field mappings.
