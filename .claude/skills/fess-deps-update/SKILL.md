---
name: fess-deps-update
description: Use when updating dependency versions in fess-parent/pom.xml.
---

# Fess Dependency Update Skill

This skill updates library and plugin versions in `repos/fess-parent/pom.xml` while respecting compatibility constraints with OpenSearch and Tika.

## Prerequisites

- Maven 3.8+, Java 21+
- Internet access to query Maven Central
- All repos cloned (`./scripts/clone.sh all`)

## Compatibility Constraints

### OpenSearch Constraint

Fess embeds OpenSearch. Libraries that OpenSearch depends on **must match OpenSearch's versions** unless Fess has an established history of using a newer version.

**Check OpenSearch's dependency versions:**

OpenSearch's published POMs list versions on the `<dependency>` elements themselves, not
in `<properties>` — so grepping for `*.version>` finds nothing. Extract the dependency
list instead. Three separate POMs matter, because no single one carries every constraint:

```bash
# Find OpenSearch version from pom.xml
grep 'opensearch.version' repos/fess-parent/pom.xml

OS=<VERSION>
# 1. core: jackson, lucene, log4j
python3 -c "
import re,sys
s=open(sys.argv[1]).read()
for m in re.finditer(r'<dependency>(.*?)</dependency>', s, re.S):
    b=m.group(1)
    f=lambda t: (re.search(f'<{t}>(.*?)</{t}>', b) or [None,'?'])[1]
    print(f'{f(\"groupId\")}:{f(\"artifactId\")} = {f(\"version\")}')
" ~/.m2/repository/org/opensearch/opensearch/$OS/opensearch-$OS.pom

# 2. asm lives in lang-painless, NOT in the core POM
grep -A3 'ow2' ~/.m2/repository/org/opensearch/plugin/lang-painless/$OS/lang-painless-$OS.pom

# 3. httpclient5 lives in opensearch-rest-client, NOT in the core POM
grep -A3 'httpclient5\|httpcore5' \
  ~/.m2/repository/org/opensearch/client/opensearch-rest-client/$OS/opensearch-rest-client-$OS.pom
```

**Must match OpenSearch exactly:**

| Library | Where OpenSearch declares it |
|---------|------------------------------|
| jackson (core, databind, annotations) | `org.opensearch:opensearch` |
| lucene | `org.opensearch:opensearch` |
| log4j | `org.opensearch:opensearch` |
| asm | `org.opensearch.plugin:lang-painless` |
| httpclient5 | `org.opensearch.client:opensearch-rest-client` |
| httpcomponents (httpclient 4.x, httpcore 4.x) | transitive; cross-check against Tika |

Note that `asm` has historically been *behind* OpenSearch in this POM rather than ahead —
check the direction before assuming a constrained library needs no change.

**Fess uses newer than OpenSearch (acceptable, do not downgrade):**
- icu4j, guava, commons-codec, commons-io, commons-lang3

### Tika Constraint

Tika bundles specific versions of document processing libraries. Using mismatched versions can cause runtime errors.

**Check Tika's dependency versions:**

```bash
cat ~/.m2/repository/org/apache/tika/tika-parent/<VERSION>/tika-parent-<VERSION>.pom | grep -E '(poi|pdfbox|bouncycastle|commons).*version'
```

**Must match Tika's versions:**
- Apache POI (`poi.version`)
- Other libraries where Tika relies on internal APIs

**Fess uses newer than Tika (acceptable if patch-level difference):**
- PDFBox (patch version differences are OK)
- Bouncy Castle
- commons-codec, commons-io, commons-lang3

#### Tika mime-types resource (required companion change)

`fess-crawler` ships a **fork** of Tika's mime-type registry at
`repos/fess-crawler/fess-crawler/src/main/resources/org/codelibs/fess/crawler/mime/tika-mimetypes.xml`
(loaded via `MimeTypeHelperImpl.MIME_TYPES_RESOURCE_NAME`). Whenever `tika.version`
changes, this file may need to be re-synced against the new Tika release.

**Never overwrite it wholesale with the upstream file.** It carries Fess-specific
additions that a straight copy silently deletes — and because nothing compiles against
this resource, the build and the tests stay green while MIME detection regresses.

