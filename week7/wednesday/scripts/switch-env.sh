#!/usr/bin/env bash

set -euo pipefail

ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_STATE="/opt/kijanikiosk/.previous-env"
NGINX_ACTIVE="/etc/nginx/kijanikiosk-active-env.conf"

TARGET_ENV="${1:-}"

MAX_ATTEMPTS=15
RETRY_DELAY=2

TMP_CONFIG=""
BACKUP_CONFIG=""

log() {
    echo "[$(date '+%H:%M:%S')] [SWITCH] $*"
}

log_fail() {
    echo "[$(date '+%H:%M:%S')] [SWITCH FAIL] $*" >&2
}

cleanup() {
    if [ -n "${TMP_CONFIG}" ] && [ -f "${TMP_CONFIG}" ]; then
        rm -f "${TMP_CONFIG}"
    fi

    if [ -n "${BACKUP_CONFIG}" ] && [ -f "${BACKUP_CONFIG}" ]; then
        rm -f "${BACKUP_CONFIG}"
    fi
}

trap cleanup EXIT


# ============================================================
# Validate argument
# ============================================================

if [ "${TARGET_ENV}" != "blue" ] && [ "${TARGET_ENV}" != "green" ]; then
    log_fail "Usage: $0 blue|green"
    exit 1
fi


# ============================================================
# Determine current environment
# ============================================================

if [ ! -f "${ACTIVE_ENV_STATE}" ]; then
    log_fail "Active environment state file does not exist: ${ACTIVE_ENV_STATE}"
    exit 1
fi

CURRENT_ENV="$(tr -d '[:space:]' < "${ACTIVE_ENV_STATE}")"

if [ "${CURRENT_ENV}" != "blue" ] && [ "${CURRENT_ENV}" != "green" ]; then
    log_fail "Invalid current environment: ${CURRENT_ENV}"
    exit 1
fi


# ============================================================
# Determine target settings
# ============================================================

case "${TARGET_ENV}" in
    blue)
        TARGET_PORT=3000
        TARGET_SERVICE="kk-api-blue.service"
        TARGET_UPSTREAM="kk-api-blue"
        ;;
    green)
        TARGET_PORT=3001
        TARGET_SERVICE="kk-api-green.service"
        TARGET_UPSTREAM="kk-api-green"
        ;;
esac

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"


# ============================================================
# Already active?
# ============================================================

if [ "${CURRENT_ENV}" = "${TARGET_ENV}" ]; then
    log "Target environment ${TARGET_ENV} is already active."
    log "No traffic switch required."
    exit 0
fi


# ============================================================
# STEP 1 - Verify target
# ============================================================

log "Step 1: Verifying ${TARGET_ENV} is healthy on port ${TARGET_PORT}..."

if ! systemctl is-active --quiet "${TARGET_SERVICE}"; then
    log_fail "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding"
    log_fail "Refusing to switch. Run the deployment script first."
    exit 1
fi

HEALTH_RESPONSE="$(
    curl \
        --silent \
        --show-error \
        --fail \
        --max-time 5 \
        "http://127.0.0.1:${TARGET_PORT}/health"
)" || {
    log_fail "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding"
    log_fail "Refusing to switch. Run the deployment script first."
    exit 1
}

log "Target health: ${HEALTH_RESPONSE}"

if ! echo "${HEALTH_RESPONSE}" |
    grep -Eq "\"status\"[[:space:]]*:[[:space:]]*\"ok\""; then

    log_fail "Target ${TARGET_ENV} returned an unhealthy response"
    exit 1
fi

if ! echo "${HEALTH_RESPONSE}" |
    grep -Eq "\"port\"[[:space:]]*:[[:space:]]*${TARGET_PORT}([,}])"; then

    log_fail "Target health endpoint is not reporting port ${TARGET_PORT}"
    exit 1
fi

log "Pre-switch health check passed: ${TARGET_ENV} is healthy"


# ============================================================
# STEP 2 - Build new nginx config
# ============================================================

log "Step 2: Writing new nginx active-env configuration..."

TMP_CONFIG="$(mktemp "${NGINX_ACTIVE}.new.XXXXXX")"
BACKUP_CONFIG="$(mktemp "${NGINX_ACTIVE}.backup.XXXXXX")"

# Preserve the currently working config in case validation,
# reload, or post-switch verification fails.
cp -a "${NGINX_ACTIVE}" "${BACKUP_CONFIG}"

