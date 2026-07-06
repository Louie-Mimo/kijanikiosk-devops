# KijaniKiosk Infrastructure Hardening Decisions

## Purpose

This document explains the security decisions made while building the KijaniKiosk staging infrastructure. It is written to support discussions with non-technical stakeholders by describing what protections were added, why they matter, and which risks still remain. The goal is not to eliminate every possible threat, but to reduce the likelihood that common mistakes or attacks can compromise the staging environment while keeping the infrastructure repeatable through Infrastructure as Code.

Terraform provisions the infrastructure while Ansible applies a consistent server configuration. Together they ensure that every deployment follows the same security baseline rather than relying on manual configuration.

## Security Controls

| Control | What it does | Risk mitigated |
|---------|--------------|----------------|
| Restricted SSH access | Allows administrative access only from approved network ranges instead of the public internet. | Reduces the likelihood of unauthorized login attempts and automated scanning. |
| Security groups | Filters inbound and outbound network traffic so only required services are reachable. | Limits unnecessary network exposure and reduces the attack surface. |
| Managed SSH key pairs | Uses trusted cryptographic keys for administrator authentication instead of passwords. | Protects against password guessing and credential theft. |
| Remote Terraform state | Stores infrastructure state in centralized object storage rather than individual developer machines. | Prevents configuration drift, improves collaboration, and protects infrastructure records. |
| Terraform variables | Separates environment-specific settings from infrastructure logic. | Reduces configuration errors and accidental deployment into incorrect environments. |
| systemd service sandboxing | Restricts what application services can access on the operating system. | Limits the impact if an application process becomes compromised. |
| Dedicated service accounts | Runs each application component using its own identity with limited permissions. | Prevents one compromised service from affecting unrelated components. |
| Persistent logging and log rotation | Preserves operational logs while automatically managing storage growth. | Improves incident investigation and prevents excessive disk consumption. |

## Why These Decisions Matter

The infrastructure was designed so that every deployment is repeatable and produces the same security posture regardless of who performs it. By defining infrastructure in Terraform, security settings become part of the version-controlled codebase instead of depending on manual configuration. This reduces human error and makes every change reviewable before deployment.

Network protection begins by limiting administrative access to approved locations rather than exposing management interfaces broadly. Combined with network filtering rules, this significantly reduces opportunities for unauthorized access while still allowing legitimate maintenance activities.

Application services are also isolated from one another. Each service operates with only the permissions necessary to perform its role, following the principle of least privilege. If one application were compromised, these restrictions help prevent the attacker from moving freely across the system or modifying unrelated services.

Service sandboxing provides another important layer of protection. Rather than allowing unrestricted access to operating system resources, the runtime environment limits which capabilities are available to each application. This helps contain the impact of software vulnerabilities by preventing unnecessary access to sensitive resources.

Infrastructure consistency is equally important. Every server receives the same baseline configuration through automation, eliminating differences that often appear when systems are configured manually. Consistent deployments simplify troubleshooting, reduce configuration drift, and improve confidence that security controls remain in place after future changes.

Centralized infrastructure state further improves operational reliability by providing a shared source of truth for infrastructure resources. Team members work from the same infrastructure definition, reducing the chance of conflicting updates or accidental resource duplication.

Operational visibility is strengthened through persistent logging. Retaining service logs while automatically managing storage usage supports troubleshooting, compliance activities, and incident response without creating unnecessary operational overhead.

Finally, separating environment-specific values from infrastructure logic improves maintainability. Changes such as deployment region, instance type, or network configuration can be made without modifying the underlying infrastructure definitions, reducing the risk of introducing accidental security regressions.

## Security Assessment

The `kk-payments` service was evaluated using the built-in system security analysis tool after deployment.

**Security score:** **Overall exposure level for kk-payments.service:1.8 OK 🙂**

This score confirms that the service meets the project requirement of an exposure level below **2.5**, demonstrating that strong service isolation and runtime hardening have been successfully applied while allowing the application to operate normally.

## Current Limitations

Although the environment has a strong security baseline, it does not protect against every possible threat. The current implementation does not include centralized identity management, automated secret rotation, vulnerability scanning, intrusion detection, or continuous compliance monitoring. Encryption of application data beyond the infrastructure layer is also outside the scope of this project.

The remote Terraform backend improves collaboration, but production deployments would additionally use a dedicated state-locking mechanism to prevent simultaneous infrastructure updates by multiple engineers. High availability, disaster recovery, and continuous security monitoring would also be important additions before deploying this architecture into a production environment.

Overall, the completed pipeline demonstrates that secure infrastructure can be defined, deployed, and reproduced consistently through Infrastructure as Code while providing a solid foundation for future CI/CD automation.
