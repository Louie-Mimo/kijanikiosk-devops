# Reflection

## 1. At what point during the project did you discover that two requirements conflicted? Describe the conflict and what you learned from resolving it.

I encountered the conflict while hardening the `kk-payments` systemd service. After adding `ProtectSystem=strict` and updating the `EnvironmentFile` location to `/opt/kijanikiosk/config/payments-api.env`, the service failed to start because the expected environment file did not exist. The hardening requirement reduced the service's access to the filesystem, while the service configuration still depended on an external configuration file being present. Resolving this required making the directory structure, the `EnvironmentFile` path, and the Ansible playbook consistent so that the configuration directory and environment file were created before the service started. I learned that security hardening cannot be treated independently from deployment automation; every dependency introduced by the application must be explicitly provisioned by the infrastructure code.

## 2. The hardening decisions document is written for Nia. Rewrite one sentence from it in the technical language you would use if writing it for Tendo instead. What is lost and what is gained in the translation?

For Nia, I wrote that enabling `ProtectSystem=strict` "prevents the service from modifying important operating system files, reducing the impact of a compromised process."

For Tendo, I would write: "`ProtectSystem=strict` remounts most of the filesystem read-only within the service's mount namespace, limiting write access to explicitly permitted paths and reducing post-compromise persistence opportunities."

The version for Nia emphasizes the practical security benefit without requiring knowledge of systemd internals. The version for Tendo is more precise about the implementation and security model, but it assumes familiarity with concepts such as mount namespaces and filesystem isolation.

## 3. Looking at the full pipeline (Terraform plus Ansible plus pipeline.sh): what is the single most fragile handoff? What would you need to know about the target environment to make that handoff robust?

The most fragile handoff is the transition from Terraform to Ansible through the dynamically generated inventory. Terraform successfully creates infrastructure, but Ansible depends on accurate instance IP addresses, SSH connectivity, correct host variables, and the expected filesystem layout. A small difference in the target environment—such as different security group rules, another Linux distribution, a different default SSH user, or missing directories—can cause configuration to fail even though infrastructure provisioning succeeded. To make this handoff more robust, I would need to know the target operating system, SSH authentication method, network and firewall policies, required filesystem layout, and any environment-specific configuration files so the pipeline can validate these assumptions before running the playbook.
