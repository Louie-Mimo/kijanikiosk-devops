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

    verify_package_versions
    apt update

    apt install -y \
        nginx \
        nodejs \
        ufw \
        acl

    apt-mark hold nginx nodejs
}

verify_package_versions() {

    local nginx_version
    local nodejs_version

    nginx_version="$(dpkg-query -W -f='${Version}' nginx 2>/dev/null || true)"
    nodejs_version="$(dpkg-query -W -f='${Version}' nodejs 2>/dev/null || true)"

    local expected_nginx="1.24.0-2ubuntu7.13"
    local expected_nodejs="18.19.1+dfsg-6ubuntu5"

    if [[ -n "$nginx_version" && "$nginx_version" != "$expected_nginx" ]]; then
        fail "nginx version drift detected. Expected ${expected_nginx}, found ${nginx_version}. Manual intervention required."
    fi

    if [[ -n "$nodejs_version" && "$nodejs_version" != "$expected_nodejs" ]]; then
        fail "nodejs version drift detected. Expected ${expected_nodejs}, found ${nodejs_version}. Manual intervention required."
    fi
}

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

    setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
    setfacl -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs

    setfacl -d -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
    setfacl -d -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
    
    setfacl -m u:$(logname):r-x /opt/kijanikiosk/config
    setfacl -m u:$(logname):r-x /opt/kijanikiosk/shared/logs
}

install_service() {

    log "=== Phase 4: Systemd ==="

    cat >/etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API
After=network.target

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=kk-api
Group=kk-api

EnvironmentFile=/opt/kijanikiosk/config/api.env

ExecStart=/usr/bin/sleep infinity

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true

RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

SystemCallArchitectures=native
SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kk-payments.service <<'EOF'
[Unit]
Description=KijaniKiosk Payments
After=network.target kk-api.service
Wants=kk-api.service

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=kk-payments
Group=kk-payments

EnvironmentFile=/opt/kijanikiosk/config/payments-api.env

ExecStart=/usr/bin/sleep infinity

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true

RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

SystemCallArchitectures=native
SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

   cat >/etc/systemd/system/kk-logs.service <<'EOF'
[Unit]
Description=KijaniKiosk Logs
After=network.target

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=kk-logs
Group=kk-logs

EnvironmentFile=/opt/kijanikiosk/config/logs.env

ExecStart=/usr/bin/sleep infinity

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true

RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX

SystemCallArchitectures=native
SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kk-logs.service <<'EOF'
[Unit]
Description=KijaniKiosk Logs
After=network.target

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=kk-logs
Group=kk-logs

EnvironmentFile=/opt/kijanikiosk/config/logs.env

ExecStart=/usr/bin/sleep infinity

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true

RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX

SystemCallArchitectures=native
SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/kk-logs.service <<'EOF'
[Unit]
Description=KijaniKiosk Logs
After=network.target

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=kk-logs
Group=kk-logs

EnvironmentFile=/opt/kijanikiosk/config/logs.env

ExecStart=/usr/bin/sleep infinity

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=true

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true

RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX

SystemCallArchitectures=native
SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable kk-api.service
    systemctl enable kk-payments.service
    systemctl enable kk-logs.service
}

configure_firewall() {

    log "=== Phase 5: Firewall ==="

    ufw --force reset

    ufw default deny incoming
    ufw default allow outgoing

    ufw allow 22/tcp comment 'SSH administration'

    ufw allow 80/tcp comment 'Public web traffic'

    ufw allow in on lo to any port 3001 proto tcp \
        comment 'Local nginx proxy access'

    ufw allow from 10.0.1.0/24 \
        to any port 3001 proto tcp \
        comment 'Monitoring subnet health checks'

    ufw deny 3001/tcp \
        comment 'Block external access to internal service'

    ufw --force enable
}

verify_firewall() {

    local failed=0
    local status

    status="$(ufw status)"

    echo "$status" | grep -q "22/tcp.*ALLOW" \
    	&& echo "PASS: SSH rule present" \
    	|| { echo "FAIL: SSH rule missing"; ((failed++)); }

   echo "$status" | grep -q "80/tcp.*ALLOW" \
   	 && echo "PASS: HTTP rule present" \
    	 || { echo "FAIL: HTTP rule missing"; ((failed++)); }

   echo "$status" | grep -q "3001/tcp on lo" \
        && echo "PASS: Loopback allow present" \
        || { echo "FAIL: Loopback allow missing"; ((failed++)); }
 
   echo "$status" | grep -q "10.0.1.0/24" \
   	 && echo "PASS: Monitoring subnet allow present" \
    	 || { echo "FAIL: Monitoring subnet allow missing"; ((failed++)); }

   echo "$status" | grep -q "3001/tcp.*DENY" \
        && echo "PASS: External deny present" \
        || { echo "FAIL: External deny missing"; ((failed++)); }

    [[ $failed -eq 0 ]] || fail "$failed firewall verification check(s) failed"
}

verify_configuration() {

    log "=== Phase 6: Verification ==="

    id kk-api >/dev/null
    id kk-payments >/dev/null
    id kk-logs >/dev/null

    systemctl is-enabled kk-api.service >/dev/null

    apt-mark showhold | grep nginx >/dev/null

    apt-mark showhold | grep nodejs >/dev/null

    verify_firewall

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

