# Engineering Decision: `/usr/sbin/nologin` vs `/bin/false`

## Decision

The KijaniKiosk service accounts (`kk-api`, `kk-payments`, and `kk-logs`) use `/usr/sbin/nologin` as their login shell.

## Rationale

Both `/usr/sbin/nologin` and `/bin/false` prevent interactive user logins, but they behave differently.

### `/bin/false`

When a user attempts to log in, `/bin/false` immediately exits with a non-zero status code. The login attempt fails, but the user receives little or no explanation.

### `/usr/sbin/nologin`

When a user attempts to log in, `/usr/sbin/nologin` terminates the session and displays a message indicating that the account is not available for interactive login.

Example:

```text
This account is currently not available.
```

This behavior provides clearer operational feedback while still preventing shell access.

## Security Considerations

The KijaniKiosk service accounts are intended only for running application processes. They should never be used for interactive administration, SSH access, or terminal sessions.

Using `/usr/sbin/nologin` ensures:

* No interactive shell access is available.
* SSH authentication cannot be used to obtain a shell.
* Services can still run under dedicated identities.
* Administrators receive a clear message explaining why login is denied.

## Conclusion

`/usr/sbin/nologin` was selected because it enforces the Principle of Least Privilege while providing clearer operational behavior than `/bin/false`. The service accounts remain usable for process ownership and service execution but cannot be used for interactive access.
