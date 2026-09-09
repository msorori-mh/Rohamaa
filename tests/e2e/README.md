# Disposable live testing

The `Isolated E2E and Security` workflow runs against **localhost only**. It does
not use project secrets, a hosted Supabase project, or production user data.

1. Initialize a temporary Supabase configuration and replay every migration.
2. Start Auth, REST, Storage and the repository's Edge Functions.
3. Provision eight synthetic users through the local Auth admin API; assign
   roles/addresses as fixture setup. Subsequent requests use real user JWTs.
4. Run API business workflows, isolation tests and security rejection tests.
5. Install Flutter, analyze, run existing tests and query OSV for resolved Pub
   package versions. This is not a native/Gradle vulnerability scan.
6. Build the complete Flutter application for Linux and run integration tests
   with the same local backend. Test-only credentials are injected into this
   disposable test build, never a distributed APK.
7. Upload test logs/results and the resolved dependency lock. Credential files
   are excluded; destroy the local stack and remove credentials in cleanup.

Failures are not marked expected or skipped to turn the security gate green.
The workflow collects independent results and fails if any required gate fails.
Each API test creates its own operational records; credentials shared by the
suite are synthetic. The entire database exists only for the job and is removed
with `supabase stop --no-backup`.

`run_api.py --bootstrap` requires `E2E_STATUS_FILE` from `supabase status -o json`
and a private `E2E_RUNTIME_FILE` destination. The normal invocation runs the
tests and writes `test-results/api.xml`. Both Python and Flutter refuse remote
backend URLs, so do not adapt this runner to production.

## What these tests do not certify

Linux application checks do not certify Android/iOS hardware, Google consent,
signed App Links, background/closed-app Push, camera/GPS permission dialogs,
mobile offline recovery, or full accessibility. External identity flows and
hardware still require a separate device test lane. Screen loading checks are
distinguished from the contribution UI write flow and multi-role API workflows.

The historical `0008` policy replacement correction enables clean migration
replay. It does not apply any change to a deployed project or modify migration
history there. CI records any further replay failure as a real failure.
