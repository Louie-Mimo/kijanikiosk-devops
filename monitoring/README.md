# KijaniKiosk Error-Rate Monitoring

This directory implements the Track A log-based error-rate monitoring signal.

## Objective

Evaluate the staging `kk-payments` service before production promotion.

The monitor:

1. Sends live HTTP requests to the staging `/health` endpoint.
2. Records each result as structured JSONL.
3. Counts HTTP 5xx responses and failed connections.
4. Calculates the error rate.
5. Blocks production promotion when the error rate is greater than 5%.

## Threshold

The requirement is:

    ERROR_RATE > 5% => ALERT

Therefore:

- 5.00% is HEALTHY
- anything greater than 5.00% is ALERT

With the default 20 probes:

- 0 failures = 0% -> HEALTHY
- 1 failure = 5% -> HEALTHY
- 2 failures = 10% -> ALERT

## Files

- `error-rate-monitor.py` - parses structured JSONL and calculates error rate.
- `check-staging-error-rate.sh` - performs live staging probes.
- `test-error-rate-monitor.sh` - verifies threshold behaviour.

Generated evidence is written under `monitoring/output/` and is excluded from Git.

## Jenkins Integration

The production flow is:

    Deploy Staging
        |
        v
    Staging Smoke Test
        |
        v
    Staging Error Rate Check
        |
        +-- error rate <= 5% --> Production Approval
        |
        +-- error rate > 5%  --> Pipeline FAIL / production blocked
