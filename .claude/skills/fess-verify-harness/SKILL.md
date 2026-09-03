---
name: fess-verify-harness
description: Use when verifying Fess against a live server - SSO (SPNEGO/SAML/OIDC/EntraID), LLM and embedding plugins, MCP, data store plugins, or Playwright crawling.
---

# Fess Live-Server Verification Harnesses

Reusable harnesses that drive a **running** Fess plus its real dependencies (an AD DC, a
Keycloak realm, an LLM endpoint, an MCP client, a JS site behind a proxy). Use these instead of
rebuilding a verification environment from scratch.

## Where the code lives

`docs/harnesses/<name>/` in this workspace.

**`docs/` is gitignored** (`.gitignore:30`) and the harnesses are stored there deliberately: they
carry throwaway fixture passwords, a Kerberos keytab, SP keys, and real infrastructure paths.
**Never copy harness files into `.claude/skills/`, a commit, or a published Artifact** — this
workspace repo is public. Keep code in `docs/`, keep procedure here.

| Harness | Verifies | Entry point |
|---|---|---|
| `spnego-verify/` | SPNEGO/Kerberos + LDAP permissions against a Samba AD DC | `run-suite.sh` drives ~40 `t-*.sh` |
| `saml-verify/` | SAML SP against a Keycloak IdP | `kc_setup.py` then `t1..t7_*.py` |
| `oidc-verify/` | OIDC RP against Keycloak | `env/setup-keycloak.sh` then `tests/t_phase*.py` |
| `entraid-verify/` | EntraID against a live Azure tenant | `scripts/azure-setup-r5.sh`, `RETEST.md` |
| `llm-openai-158/`, `llm-ollama-r4/`, `llm-gemini-158/` | LLM plugin: embeddings, RAG, prompt bases, wire format | `up.sh`, `configure.sh`/`mkconf.sh`, `verify_*.py` |
| `embedding-quality/` | Embedding scoring correctness, independent of Fess | `offline_cos.py`, `minscore_test.py`, `degrade_test.py` |
| `mcp-verify/` | MCP plugin over a real MCP client | `start.sh`, `phase*.sh` |
| `playwright-crawl-test/` | Playwright crawler: JS rendering, auth, proxy | `scripts/run-all.sh` |
| `ognl-verify/` | fess-script-ognl: DI registration, expression semantics, strict-mode sandbox, config clamps, crawler field scripts | `run-all.sh` |
| `wikipedia-verify/` | fess-ds-wikipedia: DI registration, 6 dump compressions, CirrusSearch NDJSON, directory expansion, the download User-Agent, `limit` and error routing, search reachability | `run-all.sh` |
| `json-verify/` | fess-ds-json: the three document shapes and `format` auto-detection, source discovery and ordering, `root_path` pointer semantics, per-mode error tolerance, encodings, script scope and credential masking, `deleteOldDocs` | `run-all.sh` |
| `slack-verify/` | fess-ds-slack, **two lanes**. Lane A (`scripts/run-all.sh`) drives a fake Slack that *is* `slack.com`, for everything you cannot ask a real workspace for: 429/5xx, `Retry-After` in three forms, retry exhaustion, mid-crawl token death, unparseable bodies, private-channel fail-closed, and a per-call request log. Lane B (`live/scripts/run-all.sh`) points a plain Fess at the **real** `slack.com` with a bot token, and answers only the question Lane A cannot: is the wire format actually what we assumed | `scripts/run-all.sh` ／ `live/scripts/run-all.sh` |

## Reviving a harness

1. **Rebuild `FESS_HOME`.** Most harnesses point at an extracted Fess distribution that no longer
   exists. Build it with `mvn antrun:run` **before** `mvn package` — the antrun plugin has no
   `<phase>`, so the normal lifecycle never runs it, and skipping it produces a WAR that boots but
   whose crawler/thumbnail/suggest/chunk child processes all die at DI init with
   `NoClassDefFoundError: jakarta/annotation/PostConstruct`.
2. **Fix the absolute paths.** `spnego-verify/lib.sh:2-4` hardcodes `VD=`, `FH=` and `BASE=`; the
   SAML/OIDC/MCP scripts `source` sibling files by absolute path. Rewrite to `${BASH_SOURCE%/*}`.
   `playwright-crawl-test/` needs no edit — every knob is already `${VAR:-default}`.
