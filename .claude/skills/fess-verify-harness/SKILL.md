---
name: fess-verify-harness
description: Builds and runs live-server verification harnesses that drive a running Fess and its real dependencies. Use when verifying Fess against a live server - SSO (SPNEGO/SAML/OIDC/EntraID), LLM and embedding plugins, MCP, data store plugins, or Playwright crawling.
---

# Fess Live-Server Verification Harnesses

A harness drives a **running** Fess plus its real dependencies (an AD DC, a Keycloak realm, an LLM
endpoint, an MCP client, a JS site behind a proxy) and asserts on observable behaviour. This skill is
the procedure and the traps; the harness code is yours to write per task.

## Where harness code lives

Keep harness code, fixtures and results in a gitignored directory of this workspace (`work/` or
`docs/`, see `.gitignore`), never under `.claude/`, in a commit, or in a published Artifact — this
workspace repository is public. Harnesses carry throwaway passwords, keytabs, SP keys, API keys and
tenant identifiers. Write every script against `${BASH_SOURCE%/*}` and `${VAR:-default}` knobs, not
absolute paths, so it can be revived from a different directory.

## Setting up

1. **Build the Fess under test.** Run `mvn antrun:run` **before** `mvn package` — the antrun plugin has
   no `<phase>`, so the normal lifecycle never runs it, and skipping it produces a WAR that boots but
   whose crawler/thumbnail/suggest/chunk child processes all die at DI init with
   `NoClassDefFoundError: jakarta/annotation/PostConstruct`.
2. **Build plugins against the same Fess minor version** they are installed into (see `CLAUDE.md`).
3. **Generate credentials for each run, never reuse them.** Keytabs, IdP descriptors, certificates and
   `conf/*.properties` holding API keys are produced by setup scripts from environment variables
   (`$OPENAI_API_KEY`, `$GEMINI_API_KEY`, ...), not restored from an old copy.

## Rules that apply to every harness

- **Give each stack its own ports and compose project name.** Two sessions running the default compose
  project tear down each other's containers mid-run.
- **Run a dedicated OpenSearch container per harness.** Sharing one lets a previous run's index state
  decide the next run's result.
- **Seed one document per permission.** Then a result set *is* the permission set, and an assertion
  cannot pass for the wrong reason.
- **Wait on a component endpoint, not `/`.** With `sso.type=saml` the root path does not return 200, so
  poll something like `/sso/metadata`. `curl` prints `000` on connection failure and exits 7, which
  `set -e` treats as fatal; the poll loop must tolerate both.
- **Know which config channel you are writing.** `system.properties` is a `DynamicProperties` that
  reloads lazily on an mtime check — writing the file is not the same as Fess honouring it, so poll for
  the behaviour, and send one uncharged request before a parallel burst (requests concurrent with the
  reloading thread still see the old values). `fess_config.properties` needs a restart.
  `-Dfess.system.*` cannot carry values with spaces. Suites that rewrite `system.properties` must run
  one after another, never in parallel.
- **Read the body, not the status.** The admin API returns HTTP 200 on auth failure; the verdict is
  `response.status` in the JSON body. The admin JSON API maps fields in **snake_case**, rejects a
  session cookie, and needs a token whose permission is `{role}admin-api`, not `{role}admin`.
- **Judge a crawl by the index, not the job.** Data store and crawler failures are caught per config in
  the crawler *child* process, so a crawl that fails completely still reports the scheduler job as `ok`.
  Use the index count, the failure-URL rows and the ERROR line in `fess-crawler.log` (not `fess.log`).