cat > "${TMP_CONFIG}" <<EOF
location / {
    proxy_pass http://${TARGET_UPSTREAM};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_cache_bypass \$http_upgrade;
}

location /health {
    proxy_pass http://${TARGET_UPSTREAM};
}
EOF

# Preserve existing permissions and ownership.
chown --reference="${NGINX_ACTIVE}" "${TMP_CONFIG}"
chmod --reference="${NGINX_ACTIVE}" "${TMP_CONFIG}"

# Put the candidate config in the active location.
#
# nginx has NOT been reloaded yet, so live traffic is still
# using the old configuration at this point.
mv -f "${TMP_CONFIG}" "${NGINX_ACTIVE}"
TMP_CONFIG=""


# ============================================================
# STEP 3 - Validate NEW nginx config
# ============================================================

log "Step 3: Validating nginx configuration..."

if ! nginx -t; then
    log_fail "nginx configuration validation failed"
    log_fail "Restoring previous nginx configuration"

    cp -a "${BACKUP_CONFIG}" "${NGINX_ACTIVE}"

    exit 2
fi

log "nginx configuration validation passed"


# ============================================================
# STEP 4 - Reload nginx
# ============================================================

log "Step 4: Reloading nginx..."

if ! systemctl reload nginx; then
    log_fail "nginx reload failed"
    log_fail "Restoring previous nginx configuration"

    cp -a "${BACKUP_CONFIG}" "${NGINX_ACTIVE}"

    nginx -t >/dev/null 2>&1 || true
    systemctl reload nginx >/dev/null 2>&1 || true

    exit 2
fi

log "nginx reloaded. Waiting for traffic to route to ${TARGET_ENV}."


# ============================================================
# STEP 5 - Verify proxy with retry window
# ============================================================

log "Step 5: Confirming switch via proxy health check..."

SWITCH_CONFIRMED=false
RESPONSE=""

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do

    log "Post-switch health check ${attempt}/${MAX_ATTEMPTS}..."

    RESPONSE="$(
        curl \
            --silent \
            --show-error \
            --fail \
            --max-time 5 \
            http://127.0.0.1:80/health 2>/dev/null
    )" || RESPONSE=""

    if [ -n "${RESPONSE}" ]; then
        log "nginx response: ${RESPONSE}"
    else
        log "nginx response: <no response>"
    fi

    if echo "${RESPONSE}" |
        grep -Eq "\"status\"[[:space:]]*:[[:space:]]*\"ok\"" &&
       echo "${RESPONSE}" |
        grep -Eq "\"port\"[[:space:]]*:[[:space:]]*${TARGET_PORT}([,}])"; then

        SWITCH_CONFIRMED=true
        break
    fi

    if [ "${attempt}" -lt "${MAX_ATTEMPTS}" ]; then
        sleep "${RETRY_DELAY}"
    fi
done


# ============================================================
# Verification failure — restore previous nginx configuration
# ============================================================

if [ "${SWITCH_CONFIRMED}" != "true" ]; then
    log_fail "Traffic did not switch to ${TARGET_ENV}"
    log_fail "Restoring nginx traffic to ${CURRENT_ENV}"

    cp -a "${BACKUP_CONFIG}" "${NGINX_ACTIVE}"

    if nginx -t; then
        systemctl reload nginx || true
    fi

    log_fail "Switch aborted. Active environment state remains ${CURRENT_ENV}"

    exit 3
fi


# ============================================================
# Update state ONLY after successful proxy confirmation
# ============================================================

PREVIOUS_TMP="${PREVIOUS_ENV_STATE}.tmp.$$"
ACTIVE_TMP="${ACTIVE_ENV_STATE}.tmp.$$"

printf '%s\n' "${CURRENT_ENV}" > "${PREVIOUS_TMP}"
printf '%s\n' "${TARGET_ENV}" > "${ACTIVE_TMP}"

chown root:kijanikiosk "${PREVIOUS_TMP}" "${ACTIVE_TMP}"
chmod 640 "${PREVIOUS_TMP}" "${ACTIVE_TMP}"

mv -f "${PREVIOUS_TMP}" "${PREVIOUS_ENV_STATE}"
mv -f "${ACTIVE_TMP}" "${ACTIVE_ENV_STATE}"

log "Post-switch confirmation passed: proxy is routing to ${TARGET_ENV} (port ${TARGET_PORT})"
log "Recorded previous environment: ${CURRENT_ENV}"
log "Active environment recorded as ${TARGET_ENV}"
log "=== Switch to ${TARGET_ENV} complete ==="

exit 0