# Sanad V1 implementation status

## Live Supabase project

Project: `vclicpejajxadsbuakdw`

There are currently **16 applied migrations** on the live project:

1. `initial_schema`
2. `storage_and_delivery`
3. `courier_rls`
4. `donation_images_rls`
5. `admin_matching_ops`
6. `risk_rules_and_ops`
7. `delivery_failures`
8. `security_hardening`
9. `api_privileges_hardening`
10. `function_public_execute_hardening`
11. `role_management`
12. `user_handoffs`
13. `delivery_pin_issuance_model`
14. `match_offer_workflow`
15. `admin_accepted_matches_queue`
16. `suspension_and_contribution_enforcement`

Applied and verified capabilities:

- Initial PostgreSQL schema and workflow state
- RLS enabled on every `public` table
- Private donation-image Storage bucket and object policies
- No direct `anon` table access in V1
- No default PostgreSQL `PUBLIC` execution on application functions
- Column-level protection for role, trust, workflow state and other privileged fields
- Courier-scoped delivery reads
- Minimum-information courier task RPC
- Pickup/delivery PIN verification
- PIN plaintext is generated only on demand by the handoff owner; only the hash is stored
- Private beneficiary match-offer workflow: offer -> accept/decline -> delivery assignment
- Admin queue for accepted matches awaiting courier assignment
- Admin contribution verification and audit log
- Rule-based fraud/risk triggers
- Delivery failure/no-show tracking and rescheduling
- Audited risk resolution and user suspension operations
- Audited role-management RPC for user/courier/admin roles
- Suspended accounts cannot create new needs, donations, addresses, contribution records or donation-image uploads
- Operational contributions are server-constrained to 1,000/2,000/3,000/4,000/5,000 YER
- One active payment reference cannot be reused across pending/verified contributions
- Pilot assets `BIKE-01` and `BIKE-02` inserted as active electric motorbikes

Security verification performed directly against the live database:

- all current `public` tables have RLS enabled;
- `anon` has no direct table privileges;
- admin/courier/user operational RPCs are not executable by `anon`;
- trigger/internal helper functions are not exposed as client RPCs;
- normal authenticated users cannot directly mutate workflow/status/role fields.

## Flutter application implemented

Community flow:

- Arabic RTL shell
- Google-auth-ready sign-in
- Phone/address/GPS onboarding
- Donation creation with category/condition
- Need creation with private reason
- Operational-profile requirement before creating a donation or need
- Up to four compressed donation images with private upload
- Optional 1,000–5,000 YER operational contribution flow
- Private match-offer screen with accept/decline
- User handoff/status screen
- On-demand pickup/delivery PIN generation

Courier flow:

- Role-gated courier mode
- Assigned-task list only
- Minimum necessary pickup/dropoff location and operational phone
- GPS captured at operational events, not continuous tracking
- Pickup/delivery PIN verification
- Failure/reschedule reporting

Admin flow:

- Role-gated admin mode
- KPI overview
- Matching queue and scoring
- Private offer creation
- Accepted-match delivery queue
- Courier + electric motorbike assignment
- Contribution review
- Risk review with audited resolution
- User role management
- User suspension / unsuspension

## Repository / CI

- GitHub branch: `feat/mvp-foundation`
- Pull request: #1
- Flutter Analyze GitHub Actions workflow enabled
- Supabase migrations and pilot seed stored in the repository
- A one-time Android scaffold generation workflow is configured to create package `io.sanad.app`, add location permissions and register `io.sanad.app://login-callback`.

## Remaining external configuration / pilot gates

1. Create/configure Google OAuth client credentials in Google Cloud.
2. Enable Google provider in Supabase Auth using those client credentials.
3. Add the required Google/Supabase redirect configuration.
4. Verify the generated Android host and produce a signed pilot APK/AAB.
5. After the first trusted Google account signs in, bootstrap that account as the first `admin` once.
6. Have both courier Google accounts sign in, then assign them `courier` from the admin UI.
7. Run a controlled end-to-end pilot with test donor + beneficiary + courier before public onboarding.

No service-role/secret key is stored in Flutter or GitHub.