3. **Regenerate credentials, never reuse them.** `spnego-verify/setup-ad.sh` regenerates
   `fess.keytab`; `saml-verify/kc_setup.py` regenerates the IdP descriptor and certificate;
   the LLM harnesses' `configure.sh`/`mkconf.sh` write `conf/*.properties` from `$OPENAI_API_KEY`
   / `$GEMINI_API_KEY`. The `conf/` directories were deliberately dropped when these were
   archived — regenerate them from the environment rather than restoring an old copy.

## Rules that apply to every harness

- **Give each stack its own ports and compose project name.** `playwright-crawl-test` uses
  `name: pwcrawl` with 18080/19200/18081 for exactly this reason: two sessions running the default
  compose project will otherwise tear down each other's containers mid-run.
- **Run a dedicated OpenSearch container per harness.** Sharing one lets a previous run's index
  state decide the next run's result.
- **Seed one document per permission.** Then a result set *is* the permission set, and an
  assertion cannot pass for the wrong reason.
- **Wait on a component endpoint, not `/`.** `saml-verify/restart.sh` polls `/sso/metadata`
  because with `sso.type=saml` the root path does not return 200 — waiting on `/` races the boot.
  Note also that `curl` prints `000` on connection failure and exits 7, which `set -e` treats as
  fatal; the poll loop must tolerate both.
- **Know which config channel you are writing.** `system.properties` reloads live but on an
  mtime delay of roughly 10 seconds — writing the file is not the same as the endpoint honouring
  it, so poll for the behaviour (`mcp-verify/lib.sh:36-47 wait_until_anonymous()`).
  `fess_config.properties` needs a restart. `-Dfess.system.*` cannot carry values with spaces.
- **Falsify every green.** A passing assertion is worthless until you have made it fail on purpose:
  remove the ticket file rather than running `kdestroy`, point at an undeployed model, corrupt the
  wire response. Several traps recorded in these scripts are cases where a test was green because
  it was asserting nothing — audit-log rotation emptying the window, `action:LOGIN` matching
  `action:LOGIN_FAILURE` as a prefix, `kcadm.sh` double-escaping a backslash so a truncation check
  had nothing to truncate.
- **Read the body, not the status.** The Fess admin API returns HTTP 200 on auth failure; the real
  verdict is `response.status` in the JSON body (`playwright-crawl-test/scripts/lib.sh:29-32`).

## Harness-specific notes

- **SPNEGO** — the AD DC container needs `--cap-add SYS_ADMIN`. Heimdal's `kinit` on macOS writes
  to an `API:` cache instead of the `FILE:` cache the scripts expect unless `KRB5CCNAME` is set
  explicitly.
- **SAML/OIDC** — build the realm through the Admin REST API, not `kcadm.sh`: `kcadm.sh`
  double-escapes backslashes, silently turning a group named `x\finance` into `x\\finance`.
  `oidc-verify/tests/mock_token.py` is a stand-in token endpoint — the only way to control JWT
  contents without attacking the transport.
- **EntraID** — `entraid-verify/RETEST.md` is the operational record: consent scopes, soft-deleted
  objects awaiting purge, and the rule to restore the Graph scope after testing. It names a real
  tenant, so it stays in `docs/` and never goes anywhere else.
- **LLM plugins** — `make_variant_jar.py` rewrites the plugin's DI XML in place to build canary and
  deliberately-broken variants, so a prompt-base assertion cannot pass tautologically. The
  recording/faulting reverse proxy under `proxy/` replays and corrupts provider responses without
  ever recording the `Authorization` value.
- **Embedding quality** — `offline_cos.py` reads the stored vectors straight out of OpenSearch,
  embeds the query through ML Commons `_predict` bypassing Fess entirely, and asserts Fess's score
  equals `(1 + maxcos) / 2`. That is an independent falsification of the scoring path, not a smoke
  test. `make_docs.py` builds a corpus whose answer passage sits in a late chunk with vocabulary
  disjoint from the query, so BM25 scores zero and only the vector path can succeed.
- **MCP** — `client/fess-mcp-bridge.mjs` is not replaceable. The MCP SDK's newest protocol version
  opens every session with `initialize`, which the Fess endpoint removed; the bridge speaks
  2025-06-18 to the client and 2026-07-28 to Fess. Without it no real MCP client can reach Fess.
- **OGNL** — the plugin installs to `app/WEB-INF/plugin/`, not `WEB-INF/lib/`. Fess core rewrote the
  script subsystem on 2026-08-29, so re-derive which call sites accept `ognl` from core rather than
  from notes. Two silent traps: the admin REST API maps JSON in **snake_case**, and crawler field
  templates use `field.value.` / `field.script.` — the wrong prefix parses fine and the field simply
  never appears. `FESS_DICTIONARY_PATH` is a Fess-side setting; without it Fess dies at boot with
  `IndexNotFoundException` whose real cause shows only in the OpenSearch log.
