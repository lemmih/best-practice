#!/usr/bin/env bash
set -e

# This script runs end-to-end tests with geckodriver and wrangler
# Expected environment variables:
#   WEBAPP_PATH - Path to the built webapp
#   CURL_BIN - Path to curl binary
#   WRANGLER_BIN - Path to wrangler binary
#   E2E_TESTS_BIN - Path to e2e_tests binary
#   WRANGLER_PORT (optional, default: 8787)
#   WEBDRIVER_PORT (optional, default: 4444)
#   E2E_BROWSER (optional, default: firefox)

# shellcheck disable=SC2153
: "${WEBAPP_PATH:?}" "${CURL_BIN:?}" "${WRANGLER_BIN:?}" "${E2E_TESTS_BIN:?}"

# Create a temporary directory for all e2e test artifacts
# This prevents polluting the user's CWD with node_modules, logs, etc.
E2E_TMPDIR=$(mktemp -d)
echo "Using temp directory: $E2E_TMPDIR"

# Setup cleanup trap to kill wrangler and geckodriver on exit
# shellcheck disable=SC2317,SC2329
cleanup() {
	local exit_code=${TEST_EXIT_CODE:-1}

	if [ -n "${WRANGLER_PID:-}" ]; then
		echo "Stopping wrangler and its child processes..."
		# Kill all children of wrangler first
		pkill -P "$WRANGLER_PID" 2>/dev/null || true
		# Then kill wrangler itself
		kill "$WRANGLER_PID" 2>/dev/null || true
		# Wait a moment then force kill if still running
		sleep 1
		kill -9 "$WRANGLER_PID" 2>/dev/null || true
	fi
	if [ -n "${GECKODRIVER_PID:-}" ]; then
		echo "Stopping geckodriver..."
		kill "$GECKODRIVER_PID" 2>/dev/null || true
	fi

	# Only keep logs on failure
	if [ "$exit_code" -ne 0 ] && [ -d "$E2E_TMPDIR" ]; then
		echo "Tests failed. Logs available in: $E2E_TMPDIR"
		echo "--- geckodriver.log ---"
		cat "$E2E_TMPDIR/geckodriver.log" 2>/dev/null || true
		echo "--- wrangler.log ---"
		cat "$E2E_TMPDIR/wrangler.log" 2>/dev/null || true
	else
		# Clean up temp directory on success
		rm -rf "$E2E_TMPDIR"
	fi
}
trap cleanup EXIT

# Create result symlink inside temp directory
# Wrangler config references result/ for e2e environment
ln -sfn "$WEBAPP_PATH" "$E2E_TMPDIR/result"

# Copy wrangler.toml to temp directory
cp wrangler.toml "$E2E_TMPDIR/"

# Start geckodriver in the background (logs to temp dir)
echo "Starting geckodriver..."
WEBDRIVER_PORT=${WEBDRIVER_PORT:-4444}
geckodriver --port="$WEBDRIVER_PORT" >"$E2E_TMPDIR/geckodriver.log" 2>&1 &
GECKODRIVER_PID=$!
echo "Geckodriver started with PID $GECKODRIVER_PID on port $WEBDRIVER_PORT"

# Wait for geckodriver to start (up to 10 seconds)
echo "Waiting for geckodriver to be ready..."
for i in {1..10}; do
	if "$CURL_BIN" -sf "http://localhost:$WEBDRIVER_PORT/status" >/dev/null 2>&1; then
		echo "Geckodriver is ready!"
		break
	fi
	if [ "$i" -eq 10 ]; then
		echo "Geckodriver failed to start within 10 seconds"
		echo "Last 20 lines of geckodriver.log:"
		tail -20 "$E2E_TMPDIR/geckodriver.log" || true
		exit 1
	fi
	sleep 1
done

# Start wrangler dev with e2e environment (runs in temp dir to contain node_modules)
echo "Starting wrangler dev with e2e environment..."
WRANGLER_PORT=${WRANGLER_PORT:-8787}
(cd "$E2E_TMPDIR" && "$WRANGLER_BIN" dev --env e2e --port "$WRANGLER_PORT" >wrangler.log 2>&1) &
WRANGLER_PID=$!
echo "Wrangler started with PID $WRANGLER_PID"

# Wait for wrangler to start (up to 30 seconds)
echo "Waiting for wrangler to start on port $WRANGLER_PORT..."
for i in {1..30}; do
	if "$CURL_BIN" -sf "http://localhost:$WRANGLER_PORT" >/dev/null 2>&1; then
		echo "Wrangler is ready!"
		break
	fi
	if [ "$i" -eq 30 ]; then
		echo "Wrangler failed to start within 30 seconds"
		echo "Last 20 lines of wrangler.log:"
		tail -20 "$E2E_TMPDIR/wrangler.log" || true
		exit 1
	fi
	sleep 1
done

# Run e2e tests with headless Firefox
echo "Running e2e tests with headless Firefox..."
export WRANGLER_PORT
export WEBDRIVER_PORT
export E2E_BROWSER=${E2E_BROWSER:-firefox}

# Run tests and capture exit code
"$E2E_TESTS_BIN"
TEST_EXIT_CODE=$?

# Exit with test exit code (cleanup trap will run automatically)
exit $TEST_EXIT_CODE
