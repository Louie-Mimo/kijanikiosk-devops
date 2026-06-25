# kk-payments Hardening Analysis

## Objective

The kk-payments service processes payment-related data and therefore requires a stronger security posture than the other application services. The target for this project was an exposure score below 2.5 while maintaining a functional and maintainable service configuration.

---

## Initial State

The first version of the service used only the baseline hardening controls from Wednesday:

* User=kk-payments
* Group=kk-payments
* NoNewPrivileges=true
* PrivateTmp=true
* ProtectSystem=strict

Initial security analysis:

```text
Overall exposure level: approximately 6.7 (MEDIUM)
```

This score was above the production target and indicated that additional controls were required.

---

## Hardening Process

### Step 1: LockPersonality=true

Directive added:

```ini
LockPersonality=true
```

Purpose:

Prevents the service from changing its execution personality or ABI behaviour.

Result:

The score improved and removed an unnecessary attack surface.

---

### Step 2: MemoryDenyWriteExecute=true

Directive added:

```ini
MemoryDenyWriteExecute=true
```

Purpose:

Prevents creation of memory regions that are simultaneously writable and executable.

Reasoning:

This mitigates a common exploitation technique used by memory corruption attacks.

Result:

Further reduction in overall exposure score.

---

### Step 3: RestrictAddressFamilies

Directive added:

```ini
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
```

Purpose:

Limits the network socket types the service can create.

Reasoning:

The payments service only requires normal TCP/IP and local UNIX socket communication.

Result:

Reduced the attack surface associated with unnecessary networking capabilities.

---

### Step 4: SystemCallFilter

Directive added:

```ini
SystemCallFilter=@system-service
```

Purpose:

Restricts available kernel system calls to the standard set expected by typical services.

Reasoning:

Many attacks rely on unusual system calls. Restricting them reduces the options available to an attacker.

Result:

Significant improvement in hardening score.

---

### Step 5: CapabilityBoundingSet

Directive added:

```ini
CapabilityBoundingSet=
AmbientCapabilities=
```

Purpose:

Removes Linux capabilities that would otherwise be available to the service.

Reasoning:

The payments application does not require elevated kernel privileges.

Result:

Further reduction in exposure score.

---

### Step 6: ProtectKernelTunables

Directive added:

```ini
ProtectKernelTunables=true
```

Purpose:

Prevents modification of kernel configuration interfaces.

Reasoning:

The service should never alter kernel runtime settings.

Result:

Improved overall security posture.

---

## Additional Controls Applied

The final configuration also includes:

```ini
PrivateDevices=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectClock=true
RestrictNamespaces=true
RemoveIPC=true
```

These controls collectively:

* Prevent access to hardware devices.
* Block modification of control groups.
* Restrict kernel log access.
* Prevent kernel module interaction.
* Protect system time settings.
* Prevent namespace creation.
* Clean up IPC resources automatically.

---

## Directives Investigated but Not Applied

### RootDirectory=

Purpose:

Runs the service inside a dedicated filesystem root.

Reason Not Selected:

The service currently relies on the existing application directory structure and configuration paths. Introducing a separate root filesystem would significantly increase operational complexity without providing proportional security benefit for this environment.

---

### RootImage=

Purpose:

Runs the service from a dedicated filesystem image.

Reason Not Selected:

This approach is more appropriate for highly isolated production workloads or container-style deployments. The added complexity was not justified for the current staging and foundation requirements.

---

## Final Unit File

```ini
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
User=kk-payments
Group=kk-payments

EnvironmentFile=-/opt/kijanikiosk/config/payments-api.env

ExecStart=/usr/bin/node /opt/kijanikiosk/payments/server.js

Restart=on-failure
RestartSec=5

StartLimitIntervalSec=60
StartLimitBurst=3

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectClock=true

RestrictNamespaces=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

LockPersonality=true
MemoryDenyWriteExecute=true

SystemCallFilter=@system-service

CapabilityBoundingSet=
AmbientCapabilities=

RemoveIPC=true

[Install]
WantedBy=multi-user.target
```

---

## Final Result

Final command:

```bash
sudo systemd-analyze security kk-payments.service
```

Result:

```text
Overall exposure level: 1.9 OK
```

This exceeds the project requirement of a score below 2.5 while maintaining a functional service configuration.

---

## Conclusion

The hardening process focused on reducing unnecessary privileges, limiting filesystem access, restricting networking and kernel interactions, and preventing common privilege-escalation techniques. The final configuration achieved a security score of 1.9 while preserving service functionality and maintainability.

