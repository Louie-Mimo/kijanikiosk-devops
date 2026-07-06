#!/bin/bash

set -euo pipefail

log() {
    echo "[INFO] $(date '+%F %T') $*"
}

fail() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Must run as root"
    fi
}

verify_ubuntu() {
    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        fail "Ubuntu required"
    fi
}

install_packages() {

    log "=== Phase 1: Packages ==="

    apt update

    apt install -y \
        nginx \
        nodejs \
        ufw \
        acl

    apt-mark hold nginx nodejs
}

apt-cache policy nginx
apt-cache policy nodejs


create_accounts() {

    log "=== Phase 2: Service Accounts ==="

    getent group kijanikiosk >/dev/null || groupadd kijanikiosk

    if ! id kk-api >/dev/null 2>&1; then
        useradd --system \
            --user-group \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --comment "KijaniKiosk API Service" \
            kk-api
    else
        log "Already exists: kk-api"
    fi

    if ! id kk-payments >/dev/null 2>&1; then
        useradd --system \
            --user-group \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --comment "KijaniKiosk Payments Service" \
            kk-payments
    else
        log "Already exists: kk-payments"
    fi

    if ! id kk-logs >/dev/null 2>&1; then
        useradd --system \
            --user-group \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --comment "KijaniKiosk Log Service" \
            kk-logs
    else
        log "Already exists: kk-logs"
    fi
}

configure_filesystem() {

    log "=== Phase 3: Filesystem ==="

    mkdir -p \
        /opt/kijanikiosk/api \
        /opt/kijanikiosk/payments \
        /opt/kijanikiosk/logs \
        /opt/kijanikiosk/config \
        /opt/kijanikiosk/shared/logs

    chown kk-api:kk-api /opt/kijanikiosk/api
    chmod 750 /opt/kijanikiosk/api

    chown kk-payments:kk-payments /opt/kijanikiosk/payments
    chmod 750 /opt/kijanikiosk/payments

    chown kk-logs:kk-logs /opt/kijanikiosk/logs
    chmod 750 /opt/kijanikiosk/logs

    chown root:kijanikiosk /opt/kijanikiosk/config
    chmod 750 /opt/kijanikiosk/config

    chown kk-logs:kk-logs /opt/kijanikiosk/shared/logs
    chmod 2770 /opt/kijanikiosk/shared/logs

    setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
    setfacl -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs

    setfacl -m u:$(logname):r-x /opt/kijanikiosk/config
    setfacl -m u:$(logname):r-x /opt/kijanikiosk/shared/logs
}

install_service() {

    log "=== Phase 4: Systemd ==="

    cat >/etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API
After=network.target

[Service]
User=kk-api
Group=kk-api

EnvironmentFile=-/opt/kijanikiosk/config/api.env

ExecStart=/usr/bin/node /opt/kijanikiosk/api/server.js

Restart=on-failure
RestartSec=5

StartLimitIntervalSec=60
StartLimitBurst=3

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict

LockPersonality=true
MemoryDenyWriteExecute=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable kk-api.service
}

configure_firewall() {

    log "=== Phase 5: Firewall ==="

    ufw --force reset

    ufw default deny incoming

    ufw default allow outgoing

    ufw allow 22/tcp

    ufw allow 80/tcp

    ufw --force enable
}

verify_configuration() {

    log "=== Phase 6: Verification ==="

    id kk-api >/dev/null
    id kk-payments >/dev/null
    id kk-logs >/dev/null

    systemctl is-enabled kk-api.service >/dev/null

    apt-mark showhold | grep nginx >/dev/null

    apt-mark showhold | grep nodejs >/dev/null

    ufw status | grep "22/tcp" >/dev/null

    ufw status | grep "80/tcp" >/dev/null

    log "Verification passed"
}

main() {

    require_root

    verify_ubuntu

    install_packages

    create_accounts

    configure_filesystem

    install_service

    configure_firewall

    verify_configuration

    log "Provisioning complete"
}

main "$@"

