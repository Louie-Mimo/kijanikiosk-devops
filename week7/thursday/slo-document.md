# KijaniKiosk Service Level Objectives

## kk-api (API Service)

### SLIs

1. **Availability SLI:** Measures the percentage of valid requests to kk-api that receive a successful HTTP response rather than a 5xx error. It is collected from nginx and application request metrics over the measurement window.

2. **Latency SLI:** Measures the response time of kk-api requests, using the 95th percentile (p95) latency. It is collected from nginx access logs and application monitoring metrics.

3. **Error Rate SLI:** Measures the percentage of requests to the `/health` and production API endpoints that result in HTTP 5xx responses. It is collected from nginx and kk-api application metrics.

### SLOs

| SLI | Target | Window | Error budget |
|-----|--------|--------|--------------|
| Availability | 99.9% successful requests | 30 days | 43.2 minutes unavailable |
| Latency | 95% of requests complete within 500 ms | 30 days | 5% of requests may exceed 500 ms |
| Error rate | At least 99.5% of requests do not return 5xx | 30 days | 0.5% of requests may return 5xx |

### Rollback threshold justification

The deployment monitor uses three consecutive failed health checks, a 2-second latency threshold, and a maximum of two tolerated errors during the confidence window.

These thresholds are intentionally more conservative than the monthly SLOs. The availability SLO allows up to 43.2 minutes of unavailability over 30 days, while the deployment monitor reacts after approximately 15 seconds of consecutive failed checks. Fifteen seconds represents only 0.25 minutes, or approximately 0.58% of the monthly availability error budget.

The 2-second latency threshold is higher than the normal p95 objective of 500 ms, but it is intended to identify severe degradation during deployment rather than ordinary latency variation.

The window error threshold also detects a faulty deployment before it can consume a meaningful portion of the monthly error budget. The deployment thresholds therefore act as an early-warning safety mechanism rather than waiting for the service-level objective itself to be breached.


## kk-payments (Payments Service)

### SLIs

1. **Availability SLI:** Measures the percentage of valid requests to kk-payments that receive a successful service response. It is collected from application, ingress, and payment-service request metrics.

2. **Latency SLI:** Measures payment API response time using the 95th percentile (p95). It is collected from kk-payments application metrics and proxy request-duration metrics.

3. **Payment Transaction Error Rate SLI:** Measures the percentage of submitted payment transactions that fail because of internal kk-payments errors, excluding valid customer declines and rejected invalid requests. It is collected from payment transaction status metrics and application logs.

### SLOs

| SLI | Target | Window | Error budget |
|-----|--------|--------|--------------|
| Availability | 99.95% successful service availability | 30 days | 21.6 minutes unavailable |
| Latency | 99% of payment requests complete within 1.5 seconds | 30 days | 1% of requests may exceed 1.5 seconds |
| Payment transaction error rate | At least 99.9% of valid transactions complete without internal errors | 30 days | 0.1% of valid transactions may fail because of service errors |

### Rollback threshold justification

kk-payments requires stricter reliability because failed payment transactions directly affect customers and revenue.

A deployment that produces three consecutive failed health checks is therefore rolled back immediately instead of being allowed to consume the monthly availability or transaction-error budgets.

The 2-second deployment latency threshold is also suitable as an emergency threshold because it is above the normal 1.5-second payment latency objective while still identifying major performance regression quickly.

The post-deployment monitor is intentionally more sensitive than the long-term SLOs so that a bad release is removed before it creates a significant customer impact.
