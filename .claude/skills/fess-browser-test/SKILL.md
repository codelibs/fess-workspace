---
name: fess-browser-test
description: Use when running browser-based UI tests for Fess.
---

# Fess Browser Test Framework

This skill provides a framework for browser-based UI testing of Fess using the `agent-browser` skill.

## Prerequisites

Before running browser tests, ensure:

1. **Fess server is running** - Use `/fess-server status` to verify
2. **agent-browser skill is available** - Required for browser automation

### Pre-flight Check

```bash
# Verify Fess is running
# Resolve fess-workspace root (directory containing sets/all.yaml)
ROOT_DIR="${FESS_WORKSPACE:-$PWD}"
while [[ "${ROOT_DIR}" != "/" && ! -f "${ROOT_DIR}/sets/all.yaml" ]]; do
    ROOT_DIR="$(dirname "${ROOT_DIR}")"
done
[[ -f "${ROOT_DIR}/sets/all.yaml" ]] || { echo "ERROR: run from inside fess-workspace (or set FESS_WORKSPACE)"; exit 1; }
PID_FILE="${ROOT_DIR}/work/fess/fess.pid"
FESS_PORT="${FESS_PORT:-8080}"

if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
    echo "ERROR: Fess is not running. Start it with /fess-server start"
    exit 1
fi

if ! curl -s "http://localhost:${FESS_PORT}/" > /dev/null 2>&1; then
    echo "ERROR: Fess is not responding at http://localhost:${FESS_PORT}/"
    exit 1
fi

echo "Fess is ready for browser testing at http://localhost:${FESS_PORT}/"
```

---

## Test Execution Flow

```
1. Verify server status (pre-flight check)
        ↓
2. Define test scenario
        ↓
3. Invoke agent-browser skill
        ↓
4. Execute browser actions
        ↓
5. Verify results
        ↓
6. Report outcome
```

---

## Using agent-browser

The `agent-browser` skill provides browser automation capabilities. Invoke it using:

```
/agent-browser
```

Then provide instructions for the specific test scenario.

---

## Test Scenario Template

When defining a test scenario, include:

### 1. Target URL

```
http://localhost:8080/           # Search page
http://localhost:8080/admin/     # Admin console
```

### 2. Actions to Perform

- Navigate to URL
- Fill form fields
- Click buttons
- Wait for elements
- Extract text/data
- Take screenshots

### 3. Expected Results

- Page elements visible
- Search results returned
- Form submission successful
- Error messages displayed correctly

---

## Example Test Scenarios

### Basic Search Test

**Objective**: Verify search functionality works

**Steps**:
1. Navigate to `http://localhost:8080/`
2. Enter "test" in search box
3. Click search button or press Enter
4. Verify search results page loads
5. Check that result count is displayed

**Expected Results**:
- Search results page displays
- Results count shows (may be 0 if no content indexed)
- No error messages

### Admin Login Test

**Objective**: Verify admin authentication

**Steps**:
1. Navigate to `http://localhost:8080/admin/`
2. Enter username: `admin`
3. Enter password: `admin`
4. Click login button
5. Verify dashboard loads

**Expected Results**:
- Redirected to admin dashboard
- Admin menu visible
- User name displayed

### Crawler Configuration Test

**Objective**: Verify web crawler setup

**Steps**:
1. Login to admin console
2. Navigate to Crawler > Web
3. Click "Create New"
4. Fill in:
   - Name: "Test Crawler"
   - URLs: "https://example.com"
5. Save configuration
6. Verify crawler appears in list

**Expected Results**:
- Configuration saved successfully
- Crawler listed with correct name
- No validation errors

### Search Settings Test

**Objective**: Verify search settings modification

**Steps**:
1. Login to admin console
2. Navigate to System > General
3. Modify a setting (e.g., results per page)
4. Save changes
5. Perform search and verify setting applied

**Expected Results**:
- Settings saved successfully
- Changes reflected in search behavior

---

## Writing Custom Test Scenarios

When requesting a browser test, provide:

```markdown
## Test: [Test Name]

### Objective
[What you're testing]

### Preconditions
[Any setup required]

### Steps
1. [Action 1]
2. [Action 2]
3. ...

### Expected Results
- [Result 1]
- [Result 2]
- ...

### Screenshots
[Whether to capture screenshots at specific points]
```

---

## Troubleshooting

### Browser Not Launching

- Ensure agent-browser skill is properly installed
- Check for conflicting browser processes

### Page Not Loading

- Verify Fess server is running: `/fess-server status`
- Check correct port is configured
- Review Fess logs for errors

### Element Not Found

- Page may still be loading - add wait time
- Element selector may have changed
- Check if element is inside iframe

### Authentication Failures

- Default admin credentials: `admin` / `admin`
- Password may have been changed
- Session may have expired

---

## Best Practices

1. **Always verify server status first** before running tests
2. **Use explicit waits** for dynamic content
3. **Take screenshots** at key points for debugging
4. **Clean up test data** after tests complete
5. **Run tests in isolation** - don't depend on previous test state
6. **Check logs** when tests fail unexpectedly
