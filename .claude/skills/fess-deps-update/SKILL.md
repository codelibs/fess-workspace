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

```bash
# Find OpenSearch version from pom.xml
grep 'opensearch.version' repos/fess-parent/pom.xml

# Check OpenSearch's POM for its dependency versions
cat ~/.m2/repository/org/opensearch/opensearch/<VERSION>/opensearch-<VERSION>.pom | grep -E '(jackson|lucene|log4j|asm|httpclient|httpcore|slf4j).*version'
```

**Must match OpenSearch exactly:**
- jackson (core, databind, annotations)
- lucene
- log4j
- asm
- httpcomponents (httpclient 4.x, httpcore 4.x)
- httpclient5

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

### Jakarta Mail Constraint

The `jakarta.mail.version` property is used by both `com.sun.mail:jakarta.mail` (legacy) and `org.eclipse.angus:angus-mail` (new). When updating, verify which groupId each consuming module uses. `com.sun.mail:jakarta.mail` was only published up to 2.0.2 on Maven Central; later versions use the `org.eclipse.angus` groupId.

### SLF4J Constraint

SLF4J 1.x to 2.x is a major upgrade requiring `log4j-slf4j-impl` to `log4j-slf4j2-impl` bridge changes across multiple repositories. This should be done in a dedicated PR, not as part of routine updates.

## Workflow

### Step 1: Identify Current Versions

Read `repos/fess-parent/pom.xml` and list all version properties in the `<properties>` section.

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

For each freely updatable library, query Maven Central:

```bash
# Example: check latest version
curl -s "https://search.maven.org/solrsearch/select?q=g:GROUP_ID+AND+a:ARTIFACT_ID&rows=1&wt=json" | jq -r '.response.docs[0].latestVersion'
```

Use the WebFetch or WebSearch tool for batch lookups when needed.

**Important:** Only consider stable releases. Skip:
- `-alpha`, `-beta`, `-RC`, `-M` (milestone) versions
- `-SNAPSHOT` versions

### Step 4: Check Constraint Compatibility

For libraries in constrained categories:

1. **OpenSearch**: Read OpenSearch's POM to verify version alignment
2. **Tika**: Read Tika parent's POM to verify POI and other versions
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

### Step 7: Build Verification

```bash
# Install updated parent POM
cd repos/fess-parent && mvn install -N

# Full build with tests
cd /path/to/fess-workspace && ./scripts/build.sh all --with-tests
```

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
- Libraries kept at current version (with reasons)
- Build/test results
- Any items deferred for future work

## Common Pitfalls

1. **Don't trust Maven Central search blindly** - Some libraries are published to custom repositories (CodeLibs). Maven Central may show older versions.
2. **Check transitive dependency conflicts** - A library update may pull in incompatible transitive dependencies.
3. **groupId changes** - Some libraries change groupId between major versions (e.g., `javax.*` -> `jakarta.*`, `com.sun.mail` -> `org.eclipse.angus`).
4. **Plugin vs library versions** - Maven plugins are in `<pluginManagement>`, not `<properties>`. Update both sections.

## Error Handling

- If Maven Central is unreachable: use `mvn versions:display-dependency-updates` as fallback
- If build fails after update: revert the problematic library, document, and continue with remaining updates
- If OpenSearch POM is not in local repo: run `mvn dependency:resolve` in `repos/fess` first
