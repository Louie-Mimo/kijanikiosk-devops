# Fault Injection & Pipeline Resilience Log

| Stage Faulted | Method of Fault Injection | Observed Downstream Behaviour | One-Sentence Design Rationale |
| :--- | :--- | :--- | :--- |
| **Lint Stage** | Introduced unclosed string / syntax fault in `week5/payments/src/index.js`. | Pipeline failed immediately at Lint stage. Build, Verify, Archive, and Publish stages were **Skipped**. | Catching syntax errors instantly prevents wasting compute resources on downstream compilation and testing. |
| **Build Stage** | Corrupted script command inside `package.json` to trigger exit code 1. | Lint passed. Pipeline failed at Build stage. Verify, Archive, and Publish stages were **Skipped**. | Artifact generation must halt when compilation fails to prevent packaging empty or invalid software outputs. |
| **Verify Stage** | Injected a failing assertion (`assert.strictEqual(1, 2)`) in unit tests. | Lint and Build passed. Verify stage failed. Archive and Publish stages were **Skipped**. | Software containing functional bugs must never be archived or pushed to the package registry. |
| **Publish Stage** | Supplied invalid registry credentials / incorrect Nexus port URL. | Lint, Build, Verify, and Archive passed. Publish stage failed during upload execution. | Pipeline failure at publication prevents incomplete uploads from corrupting the official version index. |