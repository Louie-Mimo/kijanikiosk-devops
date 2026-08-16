#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAMESPACE="${NAMESPACE:-kijani-staging}"
SERVICE="${SERVICE:-kk-payments}"

LOCAL_PORT="${LOCAL_PORT:-13004}"
SERVICE_PORT="${SERVICE_PORT:-3001}"

REQUEST_COUNT="${REQUEST_COUNT:-20}"
THRESHOLD="${THRESHOLD:-5}"

OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/output}"

PROBE_LOG="${OUTPUT_DIR}/staging-error-rate.jsonl"
SUMMARY="${OUTPUT_DIR}/staging-error-rate-summary.txt"
PF_LOG="${OUTPUT_DIR}/staging-monitor-port-forward.log"

mkdir -p "$OUTPUT_DIR"

rm -f \
    "$PROBE_LOG" \
    "$SUMMARY" \
    "$PF_LOG"

cleanup() {
    if [[ -n "${PF_PID:-}" ]]; then
        kill "$PF_PID" 2>/dev/null || true
        wait "$PF_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

echo "========================================"
echo "KIJANIKIOSK STAGING ERROR-RATE MONITOR"
echo "========================================"

echo
echo "Namespace    : $NAMESPACE"
echo "Service      : $SERVICE"
echo "Probe count  : $REQUEST_COUNT"
echo "Threshold    : ${THRESHOLD}%"

echo
echo "Starting Kubernetes port-forward..."

kubectl port-forward \
    -n "$NAMESPACE" \
    "svc/$SERVICE" \
    "${LOCAL_PORT}:${SERVICE_PORT}" \
    >"$PF_LOG" 2>&1 &

PF_PID=$!

echo "Waiting for port-forward..."

READY=0

for attempt in $(seq 1 10); do
    if ! kill -0 "$PF_PID" 2>/dev/null; then
        echo "ERROR: kubectl port-forward terminated unexpectedly."
        cat "$PF_LOG"
        exit 2
    fi

    if grep -q "Forwarding from" "$PF_LOG" 2>/dev/null; then
        READY=1
        break
    fi

    sleep 1
done

if [[ "$READY" -ne 1 ]]; then
    echo "ERROR: port-forward did not become ready."
    cat "$PF_LOG"
    exit 2
fi

echo "Port-forward ready."

echo
echo "Collecting live HTTP probes..."

for probe in $(seq 1 "$REQUEST_COUNT"); do

    HTTP_STATUS="$(
        curl \
            --silent \
            --output /dev/null \
            --write-out '%{http_code}' \
            --max-time 5 \
            "http://127.0.0.1:${LOCAL_PORT}/health" \
        || true
    )"

    if [[ ! "$HTTP_STATUS" =~ ^[0-9]{3}$ ]]; then
        HTTP_STATUS="000"
    fi

    NUMERIC_STATUS=$((10#$HTTP_STATUS))

    TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    printf \
        '{"timestamp":"%s","probe":%d,"method":"GET","path":"/health","status":%d}\n' \
        "$TIMESTAMP" \
        "$probe" \
        "$NUMERIC_STATUS" \
        >> "$PROBE_LOG"

    printf \
        "Probe %02d/%02d -> HTTP %s\n" \
        "$probe" \
        "$REQUEST_COUNT" \
        "$HTTP_STATUS"

    sleep 0.1
done

echo
echo "Calculating error rate..."

python3 "${SCRIPT_DIR}/error-rate-monitor.py" \
    "$PROBE_LOG" \
    --threshold "$THRESHOLD" \
    | tee "$SUMMARY"
