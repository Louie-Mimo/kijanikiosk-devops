# KijaniKiosk kk-payments SLI and SLO Specification

## 1. Purpose

This document defines the proposed Service Level Indicators (SLIs), Service Level Objectives (SLOs), and short-window rollback thresholds for the `kk-payments` payment service.

The purpose is to make reliability measurable and to define when a newly deployed version should be considered unhealthy enough to trigger an automated rollback.

> **Status:** All targets in this document are **proposed targets and have not yet been measured against production traffic**. They should be reviewed after sufficient real production data has been collected.

The three reliability areas covered are:

1. Availability
2. Request latency
3. Payment error rate

All SLOs use a **30-day rolling measurement window**.

---

## 2. SLI 1: Availability

### Definition

Availability measures the percentage of eligible requests to `kk-payments` that receive a valid response from the service instead of failing because of an application or infrastructure problem.

### Data source

The primary data source will be:

- nginx access logs for requests routed to `kk-payments`
- application health-check results
- a future metrics platform collecting request status codes and service availability

The nginx access logs should record, at minimum:

- timestamp
- request path
- response status
- upstream response status
- request duration
- upstream response time

### Calculation

Availability will be calculated as:

```text
Availability (%) =
Successful eligible requests
---------------------------- × 100
Total eligible requests
```

For this SLI, a successful request is one where the service produces an expected application response and does not fail because of a server-side or infrastructure error.

Server-side `5xx` responses, upstream connection failures, and periods where the service cannot be reached count as unavailable.

Client-generated errors such as malformed requests should not automatically count against service availability because they do not necessarily indicate that the service itself is unavailable.

### Measurement window

The production SLO is measured over a rolling **30-day window**.

Short-window health measurements are also used during a deployment to detect a release that is immediately unhealthy.

### Proposed SLO

**Target: at least 99.9% availability over any rolling 30-day period.**

This corresponds to an availability error budget of approximately 0.1% of the measurement period.

For a 30-day month:

```text
30 days × 24 hours × 60 minutes = 43,200 minutes

0.1% of 43,200 minutes = 43.2 minutes
```

Therefore, a 99.9% availability objective allows approximately **43 minutes of unavailable service in 30 days** before the SLO is missed.

---

## 3. SLI 2: Request Latency

### Definition

The latency SLI measures the percentage of successful `kk-payments` requests that complete within an acceptable response-time threshold.

For the initial target, the acceptable response time is **2 seconds**.

### Data source

The primary data source will be:

- nginx access-log request timing
- upstream response-time fields
- application request-duration metrics from a future monitoring platform

The deployment monitor already uses a 2-second latency threshold during its short confidence window. Production monitoring should use the same measurement concept but aggregate it over a longer period.

### Calculation

Latency performance will be calculated as:

```text
Latency compliance (%) =
Successful requests completed in <= 2 seconds
--------------------------------------------- × 100
Total successful eligible requests
```

Requests that complete successfully but take longer than 2 seconds count against the latency SLI.

Failed requests are tracked separately by the availability and payment error indicators so that one failed request does not distort every reliability indicator at the same time.

### Measurement window

The production latency SLO is measured over a rolling **30-day window**.

Deployment-time latency is evaluated using a much shorter window so a newly released version that becomes abnormally slow can be rolled back quickly.

### Proposed SLO

**Target: at least 99.0% of successful eligible requests complete within 2 seconds over any rolling 30-day period.**

This means no more than 1.0% of otherwise successful requests should exceed the 2-second threshold.

This target is intentionally less strict than the availability target because a slow request is undesirable but is not equivalent to complete service unavailability.

---

## 4. SLI 3: Payment Error Rate

### Definition

The payment error-rate SLI measures the percentage of valid payment attempts that fail because of a `kk-payments` application, dependency, or platform error.

Examples include:

- unhandled application exceptions
- failed internal processing
- unexpected upstream dependency failures
- server-side `5xx` failures during payment processing

A payment rejected correctly because of a valid business rule, such as invalid input or insufficient funds, should not automatically be classified as a platform error.

### Data source

The primary data source will be:

- structured `kk-payments` application logs
- payment transaction result records
- server-side error counters
- a future metrics system exposing payment success and failure counters

Each payment attempt should eventually produce a structured result that makes it possible to distinguish:

```text
successful payment
valid business rejection
client/input error
system/platform error
```

### Calculation

The payment system error rate is:

```text
Payment error rate (%) =
Payment attempts failed because of system/platform errors
--------------------------------------------------------- × 100
Total valid payment attempts
```

For easier comparison with a minimum percentage SLO, the corresponding error-free payment percentage is:

```text
Error-free payment percentage =
100% - Payment error rate
```

### Measurement window

The production SLO is calculated over a rolling **30-day window**.

A short rolling window is used after deployment to identify a release that introduces a sudden increase in payment processing failures.

### Proposed SLO

**Target: at least 99.5% of valid payment attempts must be free from system/platform errors over any rolling 30-day period.**