Fess-specific deltas against upstream (marked with `<!-- FESS added -->`, except #4):

1. `application/x-js-taro` (Ichitaro) type — 11 globs (`*.jtd` `*.jtt` `*.jtdc` `*.jttc`
   `*.jfw` `*.jvw` `*.jsw` `*.jaw` `*.jtw` `*.jbw` `*.juw`), magic `DOC\x00` at offset 0
2. `*.lha` / `*.lzh` globs added to the LHA type
3. `*.mm` / `*.dicon` globs added to `application/xml`
4. Upstream's `text/markdown` block replaced by `text/x-web-markdown`
   (drops the `text/markdown` and `text/x-markdown` aliases)

**Decide per bump whether a sync is even needed** — the upstream file does not change in
every Tika release. Compare the entry digests directly:

```bash
for V in <OLD> <NEW>; do
  J=~/.m2/repository/org/apache/tika/tika-core/$V/tika-core-$V.jar
  [ -f "$J" ] || { mkdir -p $(dirname $J); curl -sSf -o "$J" \
    https://repo1.maven.org/maven2/org/apache/tika/tika-core/$V/tika-core-$V.jar; }
  echo "$V  jar=$(shasum -a256 "$J" | cut -c1-12)  mimetypes=$(unzip -p "$J" \
    org/apache/tika/mime/tika-mimetypes.xml | shasum -a256 | cut -c1-12)"
done
```

Print the **jar** digest alongside the entry digest. If a download silently failed, both
extractions come back empty and `diff` reports a false "identical". The jars must differ
while the entries may match.

If the entries differ, sync by extracting the new upstream file and re-applying the four
deltas above, then diff the result against the old copy to confirm only the intended
upstream changes came in. If they match, state that no companion change is required.

Observed digests (2026-08): 3.2.3 `e3f15ef4`, 3.3.0 `f3d9d395`, 3.3.1 `b213c351`,
3.3.2 `b213c351` — i.e. 3.3.1 -> 3.3.2 needed no sync, but the two bumps before it did.

### Jakarta Mail Constraint

The `jakarta.mail.version` property is consumed by `org.eclipse.angus:jakarta.mail` only
(in `fess-crawler`) — not by `angus-mail`, and not by `com.sun.mail`, which appears in
`fess/pom.xml` solely inside `<exclusion>` blocks. Re-verify the consuming coordinates
before updating: `com.sun.mail:jakarta.mail` was only published up to 2.0.2 on Maven
Central, and later versions live under the `org.eclipse.angus` groupId.

### SLF4J Constraint

SLF4J 1.x to 2.x is a major upgrade requiring `log4j-slf4j-impl` to `log4j-slf4j2-impl` bridge changes across multiple repositories. This should be done in a dedicated PR, not as part of routine updates.

## Workflow

### Step 1: Identify Current Versions

Read `repos/fess-parent/pom.xml` and list all version properties in the `<properties>` section.

`fess-parent` has **no `<dependencyManagement>`** — it is a property holder only. The
actual `<dependency>` elements live in the consuming repos, so the property-to-artifact
mapping has to be recovered by scanning them:

```bash
python3 - <<'PY'
import re,os,glob,collections
props=dict(re.findall(r'<([\w.\-]+\.version)>([^<$]*)</\1>',
                      open('repos/fess-parent/pom.xml').read()))
mapping=collections.defaultdict(set)
for r in os.listdir('repos'):
    for p in glob.glob(f'repos/{r}/pom.xml')+glob.glob(f'repos/{r}/*/pom.xml'):
        s=open(p, encoding='utf-8', errors='replace').read()
        for m in re.finditer(r'<dependency>(.*?)</dependency>', s, re.S):
            b=m.group(1)
            g=re.search(r'<groupId>(.*?)</groupId>',b)
            a=re.search(r'<artifactId>(.*?)</artifactId>',b)
            v=re.search(r'<version>\$\{([\w.\-]+)\}</version>',b)
            if g and a and v and v.group(1) in props:
                mapping[v.group(1)].add(f"{g.group(1).strip()}:{a.group(1).strip()}")
for k in sorted(props):
    print(f"{k} = {props[k]}")
    for a in sorted(mapping.get(k,[])) or ["  (no consumer found)"]: print("     ",a)
PY
```

A property with **no consumer** is either dead or hardcoded somewhere — investigate
before bumping it (see Common Pitfalls #5).

### Step 2: Categorize Libraries

Classify each library into one of these categories:

| Category | Action |
|----------|--------|
| OpenSearch-constrained | Check OpenSearch POM, do not update beyond OpenSearch's version |
| Tika-constrained | Check Tika parent POM, match Tika's version |
| CodeLibs-managed | Do not update (managed in separate repos: dbflute, lastaflute, lasta.di, etc.) |
| CodeLibs custom repo | Do not update (jcifs, java-saml, nekohtml, corelib, curl4j) |
| Freely updatable | Check Maven Central for latest stable version |

### Step 3: Check Latest Versions on Maven Central

Query `maven-metadata.xml`, which is authoritative and current:

```bash
curl -s https://repo1.maven.org/maven2/<GROUP/AS/PATH>/<ARTIFACT>/maven-metadata.xml \
  | grep -o '<version>[^<]*' | sed 's/<version>//'
```

**Do not use `https://search.maven.org/solrsearch/select`.** Its index is stale and
returns versions *older than what the POM already carries* — measured 2026-08, it
reported guava 33.4.8-jre (POM had 33.6.0-jre), OpenSearch 3.7.0 (actual 3.8.0),
icu4j 77.1 (POM had 78.3), and tomcat 10.1.55 while ignoring the 11.x line. Trusting it
produces false "already latest" verdicts and downgrade proposals. Its `latestVersion`
field and `core=gav` ordering are equally unreliable.

Collect every `<version>`, filter pre-releases, then **sort by numeric segments yourself**
and take the maximum. Do not trust the `<latest>` tag inside the metadata either — it can
name a SNAPSHOT or milestone.

**Important:** Only consider stable releases. Skip `-alpha`, `-beta`, `-RC`,
`-M<n>` (milestone), and `-SNAPSHOT` versions.

Filtering caveats:
- Classifier-style suffixes are not pre-releases: keep `-jre`, drop `-android` for guava.
- An over-broad `-m\d` rule eats legitimate values — `commons-fileupload2` currently has
  *only* milestones published (`2.0.0-M5` is the newest), so filtering everything out
  leaves an empty list, not "no update".
- Some artifacts are not on Central at all (`jp.gr.java_conf.dangan:jlha`) and return 404.
  Treat a fetch error as unknown, never as "already latest".

### Step 4: Check Constraint Compatibility

For libraries in constrained categories:

1. **OpenSearch**: Read all three POMs (core, `lang-painless`, `opensearch-rest-client`)
   to verify version alignment
2. **Tika**: Read Tika parent's POM to verify POI and other versions, and check whether
   `tika-mimetypes.xml` needs the companion sync described above
3. **SLF4J**: Skip unless doing a dedicated migration PR

### Step 5: Plan Updates

Create a table of planned updates organized by:

1. **Safe updates** (minor/patch, no constraints) - apply these
2. **Constraint-verified updates** (checked against OpenSearch/Tika) - apply if compatible
3. **Major version updates** (require investigation) - list for user decision
4. **Skipped** (constrained or already latest) - document reason

Present the plan to the user for approval before making changes.

### Step 6: Apply Updates

Edit `repos/fess-parent/pom.xml` to update version properties and plugin versions.

Work in a git worktree rather than `repos/fess-parent` directly — `repos/*` is shared
across sessions. Note that `install -N` in Step 7 publishes to the shared `~/.m2`
regardless, so a worktree isolates the source, not the local repository.

Companion changes (such as `tika-mimetypes.xml`) live in **other repos** and therefore
need their own branch and PR. Keep them separate from the `fess-parent` change, and state
in each PR that the other exists.

### Step 7: Build Verification

Build in dependency order. The consuming repos resolve the parent from `~/.m2`, so the
`install -N` must come first even when working in a worktree:

```bash
# Install updated parent POM (do this first — everything else reads it from ~/.m2)
cd repos/fess-parent && mvn install -N

# Dependency order; fastest signal that coordinates resolve and everything compiles
for R in fess-crawler fess-crawler-playwright fess-suggest; do
  (cd repos/$R && mvn install -DskipTests -q) || echo "FAILED: $R"
done
(cd repos/fess && mvn package -DskipTests)

# Or the full workspace build with tests (slow, but the only run that exercises behavior)
./scripts/build.sh all --with-tests
```

**A green build does not prove the versions took effect.** Verify the resolved artifacts
in the produced WAR, and confirm the constrained libraries did *not* move:

```bash
ls repos/fess/target/fess/WEB-INF/lib/ \
  | grep -E '^(tika-core|pdfbox|asm|guava|commons-codec|lucene-core|log4j-core|jackson-databind|httpclient5|poi)-' \
  | sort
```

If a bumped property does not appear at its new version, or two versions of the same
library show up, trace it before proceeding:

```bash
cd repos/fess && mvn dependency:tree -DoutputFile=/tmp/tree.txt
```

If tests were skipped, say so explicitly in the summary rather than implying the change
is behaviorally verified.

### Step 8: Handle Build Failures

If the build fails:

1. Read the error message carefully
2. Identify which library version caused the failure
3. Check if the issue is:
   - **Artifact not found**: The artifact coordinates (groupId/artifactId) may have changed in the new version
   - **Compilation error**: API breaking change, revert to previous version
   - **Test failure**: Investigate if it's a real incompatibility or a test issue
4. Revert problematic updates and re-run the build
5. Document reverted libraries with reasons

### Step 9: Summary

Present a final summary showing:
- Libraries updated (with old -> new versions)
- Libraries kept at current version (with reasons) — call out the constrained ones where a
  newer release exists but was deliberately not taken, naming the POM that pins each
- Build/test results, and explicitly whether tests were run
- Any companion changes required in other repos (e.g. `tika-mimetypes.xml`)
- Any items deferred for future work

## Common Pitfalls

1. **Don't trust Maven Central search blindly** - The `solrsearch` index is stale (see Step 3); use `maven-metadata.xml`. Separately, some libraries are published to custom repositories (CodeLibs) and Maven Central may show older versions.
2. **Check transitive dependency conflicts** - A library update may pull in incompatible transitive dependencies.
3. **groupId changes** - Some libraries change groupId between major versions (e.g., `javax.*` -> `jakarta.*`, `com.sun.mail` -> `org.eclipse.angus`).
4. **Plugin vs library versions** - Maven plugins are in `<pluginManagement>`, not `<properties>`. Update both sections.
5. **A property bump can be a no-op** - Consumers sometimes hardcode a version instead of using `${xxx.version}`, and Maven's nearest-wins mediation lets that hardcoded *direct* dependency beat the property-driven *transitive* one. The build stays green while the shipped version never changes. Known case: `fess/pom.xml` pins `org.commonmark:commonmark` and `commonmark-ext-gfm-tables` to `0.24.0` while `fess-crawler` uses `${commonmark.version}`, so the WAR ships a split. Always confirm against `WEB-INF/lib` (Step 7).
6. **Deliberate pins carry comments** - `maven-source-plugin` is held at 3.2.1 with an inline reference to MSOURCES-143. Read the surrounding comment before bumping anything that looks outdated.
7. **Resource files can be part of a dependency bump** - `tika.version` has a companion resource in `fess-crawler` (see the Tika section). A version property is not always the whole change.
8. **Constrained does not mean "already correct"** - Check whether the POM is ahead *or behind* the constraint. `asm` was found 9.9.1 against OpenSearch's and Tika's 9.10.1.
9. **Beware vacuous comparisons** - When diffing upstream files across versions, print a digest of the container (jar) too. Two failed downloads produce two empty files and a confident false "identical".

## Error Handling

- If Maven Central is unreachable: use `mvn versions:display-dependency-updates` as fallback
- If build fails after update: revert the problematic library, document, and continue with remaining updates
- If OpenSearch POM is not in local repo: run `mvn dependency:resolve` in `repos/fess` first
