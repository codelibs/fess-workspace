---
name: fess-server
description: Use when building, starting, stopping, or checking the local Fess server.
---

# Fess Server Management

This skill manages the Fess server lifecycle for local development and testing.

## Commands

- **build** - Build Fess and extract to work directory
- **start** - Start the Fess server
- **stop** - Stop the Fess server
- **status** - Check server status

## Directory Structure

```
fess-workspace/
├── repos/fess/           # Source repository
└── work/
    └── fess/
        ├── fess-<version>/   # Extracted Fess distribution
        └── fess.pid          # PID file for running server
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FESS_PORT` | 8080 | HTTP port |
| `FESS_MIN_MEM` | 256m | Minimum heap memory |
| `FESS_MAX_MEM` | 2g | Maximum heap memory |

---

## build

Build Fess from source and extract to work directory.

### Steps

1. Change to Fess repository directory
2. Run Maven build (skip tests for speed)
3. Remove any existing extracted distribution
4. Extract the new distribution to work directory

### Commands

```bash
# Set variables
# Resolve fess-workspace root (directory containing sets/all.yaml)
ROOT_DIR="${FESS_WORKSPACE:-$PWD}"
while [[ "${ROOT_DIR}" != "/" && ! -f "${ROOT_DIR}/sets/all.yaml" ]]; do
    ROOT_DIR="$(dirname "${ROOT_DIR}")"
done
[[ -f "${ROOT_DIR}/sets/all.yaml" ]] || { echo "ERROR: run from inside fess-workspace (or set FESS_WORKSPACE)"; exit 1; }
FESS_REPO="${ROOT_DIR}/repos/fess"
WORK_DIR="${ROOT_DIR}/work/fess"

# Build Fess
cd "${FESS_REPO}" && mvn clean package -DskipTests

# Prepare work directory
rm -rf "${WORK_DIR}/fess-"*
mkdir -p "${WORK_DIR}"

# Extract distribution
unzip -o -q "${FESS_REPO}/target/releases/fess-"*.zip -d "${WORK_DIR}"

# Verify extraction
ls -la "${WORK_DIR}"
```

### Success Criteria

- Maven build completes without errors
- `work/fess/fess-<version>/` directory exists
- `bin/fess` script is present in the extracted directory

---

## start

Start the Fess server in daemon mode.

### Prerequisites

