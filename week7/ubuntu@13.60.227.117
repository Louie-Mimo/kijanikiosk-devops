#!/usr/bin/env bash

set -euo pipefail

ACTIVE_ENV_STATE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_STATE="/opt/kijanikiosk/.previous-env"
NGINX_ACTIVE="/etc/nginx/kijanikiosk-active-env.conf"

TARGET_ENV="${1:-}"

log() {
    echo "[$(date -u +%H:%M:%S)] [SWITCH] $*"
}

log_fail() {
    echo "[$(date -u +%H:%M:%S)] [SWITCH FAIL] $*" >&2
}

# ------------------------------------------------------------
# Validate argument
# ------------------------------------------------------------

if [ "${TARGET_ENV}" != "blue" ] && [ "${TARGET_ENV}" != "green" ]; then
    log_fail "Usage: $0 blue|green"
    exit 1
fi

# ------------------------------------------------------------
# Determine current environment
# ------------------------------------------------------------

if [ ! -f "${ACTIVE_ENV_STATE}" ]; then
    log_fail "Active environment state file does not exist"
    exit 1
fi

CURRENT_ENV=$(cat "${ACTIVE_ENV_STATE}")

if [ "${CURRENT_ENV}" != "blue" ] && [ "${CURRENT_ENV}" != "green" ]; then
    log_fail "Invalid current environment: ${CURRENT_ENV}"
    exit 1
fi

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"

# ------------------------------------------------------------
# Already on target?
# ------------------------------------------------------------

if [ "${CURRENT_ENV}" = "${TARGET_ENV}" ]; then
    log "Already on ${TARGET_ENV}. Nothing to switch."
    exit 0
fi

# ------------------------------------------------------------
# Determine target port
# ------------------------------------------------------------

if [ "${TARGET_ENV}" = "blue" ]; then
    TARGET_PORT=3000
    TARGET_SERVICE="kk-api-blue.service"
else
    TARGET_PORT=3001
    TARGET_SERVICE="kk-api-green.service"
fi

# ------------------------------------------------------------
# Pre-condition: target service must be running
# ------------------------------------------------------------

log "Checking ${TARGET_SERVICE}..."

if ! systemctl is-active --quiet "${TARGET_SERVICE}"; then
    log_fail "${TARGET_SERVICE} is not running"
    exit 1
fi

# ------------------------------------------------------------
# Pre-condition: target health endpoint
# ------------------------------------------------------------

log "Checking target health on port ${TARGET_PORT}..."

HEALTH_RESPONSE=$(curl -sf --max-time 5 \
    "http://127.0.0.1:${TARGET_PORT}/health") || {
        log_fail "Target ${TARGET_ENV} health check failed"
        exit 1
    }

log "Target health: ${HEALTH_RESPONSE}"

# ------------------------------------------------------------
# Build new nginx configuration
# ------------------------------------------------------------

if [ "${TARGET_ENV}" = "blue" ]; then
    TARGET_UPSTREAM="kk-api-blue"
else
    TARGET_UPSTREAM="kk-api-green"
fi

TMP_CONFIG=$(mktemp)

cat > "${TMP_CONFIG}" <<EOF
location / {
    proxy_pass         http://${TARGET_UPSTREAM};
    proxy_http_version 1.1;
    proxy_set_header   Host \$host;
    proxy_cache_bypass \$http_upgrade;
}

location /health {
    proxy_pass http://${TARGET_UPSTREAM};
}
EOF

# ------------------------------------------------------------
# Install temporary configuration
# ------------------------------------------------------------

cp "${TMP_CONFIG}" "${NGINX_ACTIVE}.new"
rm -f "${TMP_CONFIG}"

# ------------------------------------------------------------
# Validate nginx BEFORE changing active configuration
# ------------------------------------------------------------

log "Validating nginx configuration..."

if ! nginx -t; then
    log_fail "nginx configuration validation failed"
    rm -f "${NGINX_ACTIVE}.new"
    exit 2
fi

# ------------------------------------------------------------
# Record previous environment
# ------------------------------------------------------------

echo "${CURRENT_ENV}" > "${ACTIVE_ENV_STATE}.previous"
mv "${ACTIVE_ENV_STATE}.previous" "${PREVIOUS_ENV_STATE}"

log "Recorded previous environment: ${CURRENT_ENV}"

# ------------------------------------------------------------
# Atomically replace active nginx configuration
# ------------------------------------------------------------

mv "${NGINX_ACTIVE}.new" "${NGINX_ACTIVE}"

log "Active nginx configuration updated to ${TARGET_ENV}"

# ------------------------------------------------------------
# Reload nginx
# ------------------------------------------------------------

log "Reloading nginx..."

if ! nginx -s reload; then
    log_fail "nginx reload failed"
    exit 2
fi

# ------------------------------------------------------------
# Update active state
# ------------------------------------------------------------

echo "${TARGET_ENV}" > "${ACTIVE_ENV_STATE}"

log "Active environment recorded as ${TARGET_ENV}"

# ------------------------------------------------------------
# Verify traffic actually switched
# ------------------------------------------------------------

log "Verifying nginx traffic..."

RESPONSE=$(curl -sf --max-time 5 http://127.0.0.1/health) || {
    log_fail "nginx health check failed after switch"
    exit 3
}

log "nginx response: ${RESPONSE}"

if ! echo "${RESPONSE}" | grep -q "\"port\":${TARGET_PORT}"; then
    log_fail "Traffic did not switch to ${TARGET_ENV}"
    exit 3
fi

log "Traffic successfully switched to ${TARGET_ENV}"

exit 0
