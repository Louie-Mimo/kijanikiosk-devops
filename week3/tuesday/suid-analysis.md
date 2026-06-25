# SUID Misconfiguration Analysis

## Why does Linux ignore SUID on interpreted scripts?

Linux disables SUID behavior on interpreted scripts because of race-condition vulnerabilities.

When a script is executed, the kernel must first launch the interpreter (such as bash or python) and then pass the script file to it. Historically, attackers could exploit timing gaps between these actions by replacing or modifying the script after the privilege check but before execution.

To eliminate this class of vulnerability, modern Linux kernels ignore SUID bits on scripts and apply SUID only to compiled binaries.

## If SUID is ignored, why is SUID plus world-write still a critical finding?

Although the SUID bit itself has no effect on the script, the file remains dangerous because it is writable by any user.

The deployment script was executed by a root-owned automated process. Any user could modify the script contents and inject commands. When the privileged automation executed the script, the malicious commands would run as root.

The real risk is not the SUID bit itself but the combination of:

* Root ownership
* Automated privileged execution
* World-writable permissions

Together these create an indirect privilege escalation path.

## What would make this scenario exploitable in practice?

Several conditions could make exploitation possible:

### Root-Owned Cron Job

If cron executes the script as root:

```bash
* * * * * root /opt/kijanikiosk/scripts/deploy.sh
```

an attacker can modify the script and wait for execution.

### CI/CD Pipeline

A deployment pipeline running with elevated privileges could execute the modified script during deployment.

### Administrative Automation

Configuration-management systems or operational scripts running as root could invoke the file and execute attacker-controlled commands.

## Remediation Performed

* Removed SUID bit.
* Removed world-write permissions.
* Set ownership to root:root.
* Set permissions to 750.
* Verified no remaining SUID files in /opt/kijanikiosk.

Result: No untrusted user can modify the deployment script and no privilege-escalation path remains.