This is equivalent to:

```text
Payment system error rate <= 0.5%
```

Business-rule rejections should be measured separately because they may represent legitimate application behaviour rather than a service reliability failure.

---

## 5. SLO Summary

| Reliability concern | SLI | Proposed 30-day SLO |
|---|---|---|
| Availability | Percentage of eligible requests completed without server-side or infrastructure failure | **>= 99.9%** |
| Latency | Percentage of successful eligible requests completed within 2 seconds | **>= 99.0% within 2 seconds** |
| Payment error rate | Percentage of valid payment attempts free from system/platform errors | **>= 99.5% error-free**, equivalent to **<= 0.5% system error rate** |

> These are **proposed targets, not yet measured against production traffic**.

---

## 6. Automated Rollback Thresholds

The 30-day SLOs describe long-term reliability. They are not appropriate as the only trigger for deployment rollback because waiting for a 30-day objective to fail would allow a bad release to remain live for too long.

A deployment therefore uses stricter short-window thresholds.

| SLI | 30-day SLO | Short-window rollback threshold | Relationship to the SLO |
|---|---|---|---|
| Availability | >= 99.9% | **Availability below 99.0% over a rolling 1-minute window, or 3 consecutive health-check failures** | A new release showing immediate availability loss is rolled back long before it can consume a meaningful part of the 30-day availability error budget. |
| Latency | >= 99.0% of successful requests within 2 seconds | **Less than 95.0% of successful requests complete within 2 seconds over a rolling 1-minute window** | The rollback threshold allows minor short-term variation but treats a sharp degradation from the long-term target as evidence that the release may be unhealthy. |
| Payment error rate | >= 99.5% error-free, or <= 0.5% system errors | **More than 3.0% system/platform payment errors over a rolling 1-minute window** | The short-window threshold is intentionally higher than the long-term 0.5% error-rate objective so isolated errors do not trigger rollback, while a release causing a sudden large failure rate is removed quickly. |

### Why the rollback thresholds are different from the SLOs

SLOs describe the reliability customers should experience over time.

Rollback thresholds answer a different question:

> Is the newly deployed version behaving badly enough that continuing to expose customers to it creates unacceptable risk?

For this reason, the rollback thresholds use short measurement windows and detect sharp changes rather than waiting for the long-term SLO to be breached.

The automated post-deployment monitor used in the deployment exercise checks health every 5 seconds and triggers rollback after 3 consecutive failed health checks. During the controlled-fault test, this mechanism detected the failed green environment and automatically restored the previous blue environment.

The measured automated rollback for this project completed in **31 seconds from controlled fault introduction to confirmed restoration of the previous version through the proxy**, which is within the required 90-second recovery target.

---

## 7. Measurement and Reporting Approach

For production use, the team should build a dashboard containing the three SLIs and their corresponding SLO status.

The dashboard should provide:

- current 30-day SLO compliance
- remaining availability/error budget
- short-window deployment health
- current payment system error rate
- request latency distribution
- deployment/version annotations so changes can be correlated with reliability changes

Reports should distinguish between:

- customer-caused failures
- expected business-rule rejections
- application failures
- dependency failures
- infrastructure failures

This prevents legitimate payment declines or invalid requests from being incorrectly reported as platform unreliability.

---

## 8. What We Do Not Commit To

The following metrics are useful operational indicators, but they are **not part of the initial kk-payments SLO commitment**.

### CPU utilisation

We do not commit to maintaining a particular CPU utilisation percentage.

CPU usage is an internal capacity and efficiency signal rather than a direct measure of the customer experience. High CPU usage can be acceptable if availability, latency, and payment correctness remain within their objectives.

### Memory utilisation

We do not commit to a specific average memory-utilisation percentage.

Memory consumption is important for capacity planning and detecting leaks, but customers experience the consequences through availability, latency, or failed payment processing. Memory therefore remains an operational metric rather than an SLO in this initial specification.

### Deployment frequency

We do not commit to a minimum number of deployments per day or week.

Deployment frequency measures engineering delivery activity rather than payment-service reliability. It may be tracked separately as an engineering performance metric.

### Business payment approval rate

We do not commit to a specific percentage of payment attempts being approved.

Approval can depend on account balance, customer input, fraud controls, downstream rules, and other legitimate business decisions. A correctly rejected payment is not automatically a reliability failure. This SLO therefore measures system-caused payment errors rather than business approval outcomes.

---

## 9. Review and Next Steps

These SLOs should be treated as an initial reliability specification.

After sufficient production traffic is available, the team should review actual availability, latency, and payment error distributions and determine whether the proposed targets reflect realistic customer expectations and system capability.

Any adjustment should be supported by measured production evidence rather than by changing a target simply because the service failed to meet it.

The objective is to use SLIs and SLOs as engineering decision tools: they should identify reliability risk early, make rollback decisions measurable, and provide a clear definition of what reliable payment service means for KijaniKiosk.