- **fess-ds-wikipedia** — a data store crawl runs in the crawler *child* process, and Fess
  catches its exceptions per config, so **a crawl that fails completely still reports the job as
  `ok`**; judge by the index count, the failure-URL rows and the `ERROR Failed to process a data
  crawling` line, never by job status. A script expression that throws is not a failure either:
  `convertValue` returns null and the key is simply left out of the document. `dump_server.py`
  records every request's User-Agent, which is the only way to prove the download header from the
  server's side, and answers `/deny/` with 403 so the green can be falsified. `mkdumps.py` must
  clear the served tree's *contents*, not the directory — unlinking a running server's working
  directory leaves it answering the port while serving nothing, which reads as "the plugin
  downloaded 0 documents".
- **fess-ds-json** — the DI XML is read in the crawler **child** process, so the evidence lands in
  `fess-crawler.log`, never `fess.log`; looking in the wrong file reads as a registration failure.
  Search results are role-filtered: documents indexed with `{role}guest` are invisible to the
  admin-API token (`{role}admin-api`), so `/api/v2/search` returns 0 while hundreds of documents
  sit in the index — assert reachability through the anonymous search screen instead, and note
  that Fess 15.9 removed the v1 JSON API entirely. Never grep the results page for the *query*
  term: the search box and page title echo it back, so the assertion passes on a zero-result page.
  Grep for the indexed document's URL. Processing order is only observable through the
  `Loading <absolute path>` INFO lines — anchor the regex on the absolute path, because Fess also
  logs `Loading specified ...` at crawler start-up.

- **fess-ds-slack, Lane B (live)** — expectations are computed by `live/scripts/facts.py`, which walks the
  Slack API itself rather than hard-coding counts, and prints **counts and opaque ids only** because its output
  is quoted into reports. Four rules learned the hard way. **Wait out a running crawl BEFORE clearing the index,
  not after** — `runcrawl.sh` waits too, but only after `reset_index` has run, and a leftover crawl finishing in
  that gap writes into the index you just emptied; because Fess's document id is `url` **plus the sorted role
  list** (`CrawlingInfoHelper#generateId`), the two sets do not collapse and you get an exact multiple of the
  expected count that reads like the plugin double-indexing. **Never assert "the token is absent" with the
  generic `assert_not_has`** — its failure message interpolates the needle, so the check prints the live token at
  exactly the moment it matters; use a variant that withholds the value. **Put the token in a `mktemp` file with a
  `trap`**, never in `curl`'s argv (`ps auxww` reads it) and never in a fixture on disk. **Re-derive the expected
  count after the crawl too** — a real workspace changes under you, and the mismatch reads as a plugin defect.
- **fess-ds-slack** — the API base URL is a compile-time constant (`Request.java`) whose only
  override is a static setter for the unit tests, and the crawl runs in the crawler *child*
  process, so nothing the webapp JVM sets can reach it. The stub therefore *is* `slack.com`:
  compose network aliases `slack.com`/`files.slack.com` plus a throwaway CA baked into the Fess
  image's JDK truststore. Four traps, each of which produces a green test that checked nothing:
  the image logs to **stdout as ECS JSON** and `logs/*.log` stay empty; `docker logs` could not be
  read back reliably (`--since` with a UTC stamp two minutes old returned nothing, and after a
  daemon restart a full read returns only the pre-restart segment while `--tail 1` returns the
  current one) so the harness runs a `docker logs -f --tail 0` follower instead; a crawl invoked
  through `$( )` is a subshell, so the log-window marker has to live in a file; and the admin JSON
  API rejects a session cookie (HTTP 200, `response.status` 3) and needs a token whose permission
  is `{role}admin-api`, not `{role}admin`. Judge a crawl by index count + `failure_url` +
  the crawler-log ERROR line: **the scheduler job reports `ok` even when the crawl aborts**.

- **Playwright crawling** — `USE_LATEST_JAR=auto` compares the published snapshot jar against the
  jar inside the container image by SHA-256 and only layers the overlay compose file on mismatch;
  without that check you can spend a whole round verifying the image's stale jar. One nginx serves
  identical content under six network aliases so a single crawl produces every control and
  experiment arm as distinct URLs.
