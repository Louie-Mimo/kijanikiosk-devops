#!/usr/bin/env bash

set -euo pipefail

ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_STATE="/opt/kijanikiosk/.previous-env"

log() {
    echo "[$(date -u +%H:%M:%S)] [ROLLBACK] $*"
}

log_fail() {
    echo "[$(date -u +%H:%M:%S)] [ROLLBACK FAIL] $*" >&2
}

if [ -f "${PREVIOUS_ENV_STATE}" ]; then
    ROLLBACK_TARGET=$(cat "${PREVIOUS_ENV_STATE}")

    log "Rolling back to previous environment: ${ROLLBACK_TARGET}"

elif [ -f "${ACTIVE_ENV_STATE}" ]; then

    CURRENT=$(cat "${ACTIVE_ENV_STATE}")

    if [ "${CURRENT}" = "blue" ]; then
        ROLLBACK_TARGET="green"
    else
        ROLLBACK_TARGET="blue"
    fi

    log "No previous-env record."
    log "Inferring rollback target: ${ROLLBACK_TARGET}"

else
    log_fail "Cannot determine rollback target"
    exit 1
fi

log "Calling switch-env.sh ${ROLLBACK_TARGET}..."

bash "$(dirname "$0")/switch-env.sh" "${ROLLBACK_TARGET}"

SWITCH_EXIT=$?

case "${SWITCH_EXIT}" in
    0)
        log "Rollback to ${ROLLBACK_TARGET} successful."
        ;;

    1)
        log_fail "Rollback failed: pre-condition check failed."
        ;;

    2)
        log_fail "Rollback failed: nginx configuration error."
        ;;

    3)
        log_fail "Rollback failed: switch completed but health check did not confirm."
        ;;

    *)
        log_fail "Rollback failed with unexpected exit code ${SWITCH_EXIT}."
        ;;
esac

exit "${SWITCH_EXIT}"
