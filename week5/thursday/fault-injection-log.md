# Fault Injection Log

## Summary Table

| Stage faulted | Fault introduced | Expected behaviour | Observed? (Y/N) |
| :--- | :--- | :--- | :---: |
| **Lint** | Syntax error in source file (`src/index.js`) | Build, Verify, Archive, Publish all skip | **Y** |
| **Build** | Invalid `npm ci` flag (`npm ci --invalid-flag`) | Verify, Archive, Publish all skip | **Y** |
| **Test (in Verify)** | Deliberate failing assertion in `tests/payments.test.js` | Audit runs to completion; Archive, Publish skip | **Y** |
| **Publish** | Wrong credential ID (`credentialsId: 'wrong-id'`) | Archive ran; artifact in Jenkins but not in Nexus | **Y** |

---

## Stage Explanations

1. **Lint Stage Failure:**
   Introducing a broken JavaScript syntax error caused the linter/node syntax checker to fail early, preventing unnecessary dependency installation or build steps from running downstream.

2. **Build Stage Failure:**
   Passing an unassigned flag to `npm ci` resulted in a non-zero exit code during dependency resolution, which immediately aborted the stage and skipped all testing and publishing stages.

3. **Test Stage Failure:**
   A failing assertion inside Jest caused the `Test` branch of the parallel block to fail, but because `Security Audit` ran concurrently, the audit completed its scan before the pipeline halted and skipped archiving and publishing.

4. **Publish Stage Failure:**
   Referencing a non-existent Jenkins credentials ID caused the `withCredentials` block in the `Publish` stage to throw an unhandled exception, leaving the build artifacts safely archived in Jenkins while stopping the Nexus deployment.