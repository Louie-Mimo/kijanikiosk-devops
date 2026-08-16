#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="${SCRIPT_DIR}/error-rate-monitor.py"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

HEALTHY_LOG="${TMP_DIR}/healthy.jsonl"
ALERT_LOG="${TMP_DIR}/alert.jsonl"

echo "=== TEST 1: EXACTLY 5% ERROR RATE ==="

for i in $(seq 1 19); do
    printf '{"probe":%d,"status":200}\n' "$i" >> "$HEALTHY_LOG"
done

printf '{"probe":20,"status":500}\n' >> "$HEALTHY_LOG"

python3 "$MONITOR" \
    "$HEALTHY_LOG" \
    --threshold 5

echo
echo "PASS: exactly 5% does not trigger >5% alert."

echo
echo "=== TEST 2: 10% ERROR RATE ==="

for i in $(seq 1 18); do
    printf '{"probe":%d,"status":200}\n' "$i" >> "$ALERT_LOG"
done

printf '{"probe":19,"status":500}\n' >> "$ALERT_LOG"
printf '{"probe":20,"status":500}\n' >> "$ALERT_LOG"

set +e

python3 "$MONITOR" \
    "$ALERT_LOG" \
    --threshold 5

RC=$?

set -e

if [[ "$RC" -ne 1 ]]; then
    echo "FAIL: expected monitor exit code 1 for >5% error rate."
    exit 1
fi

echo
echo "PASS: 10% error rate correctly triggered ALERT."
