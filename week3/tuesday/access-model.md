# KijaniKiosk Access Control Model

## Access Design Table

| Path                         | Owner       | Group       | Mode                     | Additional Controls          | Reasoning                                                                                                                                                                             |
| ---------------------------- | ----------- | ----------- | ------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| /opt/kijanikiosk/api         | kk-api      | kk-api      | 750                      | None                         | Only the API service should access its application files. Group members may read/execute but other users are denied access.                                                           |
| /opt/kijanikiosk/payments    | kk-payments | kk-payments | 750                      | None                         | Payment processing contains sensitive business logic and must be isolated from other services.                                                                                        |
| /opt/kijanikiosk/logs        | kk-logs     | kk-logs     | 750                      | None                         | Log aggregation service manages its own data and should not be accessible to unrelated services.                                                                                      |
| /opt/kijanikiosk/config      | root        | kijanikiosk | Directory 750, Files 640 | ACL for administrator access | Configuration files contain database credentials and API secrets. Root ownership prevents service accounts from modifying them while the shared group permits controlled read access. |
| /opt/kijanikiosk/shared/logs | kk-logs     | kk-logs     | 2770                     | ACLs applied                 | Shared logging area requires access by multiple services. SGID ensures newly created files inherit the correct group ownership.                                                       |

## ACL Decisions

### kk-api → Shared Logs (Read/Write)

The API service writes application logs into the shared logging location. Standard Unix permissions cannot grant write access to a second service account without broadening permissions unnecessarily. ACLs provide targeted access.

### kk-payments → Shared Logs (Read)

The payments service needs visibility into aggregated logs but does not require modification rights. ACLs allow read-only access without changing ownership.

### Administrative User (louiemimo)

The administrator requires read access to configuration files and logs for troubleshooting and auditing purposes. ACLs grant visibility without granting ownership or write access.

## Why ACLs Instead of Basic Permissions

Traditional Unix permissions provide only one owner and one group. Multiple service accounts require different levels of access to the same resources. ACLs enable least-privilege access while maintaining service isolation.

## Security Outcomes

* Service processes no longer run with unnecessary privileges.
* Secrets are protected from unauthorized users.
* Cross-service access is restricted.
* Shared resources remain manageable through explicit ACL assignments.
* Ownership and permissions align with least-privilege principles.
