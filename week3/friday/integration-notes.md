# Integration Notes

## Challenge A: ProtectSystem=strict and the EnvironmentFile

### Conflict

The services were configured with `ProtectSystem=strict` to reduce the ability of a compromised process to modify the operating system. At the same time, each service required an `EnvironmentFile` containing configuration values.

A potential issue existed because configuration files created earlier in the week could have been stored in locations affected by the filesystem protections applied by systemd.

### Options Considered

1. Store configuration files under a system path and relax service protections.
2. Keep strict filesystem protections and relocate configuration files to a dedicated application configuration directory.
3. Use additional write exceptions through systemd directives.

### Decision

Configuration files were stored under:

```text
/opt/kijanikiosk/config
```

Each unit file references its configuration through an `EnvironmentFile` directive while maintaining `ProtectSystem=strict`.

### Verification

Verified that:

- kk-payments.service starts successfully
- EnvironmentFile loads correctly
- The service account can read payments-api.env
- ProtectSystem=strict remains enabled

No ReadWritePaths or additional exceptions were required.

### Reasoning

This approach preserves service hardening while keeping configuration management simple. The service only requires read access to configuration files and does not need write access. Verification was performed by reading the configuration as the service account before enabling the service.

### Result

The services successfully access configuration data while retaining filesystem protection controls.

---

## Challenge B: Monitoring User and ACL Defaults

### Conflict

The Friday requirements introduced a new health-check mechanism that writes a JSON status file. The provisioning script runs as root, which means any generated file would normally be owned by root.

The monitoring process and operational users needed access to this information without requiring administrative privileges.

### Options Considered

1. Leave files owned by root and require sudo access.
2. Make the health directory world-readable.
3. Create a dedicated ownership and permission model aligned with the existing access design.

### Decision

A dedicated health directory was created:

```text
/opt/kijanikiosk/health
```

Ownership:

```text
kk-logs:kijanikiosk
```

Directory permissions:

```text
750
```

Health file permissions:

```text
640
```

### Reasoning

The logging service is responsible for operational observability, making it the appropriate owner. Group ownership allows authorized service accounts and administrators to read status information without exposing it to all users.

### Result

The health-check file is generated successfully and is readable by authorized service accounts while remaining protected from unauthorized access.

---

## Challenge C: Logrotate Postrotate and PrivateTmp

### Conflict

Log rotation requires services to reopen log file handles after a rotation event. The common pattern is to execute a reload operation in a postrotate block.

However, services configured with `PrivateTmp=true` and no explicit reload support may not respond correctly to a reload request.

### Options Considered

1. Use `systemctl reload`.
2. Add an `ExecReload` directive to every service.
3. Restart the logging service after rotation.

### Decision

The configuration was evaluated to determine whether reload support existed. Because the logging service did not implement a dedicated reload mechanism, a restart operation was selected for postrotate processing.

### Reasoning

A restart is more reliable than a reload for a service that does not explicitly support configuration reloading. The restart operation guarantees that file handles are reopened and that logging continues after rotation.

### Result

Log rotation completes successfully and log access remains functional after rotation. Verification included a forced rotation followed by a write test using the service account.

---

## Challenge D: The Dirty VM and Package Holds

### Conflict

The environment had already been used throughout the week. Packages were installed, service accounts existed, permissions had been modified manually, and package holds were already present.

Blindly reinstalling pinned package versions could trigger unexpected downgrades or modify a known-good state.

### Options Considered

1. Always force installation of the pinned version.
2. Automatically downgrade packages when a mismatch is detected.
3. Check installed versions and fail if the state differs from the expected baseline.

### Decision

The provisioning process validates installed package versions before attempting installation. If the expected version is already present, installation is skipped and the existing package hold is maintained.

### Reasoning

Production infrastructure should not perform unexpected downgrades without operator approval. Failing loudly is safer than silently changing package versions on a system that may already be in service.

This approach also supports idempotency because repeated runs converge on the same desired state without unnecessary package operations.

### Result

The provisioning script safely handles previously configured systems while preserving package version integrity and maintaining predictable behaviour across repeated executions.

---

## Summary

The primary challenge of the production foundation project was not configuring individual components but ensuring they worked together without creating unintended side effects. Each integration challenge required balancing security, operability, and maintainability. The final design preserves least privilege, supports monitoring and log management, maintains strong service hardening, and remains safe to run repeatedly on a partially configured production system.
