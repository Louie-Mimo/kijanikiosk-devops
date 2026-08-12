# KijaniKiosk Board Demo Script

[Stage direction: Show the deployment dashboard with blue serving version v1.3.0 and green healthy on version v1.4.0. Confirm the post-deployment monitor is running.]

“Today I will show how KijaniKiosk can release a new payment-service version safely and recover automatically if that release fails. We begin with the current stable version serving customers while the new version waits separately.”

[Stage direction: Deploy or confirm version v1.4.0 on green and show its health check passing.]

“The new version is now running separately and has passed its health check. Customers are still using the stable version, so this preparation does not interrupt service.”

[Stage direction: Run the blue-to-green switch and show the proxy health response returning version v1.4.0.]

“We are now moving customer traffic to the new version. The system checks that the new version is healthy before completing the change. The new release is now serving traffic.”

[Stage direction: Stop `kk-api-green.service` to introduce the controlled fault. Do not manually invoke rollback.]

“I will now introduce a controlled failure in the new release. From this point, no person will trigger the recovery. The system must detect the problem and recover by itself.”

[Stage direction: Show the monitor recording three consecutive failures, `[MONITOR FAIL] ROLLBACK TRIGGERED`, and the automatic switch back to blue.]

“The monitoring process has detected repeated failures and has automatically restored the previous healthy version. No manual recovery action was required.”

[Stage direction: Show the final health response returning v1.3.0 and the recorded T0-to-T2 duration of 31 seconds.]

“The system detected the failed release and restored normal service in 31 seconds, well inside our 90-second target. Previously, recovery depended on a person noticing the problem. This demonstration shows that KijaniKiosk can now limit the impact of a bad release and restore a known-good version automatically.”
