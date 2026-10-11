# Ataa V1 — Marib Pilot Execution Plan

> **Status correction, 11 October 2026.** An independent audit found that several items below were ticked before they were true. The checkmarks have been corrected instead of deleted: `[x]` means implemented and covered by CI in this repository, `[~]` means implemented in the repository but not yet proven where it matters (production database, a signed build, or a physical device), `[ ]` means not done. What changed and what the owner still has to do in consoles is in `docs/AUDIT_2026-10.md`.

Target: launch a controlled pilot in Marib with two couriers and the two active electric motorbikes (`BIKE-01`, `BIKE-02`), reach the first 1,000 successful item handoffs/services, and measure social impact, safety and operating sustainability.

## Phase 0 — Foundation

- [x] Flutter/Supabase application foundation
- [x] Google OAuth integration through Supabase
- [x] Profiles / addresses / donations / needs / matches / deliveries / contributions
- [x] Private donation-image storage
- [x] Courier PIN workflow and delivery events
- [x] Risk flags and audit logs
- [x] Service areas, supervisors and staff creation/password workflows

## Phase 1 — Security and database hardening (repository work done; production not yet at the same level)

- [x] RLS and role-based authorization
- [x] Admin/courier/user RPC boundaries
- [~] Minimum-information courier task flow — phase-scoped contact data arrived with Courier Dispatch V2 (`0059`); before it a courier could read both parties' details for the whole task
- [~] Server-side match/assignment/verification operations — until `20260909235810_e2e_security_closure.sql` a client could insert a donation, need or contribution with a forged status; that migration is committed but was recorded as **not applied to production** in the September handover
- [~] Suspended-user enforcement — forced password change and inactive-courier checks were only added to the role helpers by the closure migration
- [~] Primary-admin protection — enforced in SQL, but the primary admin's personal email address is hard-coded in public migrations `0020`, `0021`, `0026` and in the `admin-create-staff` Edge Function
- [x] Anonymous-access hardening for private service/partner/reviewed-needs data
- [x] Migration version uniqueness check in CI (sequential `00NN_` and 14-digit timestamp prefixes)
- [x] Historical migration collision removed and daily-report history reconciled with live Supabase
- [~] PIN hashes hidden from clients, 10-minute PIN expiry and 5-attempt limit — closure migration, same production caveat
- [ ] Supabase Auth leaked-password protection and MFA for staff — project settings, not enabled in the last Advisor review
- [ ] Production migration history reconciled with the repository (`supabase migration list`) and the closure and later migrations applied

The earlier text said the exit criteria were met. That was true only for the repository after the closure migration, and it was written before that migration existed. The phase is closed when the three unticked items above are done and the isolated E2E security suite passes on the commit that is deployed.

## Phase 2 — Community item experience (built; device UAT pending)

- [x] Arabic RTL + Ataa branding
- [x] Profile/address/location onboarding
- [x] Category System V2 donation wizard
- [x] Category System V2 need wizard
- [x] Private image upload
- [x] Reviewed-needs donor-inspiration cards
- [x] Private match offers
- [x] Handoff/status + pickup/delivery PIN
- [x] Optional cash-to-courier contribution flow
- [~] Privacy/terms/account deletion surfaces — the pages exist; until the October 2026 audit the app only recorded a deletion request and nothing processed it. The reviewed deletion process (admin queue, anonymisation, status tracking) is part of the audit-fix work and needs production deployment

## Phase 3 — Time and skills (built; device UAT pending)

- [x] Individual free time/skill offers
- [x] Private service requests
- [x] Staff offer review
- [x] Service candidate scoring
- [x] Bilateral match responses
- [x] Staff scheduling/completion
- [x] Personal service-operation history
- [x] Private incident reporting

## Phase 4 — Verified Partner Services V1 (built; device UAT pending)

- [x] Separate partner profile and business kind
- [x] Explicit Partner Safety Terms V1
- [x] Staff verification/rejection/suspension
- [x] Backend activity-scope enforcement
- [x] UI limits partner service choices to verified activity scope
- [x] Monthly case capacity
- [x] No public partner/beneficiary marketplace
- [x] No open prices/bidding; only free service or free labor + reviewed materials
- [x] Incident-review workflow

