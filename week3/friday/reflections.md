## Reflection

### 1. At what point during the project did you discover that two requirements were in conflict? Describe the conflict and what you learned from resolving it.

The clearest conflict emerged during the logrotate integration testing. The access model required `kk-api` to continue writing logs after rotation, while logrotate creates replacement files with ownership and permissions defined by its `create` directive. My initial tests showed that `kk-api` could write to the log directory but could not write to the newly created `app.log` after rotation because the file ownership and ACLs did not match the intended access model. Resolving the issue required looking beyond the individual requirements and testing how they interacted. I learned that validating components in isolation is not enough; production reliability depends on verifying that security controls, file permissions, and operational processes continue to work together after state changes such as log rotation.

### 2. The hardening decisions document is written for Nia. Rewrite one sentence from that document in the technical language you would use if writing it for Tendo instead. What is lost and what is gained in the translation?

For Nia, I wrote: "Services were restricted so that a compromise in one component cannot easily be used to modify the operating system or interfere with other services."

For Tendo, I would write: "The unit files use `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`, `NoNewPrivileges=true`, namespace restrictions, and kernel protection directives to reduce the attack surface and limit privilege escalation opportunities."

The business-oriented version communicates risk and outcome without requiring platform knowledge. The technical version is more precise because it identifies the exact controls implemented, but it assumes familiarity with systemd hardening concepts. What is gained is implementation detail and auditability; what is lost is accessibility for a non-technical audience.

### 3. Looking at the provisioning script as a whole: what is the single most fragile part of it, the part most likely to fail in a real production environment that differs slightly from your test VM? What would you need to know about the target environment to make that part robust?

The most fragile part of the script is package version management. The script assumes specific package versions and repository behaviour that matched the training environment. During testing I encountered version drift where the installed nginx package differed from the originally expected version because security updates had been applied. In a real production environment, repository configuration, update policies, operating system release levels, and internal package mirrors can vary significantly. To make this robust, I would need to know the organisation's approved package sources, patching policy, supported operating system versions, and whether package versions should be pinned exactly or tracked within an approved update stream. With that information, version validation could be aligned to operational policy rather than assumptions from a single VM.
