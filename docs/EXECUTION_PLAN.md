# Ruhamaa V1 — Marib Pilot Execution Plan

Target: launch a controlled pilot in Marib with two couriers and the two active electric motorbikes (`BIKE-01`, `BIKE-02`), reach the first 1,000 successful item handoffs/services, and measure social impact, safety and operating sustainability.

## Phase 0 — Foundation ✅

- [x] Flutter/Supabase application foundation
- [x] Google OAuth integration through Supabase
- [x] Profiles / addresses / donations / needs / matches / deliveries / contributions
- [x] Private donation-image storage
- [x] Courier PIN workflow and delivery events
- [x] Risk flags and audit logs
- [x] Service areas, supervisors and staff creation/password workflows

## Phase 1 — Security and database hardening ✅

- [x] RLS and role-based authorization
- [x] Admin/courier/user RPC boundaries
- [x] Minimum-information courier task flow
- [x] Server-side match/assignment/verification operations
- [x] Suspended-user enforcement
- [x] Primary-admin protection
- [x] Anonymous-access hardening for private service/partner/reviewed-needs data
- [x] Migration version uniqueness check in CI
- [x] Historical migration collision removed and daily-report history reconciled with live Supabase

Exit criteria met for repository/backend work: privileged actions are role/ownership checked and donor↔beneficiary item identity is not exposed through community flows.

## Phase 2 — Community item experience ✅

- [x] Arabic RTL + Ruhamaa branding
- [x] Profile/address/location onboarding
- [x] Category System V2 donation wizard
- [x] Category System V2 need wizard
- [x] Private image upload
- [x] Reviewed-needs donor-inspiration cards
- [x] Private match offers
- [x] Handoff/status + pickup/delivery PIN
- [x] Optional cash-to-courier contribution flow
- [x] Privacy/terms/account deletion surfaces

## Phase 3 — Time and skills ✅

- [x] Individual free time/skill offers
- [x] Private service requests
- [x] Staff offer review
- [x] Service candidate scoring
- [x] Bilateral match responses
- [x] Staff scheduling/completion
- [x] Personal service-operation history
- [x] Private incident reporting

## Phase 4 — Verified Partner Services V1 ✅

- [x] Separate partner profile and business kind
- [x] Explicit Partner Safety Terms V1
- [x] Staff verification/rejection/suspension
- [x] Backend activity-scope enforcement
- [x] UI limits partner service choices to verified activity scope
- [x] Monthly case capacity
- [x] No public partner/beneficiary marketplace
- [x] No open prices/bidding; only free service or free labor + reviewed materials
- [x] Incident-review workflow

## Phase 5 — Courier and operations ✅

- [x] Assigned task list
- [x] Minimum operational contact/location
- [x] GPS capture at operational events, not continuous tracking
- [x] Pickup/delivery PIN verification
- [x] Failure/reschedule/no-show reporting
- [x] Courier and vehicle assignment
- [x] Contribution receipt verification
- [x] Risk and user-management workflows

## Phase 6 — Impact and reporting ✅

- [x] Delivery success and timing
- [x] Courier performance
- [x] Operating expenses and contribution coverage
- [x] Category V2 item counts
- [x] Reviewed-needs cards, inspired donations and inspiration rate
- [x] Service offers/requests/completion and estimated hours
- [x] Verified Partner impact
- [x] Service incident metrics

## Phase 7 — Release hardening (repository work complete; external UAT/config remains)

- [x] Android identity `com.ruhamaa.app`
- [x] App-specific callback `com.ruhamaa.app://login-callback`
- [x] Future HTTPS App Link intent for `ruhamaa.com/login-callback`
- [x] Target SDK API 36 in project
- [x] Secure release signing configuration
- [x] Manual signed-AAB GitHub workflow
- [x] Keystore/password Git protection
- [x] Flutter analyze/tests/debug APK CI
- [x] Supabase migration-number CI gate
- [x] Privacy, terms, deletion and Data Safety documentation updated for items/services/partners
- [x] Production Pages workflow configured for `main`
- [ ] Physical-device OAuth test with **new** package/callback for normal user and primary admin
- [ ] Full UAT matrix on Android device
- [ ] Google Auth Platform branding/authorized-domain final configuration
- [ ] Supabase Auth redirect allow-list verification for the new callback
- [ ] Create/back up upload keystore and configure GitHub Actions secrets
- [ ] First signed AAB to Google Play Internal Testing
- [ ] Obtain Play App Signing SHA-256 and publish real `assetlinks.json`
- [ ] Verify HTTPS App Link on Play-installed build
- [ ] Complete Play Store listing/Data Safety/App Access/content declarations

See:
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