- Fess must be built first (run `build` command if `work/fess/fess-*/` doesn't exist)
- Server must not already be running

### Steps

1. Verify Fess distribution exists
2. Check for existing PID file
3. Set environment variables
4. Start Fess in daemon mode
5. Wait for server to become available

### Commands

```bash
# Set variables
# Resolve fess-workspace root (directory containing sets/all.yaml)
ROOT_DIR="${FESS_WORKSPACE:-$PWD}"
while [[ "${ROOT_DIR}" != "/" && ! -f "${ROOT_DIR}/sets/all.yaml" ]]; do
    ROOT_DIR="$(dirname "${ROOT_DIR}")"
done
[[ -f "${ROOT_DIR}/sets/all.yaml" ]] || { echo "ERROR: run from inside fess-workspace (or set FESS_WORKSPACE)"; exit 1; }
WORK_DIR="${ROOT_DIR}/work/fess"
PID_FILE="${WORK_DIR}/fess.pid"

# Find FESS_HOME
FESS_HOME=$(ls -d "${WORK_DIR}/fess-"* 2>/dev/null | head -1)

if [[ -z "${FESS_HOME}" ]]; then
    echo "ERROR: Fess distribution not found. Run build first."
    exit 1
fi

# Check if already running
if [[ -f "${PID_FILE}" ]]; then
    PID=$(cat "${PID_FILE}")
    if kill -0 "${PID}" 2>/dev/null; then
        echo "ERROR: Fess is already running (PID: ${PID})"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "${PID_FILE}"
    fi
fi

# Set environment
export FESS_HOME
export FESS_PORT="${FESS_PORT:-8080}"
export FESS_MIN_MEM="${FESS_MIN_MEM:-256m}"
export FESS_MAX_MEM="${FESS_MAX_MEM:-2g}"
export FESS_HEAP_SIZE="${FESS_MIN_MEM}"
export FESS_JAVA_OPTS="-Xms${FESS_MIN_MEM} -Xmx${FESS_MAX_MEM}"

echo "Starting Fess..."
echo "  FESS_HOME: ${FESS_HOME}"
echo "  FESS_PORT: ${FESS_PORT}"
echo "  Memory: ${FESS_MIN_MEM} - ${FESS_MAX_MEM}"

# Start Fess in daemon mode
"${FESS_HOME}/bin/fess" -d -p "${PID_FILE}"

# Wait for startup (max 120 seconds)
echo "Waiting for Fess to start..."
for i in {1..60}; do
    if curl -s "http://localhost:${FESS_PORT}/" > /dev/null 2>&1; then
        echo "Fess is running at http://localhost:${FESS_PORT}/"
        exit 0
    fi
    sleep 2
done

echo "WARNING: Fess may not have started properly. Check logs at ${FESS_HOME}/logs/"
```

### Success Criteria

- PID file is created at `work/fess/fess.pid`
- HTTP response from `http://localhost:${FESS_PORT}/`
- Process is running

---

## stop

Stop the running Fess server gracefully.

### Steps

1. Read PID from PID file
2. Send SIGTERM for graceful shutdown
3. Wait up to 30 seconds for process to stop
4. If still running, send SIGKILL
5. Remove PID file

### Commands

```bash
# Set variables
# Resolve fess-workspace root (directory containing sets/all.yaml)
ROOT_DIR="${FESS_WORKSPACE:-$PWD}"
while [[ "${ROOT_DIR}" != "/" && ! -f "${ROOT_DIR}/sets/all.yaml" ]]; do
    ROOT_DIR="$(dirname "${ROOT_DIR}")"
done
[[ -f "${ROOT_DIR}/sets/all.yaml" ]] || { echo "ERROR: run from inside fess-workspace (or set FESS_WORKSPACE)"; exit 1; }
WORK_DIR="${ROOT_DIR}/work/fess"
PID_FILE="${WORK_DIR}/fess.pid"

if [[ ! -f "${PID_FILE}" ]]; then
    echo "Fess is not running (no PID file)"
    exit 0
fi

PID=$(cat "${PID_FILE}")

if ! kill -0 "${PID}" 2>/dev/null; then
    echo "Fess process not found (stale PID file). Cleaning up."
    rm -f "${PID_FILE}"
    exit 0
fi

echo "Stopping Fess (PID: ${PID})..."

# Send SIGTERM
kill "${PID}" 2>/dev/null

# Wait for graceful shutdown (max 30 seconds)
for i in {1..30}; do
    if ! kill -0 "${PID}" 2>/dev/null; then
        echo "Fess stopped gracefully."
        rm -f "${PID_FILE}"
        exit 0
    fi
    sleep 1
done

# Force kill if still running
echo "Fess did not stop gracefully. Forcing termination..."
kill -9 "${PID}" 2>/dev/null
sleep 1

if kill -0 "${PID}" 2>/dev/null; then
    echo "ERROR: Failed to stop Fess"
    exit 1
fi

rm -f "${PID_FILE}"
echo "Fess stopped."
```

### Success Criteria

- Process is no longer running
- PID file is removed

---

## status

Check the current status of the Fess server.

### Commands

```bash
# Set variables
# Resolve fess-workspace root (directory containing sets/all.yaml)
ROOT_DIR="${FESS_WORKSPACE:-$PWD}"
while [[ "${ROOT_DIR}" != "/" && ! -f "${ROOT_DIR}/sets/all.yaml" ]]; do
    ROOT_DIR="$(dirname "${ROOT_DIR}")"
done
[[ -f "${ROOT_DIR}/sets/all.yaml" ]] || { echo "ERROR: run from inside fess-workspace (or set FESS_WORKSPACE)"; exit 1; }
WORK_DIR="${ROOT_DIR}/work/fess"
PID_FILE="${WORK_DIR}/fess.pid"
FESS_PORT="${FESS_PORT:-8080}"

echo "=== Fess Server Status ==="

# Check distribution
FESS_HOME=$(ls -d "${WORK_DIR}/fess-"* 2>/dev/null | head -1)
if [[ -z "${FESS_HOME}" ]]; then
    echo "Distribution: NOT FOUND (run build)"
else
    echo "Distribution: ${FESS_HOME}"
fi

# Check PID file
if [[ ! -f "${PID_FILE}" ]]; then
    echo "Process: NOT RUNNING (no PID file)"
else
    PID=$(cat "${PID_FILE}")
    if kill -0 "${PID}" 2>/dev/null; then
        echo "Process: RUNNING (PID: ${PID})"
    else
        echo "Process: NOT RUNNING (stale PID file)"
    fi
fi

# Check HTTP response
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${FESS_PORT}/" 2>/dev/null | grep -q "200\|302"; then
    echo "HTTP: RESPONDING at http://localhost:${FESS_PORT}/"
else
    echo "HTTP: NOT RESPONDING"
fi
```

### Status Output

- **Distribution**: Path to extracted Fess or "NOT FOUND"
- **Process**: "RUNNING (PID: xxx)" or "NOT RUNNING"
- **HTTP**: "RESPONDING" or "NOT RESPONDING"

---

## Troubleshooting

### Build Failures

```bash
# Check Maven logs
cd repos/fess && mvn clean package -DskipTests -X

# Verify Java version (requires Java 17+)
java -version
```

### Startup Issues

```bash
# Check Fess logs
tail -f work/fess/fess-*/logs/fess.log
tail -f work/fess/fess-*/logs/fess_system.log

# Check port availability
lsof -i :8080
```

### Memory Issues

```bash
# Increase memory allocation
export FESS_MAX_MEM=4g
# Then start Fess
```

### Permission Issues

```bash
# Ensure scripts are executable
chmod +x work/fess/fess-*/bin/fess
```
