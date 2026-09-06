# Sanad V1 implementation status

## Live Supabase project

Project: `vclicpejajxadsbuakdw`

Applied and verified on the live project:

- Initial PostgreSQL schema
- RLS enabled on all `public` tables
- Private donation-image Storage bucket and object policies
- Courier-scoped delivery reads
- Pickup/delivery PIN verification
- Admin matching, delivery creation, contribution verification and risk-review RPCs
- Rule-based risk triggers
- Delivery failure/no-show tracking
- Column-level privilege hardening
- `anon` table access removed for V1
- Default PostgreSQL `PUBLIC` function execution removed
- Audited admin role-management RPC
- Pilot assets `BIKE-01` and `BIKE-02` inserted as active electric motorbikes

Security verification performed against the live database:

- every `public` table has RLS enabled;
- `anon` has no direct table privileges;
- sensitive workflow/status/role columns cannot be directly updated by normal authenticated clients;
- admin/courier RPCs are not executable by `anon`;
- trigger/internal helper functions are not exposed as client RPCs.

## Flutter application implemented

- Arabic RTL application shell
- Google-auth-ready login flow
- Profile/phone/address/GPS onboarding
- Donation creation
- Need creation
- Operational-profile requirement before creating donation/need
- Donation category and condition capture
- Up to four compressed donation images with private upload
- Optional 1,000–5,000 YER operational contribution flow
- Role-gated admin and courier screens
- Admin KPIs, matching queue, contribution review and risk review
- Courier task list
- Minimum-information task details
- Pickup/delivery PIN verification with GPS event capture
- Delivery failure/reschedule reporting

## Repository / CI

- GitHub branch: `feat/mvp-foundation`
- Pull request: #1
- Flutter Analyze GitHub Actions workflow enabled
- Supabase migrations and pilot seed stored in the repository

## External configuration still required

These cannot be derived from the repository or database and require provider credentials/setup:

1. Create/configure Google OAuth client credentials in Google Cloud.
2. Enable Google provider in Supabase Auth using those client credentials.
3. Add the mobile redirect/deep-link configuration.
4. Generate/commit final Android platform scaffolding/signing configuration.
5. After the first real Google sign-in, bootstrap one trusted account as the first `admin`.
6. After the two courier Google accounts sign in, assign them the `courier` role through the admin role-management operation.

No service-role/secret key is stored in Flutter or GitHub.
