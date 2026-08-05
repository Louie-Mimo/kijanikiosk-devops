# Strategy Analysis

## Scenario 1: The Overnight Batch Processor

**Selected Strategy:** Rolling Deployment

A rolling deployment is the best choice because the batch processor runs on a single dedicated worker VM with no customer-facing traffic, rollback within 24 hours is acceptable, and the infrastructure budget only allows one environment. Although rollback is slower than blue/green, the strategy requires no duplicate infrastructure and is appropriate for background workloads where temporary reduced capacity and slower recovery are not critical.

## Scenario 2: The User-Facing Authentication Service

**Selected Strategy:** Blue/Green Deployment

A blue/green deployment is the best choice because the new JWT token format is not backwards-compatible, making mixed-version traffic unacceptable, while the requirement for rollback in under five minutes demands an instant traffic switch. Since the team has budget for duplicate infrastructure during deployment, blue/green eliminates mixed-version sessions and provides near-instant rollback by switching traffic back to the previous environment.

## Scenario 3: The Machine Learning Recommendation Engine

**Selected Strategy:** Canary Deployment

A canary deployment is the best choice because the team wants to evaluate the new recommendation model under real production traffic, accepts that users may receive different model versions simultaneously, and has a comprehensive monitoring system to support gradual rollout decisions. During each rollout stage, the team should monitor click-through rate, request latency, error rates, and resource usage, progressing only if the new model meets or exceeds the stable model's performance and SLOs; otherwise, traffic should immediately be routed back to the stable version.
