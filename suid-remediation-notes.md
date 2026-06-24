# SUID Remediation Notes

## Why does the kernel ignore SUID on interpreted scripts?

Modern Linux kernels ignore the SUID bit on interpreted scripts (such as Bash scripts beginning with `#!/bin/bash`) because of race condition and privilege escalation risks.

When a user executes a script, the kernel must first open the script and then pass it to the interpreter (for example, Bash). Historically, an attacker could manipulate or replace the script between these steps, causing the interpreter to execute different content with elevated privileges.

To prevent this class of vulnerability, Linux does not honor the SUID bit on scripts. The interpreter runs with the privileges of the calling user rather than the file owner.

## If the SUID bit has no effect on this script, why is SUID + world-write still a critical finding?

Although the SUID bit is ignored by the kernel for shell scripts, the file remains dangerous because it is world-writable.

Any user on the system can modify the contents of the deployment script. If a privileged process such as root, cron, a deployment automation tool, or a CI/CD job later executes that script, the attacker's code will run with elevated privileges.

The risk is therefore not the SUID execution itself but the ability to inject malicious commands into a file that trusted processes execute.

## What would make this scenario exploitable in practice?

This becomes exploitable when a privileged process executes the modified script.

Examples include:

- A root-owned cron job that runs `deploy.sh`.
- A systemd service running as root that executes the script.
- A deployment automation tool executing the script with elevated privileges.
- An administrator manually running the script with sudo.

An attacker could modify the script to:
- Create a new sudo-enabled user.
- Add SSH keys for persistent access.
- Read sensitive files such as `/etc/shadow`.
- Install malware or backdoors.

Because the script would be executed by a privileged process, the malicious commands would inherit those privileges and compromise the system.

## Remediation Applied

- Removed the SUID bit from `deploy.sh`.
- Changed ownership to `root:root`.
- Set permissions to `750`.
- Removed world-write access.
- Verified no remaining SUID files exist under `/opt/kijanikiosk` using:

```bash
sudo find /opt/kijanikiosk -perm -4000 -ls
