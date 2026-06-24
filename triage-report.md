# KijaniKiosk API Server - Triage Report

**Date:** 2026-06-25
**Investigated by:** Louie Mimo
**Server:** DESKTOP-8SO5PEE (WSL Ubuntu)
**Incident Start (Approximate):** 2024-01-15 04:07 UTC (based on application log evidence)

## Summary

The investigation identified a simulated Python process consuming approximately 524 MB of memory, making it the largest memory consumer on the system. Application logs show a progression from database connection pool saturation to connection pool exhaustion, query timeouts, and ultimately database connection failures. Disk space was not critically constrained, but a large log file under `/var/log/kijanikiosk` suggests a log rotation issue. The most likely root cause of the latency increase is database connectivity degradation beginning around 04:07, with memory pressure and log growth acting as contributing factors.

## Process and Resource State

### Top Memory Consumers

| PID  | Process                     | Memory Usage       |
| ---- | --------------------------- | ------------------ |
| 2825 | python3 memory consumer     | 524 MB RSS (14.3%) |
| 213  | unattended-upgrade-shutdown | 23 MB RSS          |
| 53   | systemd-journald            | 20 MB RSS          |

### Top CPU Consumers

| PID    | Process                 | CPU Usage |
| ------ | ----------------------- | --------- |
| 2825   | python3 memory consumer | 0.4%      |
| Others | System services         | Near 0%   |

### Memory Health

System memory was not exhausted at the time of investigation:

* Total RAM: 3.5 GiB
* Used: 977 MiB
* Free: 2.4 GiB
* Available: 2.5 GiB
* Swap Usage: 0 B

### Process State Findings

* No zombie (Z) processes detected.
* No processes observed in uninterruptible sleep (D) state.
* No unusually high CPU utilization detected.
* Python process PID 2825 was the dominant memory consumer and appears intentionally created to simulate memory pressure.

### Open File Descriptors

No abnormal file descriptor consumption was observed. The highest count belonged to systemd (31 descriptors).

## Filesystem and Disk

### Disk Utilization

| Filesystem       | Usage |
| ---------------- | ----- |
| Root (`/`)       | 1%    |
| Windows C: mount | 80%   |

No Linux partition exceeded 80% utilization.

### Largest Log Directories

| Path                 | Size   |
| -------------------- | ------ |
| /var/log/journal     | 324 MB |
| /var/log/kijanikiosk | 271 MB |
| /var/log/syslog      | 2.0 MB |

### Suspicious Files

The `/var/log/kijanikiosk` directory consumed 271 MB, significantly larger than other application-specific logs.

Evidence suggests a log rotation failure or orphaned access log:

* Large file: `access.log.1`
* Generated size approximately 200+ MB

This file is not currently causing disk exhaustion but represents operational debt and could become problematic if growth continues.

## Log Analysis

### Timeline of Significant Events

| Time     | Event                                         |
| -------- | --------------------------------------------- |
| 03:45:10 | Database connection pool reached 85% capacity |
| 04:01:33 | Database connection pool reached 94% capacity |
| 04:07:55 | Connection pool exhausted                     |
| 04:08:01 | Query timeout: orders query                   |
| 04:08:01 | Query timeout: products query                 |
| 04:09:12 | Memory usage warning (87%)                    |
| 06:22:18 | Database connection refused                   |
| 06:22:23 | Database connection refused                   |
| 06:22:28 | Retry limit reached                           |

### Error Frequency Summary

| Error Type                 | Count |
| -------------------------- | ----- |
| Query timeout              | 2     |
| ECONNREFUSED               | 2     |
| Database capacity warnings | 2     |
| Connection pool exhausted  | 1     |
| Memory warning             | 1     |
| Retry limit reached        | 1     |

### Pattern Analysis

The errors show a clear escalation pattern:

1. Database connection pool utilization increased steadily.
2. Connection pool became exhausted.
3. Application queries began timing out.
4. Memory pressure warning appeared shortly afterward.
5. Database connectivity ultimately failed with repeated ECONNREFUSED errors.

No evidence of OOM killer events, disk I/O failures, or authentication anomalies was found in system logs.

## Network and Service State

### Listening Services

Observed listening ports:

| Port | Service      |
| ---- | ------------ |
| 80   | NGINX HTTP   |
| 53   | DNS Resolver |

### Missing Expected Services

The following expected application/service ports were not listening:

* 3000
* 8080
* 5432 (PostgreSQL)

The absence of port 5432 aligns with the database connection errors observed in the application logs.

### HTTP Validation

| Endpoint    | Result            |
| ----------- | ----------------- |
| /           | HTTP 200 (16 ms)  |
| /api/health | HTTP 404 (5.7 ms) |

NGINX was operational and responding normally.

### TCP State Distribution

| State     | Count |
| --------- | ----- |
| LISTEN    | 5     |
| TIME-WAIT | 2     |

No abnormal TCP connection accumulation was observed.

## Assessment

The strongest evidence points to a database-related service degradation beginning around 04:07. Application logs show connection pool saturation progressing to connection pool exhaustion and query timeouts. By 06:22 the application could no longer establish database connections, generating repeated ECONNREFUSED errors.

The Python memory-consumption process contributed to elevated memory utilization and likely increased system pressure, but available memory remained sufficient during the investigation. The oversized application log directory indicates a log management issue but was not yet causing disk capacity problems.

The most likely root cause of the latency increase is database unavailability or severe database resource exhaustion, resulting in connection pool exhaustion and application query timeouts.

## Recommended Next Steps

1. Investigate the database service immediately and determine why connections on port 5432 were unavailable after 06:22.
2. Terminate or remediate the memory-consuming Python process (PID 2825) and monitor application memory utilization for recurrence.
3. Implement proper log rotation and retention policies for `/var/log/kijanikiosk` to prevent uncontrolled log growth.
