# Restricted Sudo Policy Analysis

## Objective

The goal of the restricted sudo policy is to implement the principle of least privilege. Amina requires limited operational access to monitor and maintain KijaniKiosk services, but does not require unrestricted root access.

The policy grants permission to:

* Check the status of the kk-api, kk-payments, and kk-logs services.
* Restart the kk-api, kk-payments, and kk-logs services.
* View logs associated with those services.
* Edit the NGINX configuration safely using sudoedit.

The policy intentionally does not grant access to shells, editors, interpreters, package managers, or unrestricted systemctl commands.

---

## Attack Scenario 1: Privilege Escalation Through Unrestricted systemctl

If Amina were granted unrestricted access to:

```bash
sudo systemctl
```

she could modify or create systemd service definitions that execute arbitrary commands as root.

For example:

```bash
sudo systemctl edit ssh
```

could be used to add:

```ini
[Service]
ExecStartPost=/bin/bash -c 'useradd -m attacker && echo "attacker ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/attacker'
```

When the service restarts, the command would execute with root privileges and create a permanent privileged account.

This attack does not require direct shell access. The abuse occurs through the systemd service manager itself.

For this reason, the sudo policy restricts access to specific services and specific subcommands rather than allowing unrestricted use of systemctl.

---

## Attack Scenario 2: Denial of Service Through Service Manipulation

If unrestricted systemctl access were available, an operator could intentionally or accidentally disrupt critical infrastructure.

Examples include:

```bash
sudo systemctl stop nginx
sudo systemctl mask ssh
sudo systemctl disable networking
```

Potential impact:

* NGINX becomes unavailable, causing customer-facing outages.
* SSH access is blocked, preventing remote administration.
* Network services are disabled, affecting application connectivity.

Although these actions do not directly grant root access, they can cause significant service disruption and violate operational change-control requirements.

Restricting systemctl to only approved KijaniKiosk services reduces the blast radius of mistakes and prevents abuse of unrelated system services.

---

## Verification Results

The restricted policy was tested after implementation.

### Authorized Operations

The following commands were successfully authorized:

```bash
sudo systemctl status kk-api
sudo systemctl status kk-payments
sudo systemctl status kk-logs
```

The commands returned:

```text
Unit kk-api.service could not be found.
Unit kk-payments.service could not be found.
Unit kk-logs.service could not be found.
```

This is expected because the services do not exist in the lab environment. The important result is that sudo authorized the commands.

### Blocked Privilege Escalation Attempts

The following commands were denied:

```bash
sudo bash
```

```bash
sudo vim /etc/hosts
```

```bash
sudo python3 -c 'import os; os.system("id")'
```

Each command returned a sudo authorization failure, demonstrating that:

* Root shell access is blocked.
* Arbitrary file editing is blocked.
* Interpreter-based privilege escalation is blocked.

---

## Why the Restricted Policy Is Necessary

The implemented policy provides only the permissions required for operational support activities.

Authorized actions:

* Service status checks.
* Service restarts.
* Service log review.
* Safe editing of the NGINX configuration through sudoedit.

Unauthorized actions:

* Root shell access.
* Arbitrary command execution.
* Use of interpreters such as Python.
* Use of editors such as Vim with root privileges.
* Management of unrelated system services.

This implementation follows the principle of least privilege by granting only the access required for Amina's role while preventing common privilege escalation paths.