## Phase 5 — Courier and operations (built; device UAT pending)

- [x] Assigned task list
- [x] Minimum operational contact/location
- [x] GPS capture at operational events, not continuous tracking
- [x] Pickup/delivery PIN verification
- [~] Failure/reschedule/no-show reporting — the report is recorded and the delivery moves to `rescheduled`; recovery depends on admin reassignment, refined by the October 2026 backend fixes
- [x] Courier and vehicle assignment
- [x] Contribution receipt verification
- [x] Risk and user-management workflows

## Phase 6 — Impact and reporting (built; device UAT pending)

- [x] Delivery success and timing
- [x] Courier performance
- [x] Operating expenses and contribution coverage
- [x] Category V2 item counts
- [x] Reviewed-needs cards, inspired donations and inspiration rate
- [x] Service offers/requests/completion and estimated hours
- [x] Verified Partner impact
- [x] Service incident metrics

## Phase 7 — Release hardening (repository work corrected in October 2026; external UAT/config remains)

- [x] Android identity `com.ruhamaa.app`
- [x] App-specific callback `com.ruhamaa.app://login-callback`
- [x] Future HTTPS App Link intent for `https://ruhamaa.com/login-callback/` (https only; the `http` scheme was removed from the intent filter)
- [x] Target SDK API 36 in project
- [x] Secure release signing configuration
- [~] Manual signed-AAB GitHub workflow — until October 2026 it built a bundle **without** `SUPABASE_URL` / `SUPABASE_ANON_KEY`, so the result could only show the "incomplete configuration" screen. It now requires the three dart-defines, runs in the protected `release` environment from `main` or a `v*` tag only, and obfuscates. There is **no record of a signed AAB** from it, and it cannot run until the owner creates the environment, variables and signing secrets
- [x] Keystore/password Git protection
- [x] Flutter analyze/tests/debug APK CI (Flutter pinned to 3.47.3, actions pinned to commit SHAs)
- [ ] Committed `app/pubspec.lock` — CI uploads it as the `pubspec-lock` artifact and enforces it once committed
- [x] Supabase migration-number CI gate
- [x] Privacy, terms, deletion and Data Safety documentation updated for items/services/partners
- [x] Production Pages workflow configured for `main`, gated on the website checks
- [x] Android backups and device transfer disabled; release shrinking explicit
- [ ] Physical-device OAuth test with **new** package/callback for normal user and primary admin
- [ ] Full UAT matrix on Android device
- [ ] Google Auth Platform branding/authorized-domain final configuration
- [ ] Supabase Auth redirect allow-list verification for the new callback
- [ ] Create/back up upload keystore; create the `release` GitHub Environment with required reviewers; store the four signing secrets in that environment; set the `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `AUTH_REDIRECT_URL` variables
- [ ] First signed AAB to Google Play Internal Testing
- [ ] Obtain Play App Signing SHA-256 and publish real `assetlinks.json`
- [ ] Verify HTTPS App Link on Play-installed build
- [ ] Complete Play Store listing/Data Safety/App Access/content declarations

See:
- `docs/AUDIT_2026-10.md`
- `docs/UAT_CATEGORY_V2_PARTNERS.md`
- `docs/ANDROID_RELEASE.md`
- `docs/PLAY_DATA_SAFETY.md`
- `docs/GOOGLE_PLAY_RELEASE.md`

## Pilot KPIs

1. Successful item handoffs
2. Completed service operations
3. Delivery/service success rate
4. Median time to private match
5. Median time from accepted item match to delivery
6. Estimated donated service hours
7. Cost per completed fulfillment/service where meaningful
8. Cash contribution coverage of operating expenses
9. Reviewed-needs inspiration rate
10. Risk/review and confirmed-abuse rate
11. No-show/reschedule rate
12. Partner capacity utilization and partner-service completion
13. Private service-incident rate and resolution outcome

## Operating principles

- Need-first; no donation/provider marketplace.
- No donor-beneficiary direct chat in V1.
- No contribution/previous-giving priority points.
- No time-credit/barter debt.
- Manual review is acceptable when automation would increase safety or dignity risk.
- No service-role key or Android signing secret in client source.
- Public claims must distinguish item-party privacy from the minimum information required for an accepted in-person service.