- **Falsify every green.** A passing assertion is worthless until you have made it fail on purpose:
  remove the ticket file rather than running `kdestroy`, point at an undeployed model, corrupt the wire
  response. Typical vacuous greens: log rotation emptying the assertion window, `action:LOGIN` matching
  `action:LOGIN_FAILURE` as a prefix, grepping a results page for the query term (the search box and
  title echo it back — grep for the indexed document's URL instead).
- **Keep secrets out of output.** Pass tokens through a `mktemp` file removed by a `trap`, never in
  `curl`'s argv (`ps` shows it); never write an assertion helper whose failure message prints the needle
  when the needle is a secret; report counts and opaque ids only.

## Area-specific notes

- **SPNEGO** — a Samba AD DC container needs `--cap-add SYS_ADMIN`. Heimdal's `kinit` on macOS writes to
  an `API:` cache instead of a `FILE:` cache unless `KRB5CCNAME` is set explicitly.
- **SAML/OIDC** — build the Keycloak realm through the Admin REST API, not `kcadm.sh`: `kcadm.sh`
  double-escapes backslashes, silently turning a group named `x\finance` into `x\\finance`. To control
  JWT contents without attacking the transport, stand up a mock token endpoint.
- **EntraID** — record consent scopes you grant and restore them after testing; deleted objects stay
  soft-deleted until purged. Tenant identifiers never leave the gitignored harness directory.
- **LLM plugins** — to keep a prompt-base assertion from passing tautologically, build canary and
  deliberately broken plugin variants by rewriting the plugin's DI XML. A recording/faulting reverse
  proxy can replay and corrupt provider responses; it must never record the `Authorization` value.
- **Embedding quality** — falsify the scoring path independently of Fess: read the stored vectors from
  OpenSearch, embed the query through ML Commons `_predict`, and assert Fess's score equals
  `(1 + maxcos) / 2`. Put the answer in a late chunk with vocabulary disjoint from the query, so BM25
  scores zero and only the vector path can succeed.
- **MCP** — the plugin serves both protocol eras: 2026-07-28 clients (Claude Code with
  `{"type": "http", "url": ...}`, the Python SDK 2.x, the TypeScript SDK v2 with `versionNegotiation`
  `auto` or a pin) and legacy 2025-11-25 clients that open with `initialize` (TypeScript SDK v1, Python
  SDK 1.x, the TS SDK v2 default `legacy` mode, `mcp-remote`, OpenCode, Codex CLI). Cover both paths.
  Drive agent CLIs from pinned installs with isolated homes (`HOME`, `XDG_*`, `CODEX_HOME`), never the
  user's own config, and make each one actually call a tool: `gemini mcp list` reports "Connected" from
  `initialize` alone (run `gemini -p hi --debug` to see discovery). To tell a client-side header bug
  from a server one, route through a reverse proxy that adds the missing `MCP-Protocol-Version`. Wait
  for the Default Crawler job to finish before starting the suggest indexer — the document count reaches
  its target first, and an index built in that window silently lacks terms — and wait on core's own
  `/api/v2/suggest-words`, never on the MCP tool under test. Take conformance expectations from the
  specification text, so a FAIL is a discrepancy to triage, not automatically a regression.
- **Script engines (OGNL etc.)** — script plugins install to `app/WEB-INF/plugin/`, not `WEB-INF/lib/`.
  Derive which call sites accept a given engine from core's source, not from notes. Crawler field
  templates use `field.value.` / `field.script.`; the wrong prefix parses fine and the field simply never
  appears. A script expression that throws does not fail the crawl — the key is left out of the document.
- **Data store plugins** — the plugin's DI XML is read in the crawler child process, so registration
  evidence lands in `fess-crawler.log`. Documents indexed with `{role}guest` are invisible to an
  admin-API token, so `/api/v2/search` can return 0 while the index holds hundreds; assert reachability
  as the intended user. A test server that serves dumps must clear its served tree's *contents*, not
  delete the directory — a server whose working directory was unlinked keeps answering while serving
  nothing. Have it log each request's User-Agent to prove download headers server-side.
- **Data store plugins with a hard-coded API host** (e.g. fess-ds-slack) — when the base URL is a
  compile-time constant and the crawl runs in the child process, the stub has to *be* the host: compose
  network aliases for the real hostnames plus a throwaway CA in the Fess image's JDK truststore. The
  Docker image logs to stdout as ECS JSON (`logs/*.log` stay empty), and `docker logs --since` is
  unreliable across daemon restarts, so run a `docker logs -f --tail 0` follower. A step run through
  `$( )` is a subshell, so a log-window marker must live in a file.
- **Live SaaS lanes** — compute expectations by walking the real API rather than hard-coding counts, and
  re-derive them after the crawl, because a real workspace changes under you. Wait out any running crawl
  **before** clearing the index: a leftover crawl writing into the emptied index doubles the count,
  because the document id is `url` plus the sorted role list (`CrawlingInfoHelper#generateId`).
- **Playwright crawling** — confirm the plugin jar under test is the one the container loads (compare
  SHA-256 against the published snapshot) before trusting a round. Serving identical content under
  several network aliases lets one crawl produce every control and experiment arm as distinct URLs.
