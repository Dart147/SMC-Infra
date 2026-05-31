#!/usr/bin/env bash
# Smoke test for the Prometheus Watchdog → Healthchecks.io DMS chain.
# If Healthchecks.io has received a ping recently, it proves
# the entire chain (rule → Alertmanager → network → DMS) is healthy.
#
# Usage:
#   ./scripts/smoke-watchdog.sh [check-slug] [max-age-seconds]
#
# Defaults: slug=prometheus-checker, max-age=1200s (15m period + 5m slack).
# Exit codes: 0 = healthy, 1 = stale/down, 2 = missing config.

set -euo pipefail

CHECK_SLUG="${1:-prometheus-checker}"
MAX_AGE_SECONDS="${2:-1200}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_KEY_FILE="${REPO_ROOT}/services/observe/config/prometheus/secrets/healthchecks/api-key"

if [[ ! -r "$API_KEY_FILE" ]]; then
  echo "FAIL: missing or unreadable API key at $API_KEY_FILE" >&2
  echo "      Create a read-only API key in Healthchecks.io (Project Settings →" >&2
  echo "      API Access) and write it to that file." >&2
  exit 2
fi
API_KEY="$(tr -d '[:space:]' < "$API_KEY_FILE")"

resp="$(curl -fsS -H "X-Api-Key: ${API_KEY}" \
  "https://healthchecks.io/api/v3/checks/?slug=${CHECK_SLUG}")"

count="$(echo "$resp" | jq '.checks | length')"
if [[ "$count" == "0" ]]; then
  echo "FAIL: no check found with slug '${CHECK_SLUG}'" >&2
  exit 1
fi

status="$(echo    "$resp" | jq -r '.checks[0].status')"
last_ping="$(echo "$resp" | jq -r '.checks[0].last_ping')"

if [[ "$last_ping" == "null" || -z "$last_ping" ]]; then
  echo "FAIL: check '${CHECK_SLUG}' has never received a ping" >&2
  exit 1
fi

# Portable epoch conversion: GNU date first, then BSD/macOS fallback.
if last_epoch="$(date -d "$last_ping" +%s 2>/dev/null)"; then
  :
else
  trimmed="${last_ping%+*}"   # strip timezone offset
  trimmed="${trimmed%.*}"     # strip fractional seconds
  last_epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$trimmed" +%s)"
fi

now_epoch="$(date -u +%s)"
age=$(( now_epoch - last_epoch ))

echo "check=${CHECK_SLUG} status=${status} last_ping=${last_ping} age=${age}s threshold=${MAX_AGE_SECONDS}s"

if [[ "$status" != "up" ]]; then
  echo "FAIL: Healthchecks.io reports status '${status}' (expected 'up')" >&2
  exit 1
fi

if (( age > MAX_AGE_SECONDS )); then
  echo "FAIL: last ping is ${age}s old, exceeds threshold of ${MAX_AGE_SECONDS}s" >&2
  exit 1
fi

echo "OK: watchdog chain healthy"
