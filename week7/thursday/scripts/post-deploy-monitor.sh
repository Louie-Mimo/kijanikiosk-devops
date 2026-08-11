#!/usr/bin/env bash

set -uo pipefail

MONITOR_SECONDS="${1:-120}"

HEALTH_URL="http://127.0.0.1:80/health"
ROLLBACK_SCRIPT="/opt/kijanikiosk/scripts/rollback.sh"

POLL_INTERVAL=5
MAX_CONSECUTIVE_FAILURES=3
MAX_LATENCY_SECONDS=2
MAX_WINDOW_ERRORS=2

consecutive_failures=0
window_errors=0
poll=0

START_TIME=$(date +%s)

log() {
    echo "[$(date '+%H:%M:%S')] [MONITOR] $*"
}

warn() {
    echo "[$(date '+%H:%M:%S')] [MONITOR WARN] $*" >&2
}

fail() {
    echo "[$(date '+%H:%M:%S')] [MONITOR FAIL] $*" >&2
}

rollback() {
    local reason="$1"

    fail "ROLLBACK TRIGGERED: ${reason}"
    fail "Calling rollback.sh..."

    if sudo bash "${ROLLBACK_SCRIPT}"; then
        log "Rollback completed successfully."

        local finish_time
        finish_time=$(date +%s)

        log "Monitor elapsed time: $((finish_time - START_TIME))s"
        exit 0
    else
        fail "Rollback FAILED."
        exit 2
    fi
}

log "Starting post-deployment confidence window."
log "Window: ${MONITOR_SECONDS}s"
log "Poll interval: ${POLL_INTERVAL}s"
log "Failure threshold: ${MAX_CONSECUTIVE_FAILURES} consecutive failures"
log "Latency threshold: ${MAX_LATENCY_SECONDS}s"
log "Window error tolerance: ${MAX_WINDOW_ERRORS}"
log "Health URL: ${HEALTH_URL}"

while true; do
    now=$(date +%s)
    elapsed=$((now - START_TIME))

    if [ "${elapsed}" -ge "${MONITOR_SECONDS}" ]; then
        break
    fi

    poll=$((poll + 1))

    RESULT=$(
        curl \
            --silent \
            --output /tmp/kijanikiosk-monitor-body.$$ \
            --write-out '%{http_code} %{time_total}' \
            --max-time 5 \
            "${HEALTH_URL}" 2>/dev/null
    )

    CURL_EXIT=$?

    if [ "${CURL_EXIT}" -ne 0 ]; then
        HTTP_CODE="000"
        RESPONSE_TIME="5.000"
    else
        HTTP_CODE=$(echo "${RESULT}" | awk '{print $1}')
        RESPONSE_TIME=$(echo "${RESULT}" | awk '{print $2}')
    fi

    now=$(date +%s)
    elapsed=$((now - START_TIME))

    log "Poll ${poll}: HTTP ${HTTP_CODE} | ${RESPONSE_TIME}s | elapsed: ${elapsed}s"

    HEALTHY=true

    if [ "${HTTP_CODE}" != "200" ]; then
        HEALTHY=false
    fi

    if awk "BEGIN {exit !(${RESPONSE_TIME} > ${MAX_LATENCY_SECONDS})}"; then
        warn "Latency threshold exceeded: ${RESPONSE_TIME}s > ${MAX_LATENCY_SECONDS}s"
        HEALTHY=false
    fi

    if [ "${HEALTHY}" = "true" ]; then
        consecutive_failures=0
    else
        consecutive_failures=$((consecutive_failures + 1))
        window_errors=$((window_errors + 1))

        warn "Health check failed (consecutive: ${consecutive_failures}, window errors: ${window_errors})"
    fi

    if [ "${consecutive_failures}" -ge "${MAX_CONSECUTIVE_FAILURES}" ]; then
        rollback "${MAX_CONSECUTIVE_FAILURES} consecutive health check failures"
    fi

    # MAX_WINDOW_ERRORS means two errors are tolerated.
    # Rollback occurs when the count exceeds that budget.
    if [ "${window_errors}" -gt "${MAX_WINDOW_ERRORS}" ]; then
        rollback "window error threshold exceeded (${window_errors} errors)"
    fi

    sleep "${POLL_INTERVAL}"
done

rm -f /tmp/kijanikiosk-monitor-body.$$ 2>/dev/null || true

log "Confidence window completed successfully."
log "Total polls: ${poll}"
log "Window errors: ${window_errors}"
log "No rollback required."

exit 0
