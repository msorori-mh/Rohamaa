# Ruhamaa — Current implementation status

_Last reviewed against the live Marib pilot project: 7 September 2026._

## Live Supabase project

Project ref: `vclicpejajxadsbuakdw`

The live project currently has **53 recorded migrations** before the P2 recovery migration. The repository migration chain is checked in CI for duplicate numeric versions.

### Live backend capabilities

- PostgreSQL schema for profiles, addresses, needs, donations, item images, item matches, couriers, vehicles, deliveries, delivery events/failures, contributions, risk flags and audit logs.
- Service areas and staff-area assignments for admin/supervisor scope.
- Private Supabase Storage for donation images.
- RLS on exposed operational tables and role-gated server functions.
- Roles: `user`, `courier`, `supervisor`, `admin`.
- Primary-admin protection and staff-password workflows through server-side Edge Functions.
- Item delivery chain with separate pickup/delivery PINs and event-level location capture.
- Cash-to-courier operational contributions; new flows do not use an in-app transfer/payment reference.
- Category System V2 fields on donations and needs: `category_version`, `category_group`, `item_type_key`, `item_attributes`.
- Precise V2 item matching with legacy-category fallback.
- Reviewed-needs discovery cards that expose only neutral, anonymized need information.
- Time/skill service offers, private service requests, bilateral match consent, scheduling and completion.
- Verified Partner Services V1 with partner profile, explicit terms acceptance, verification state, activity scope and monthly capacity.
- Private service incident reporting and admin review.
- Delivery, courier, economics and community-impact reports.
- Risk flags remain review signals rather than automatic eligibility decisions.
- P2 repository work adds a privacy-protected non-food/non-medical recovery path: warehouse intake, A–D inspection, cleaning/repair work orders, readiness for distribution, recycling evidence, and admin-only costs/proceeds. It remains pending live migration and physical-device UAT until the P2 gate is closed.

### Security state verified against live Supabase

- New partner/service/reviewed-needs tables do not expose direct anonymous access.
- `service_partners` is SELECT-only to the authenticated client; registration and verification changes use constrained RPCs.
- Partner offers are restricted to a verified partner owned by the authenticated user and to the allowed category scope for that partner kind.
- `staff_report_daily` is executable by `authenticated` but not by `anon`/`PUBLIC`; the function itself requires admin/supervisor access and area scope.
- Donation/need priority does not use delivery contribution amount or previous giving.
- No service-role/secret key is embedded in Flutter.

Supabase Advisor is **not** at zero warnings. Remaining warnings include intentional/historical authenticated `SECURITY DEFINER` functions that perform internal role/ownership checks, the project-level leaked-password-protection setting, legacy multiple-permissive-policy performance notices, and unused-index notices expected in a low-traffic pilot.

## Flutter application

### Community experience

- Arabic RTL visual system and Ruhamaa branding.
- Google OAuth through Supabase Auth.
- Profile, phone, address, service area and operational location onboarding.
- Three-step V2 donation and need flows with precise taxonomy and attributes.
- Private donation-image upload.
- Reviewed-needs donor-inspiration surface; users still cannot browse donations.
- Private item match offers with accept/decline.
- My handoffs/status and on-demand PIN flow.
- Optional cash-to-courier contribution intent.
- Personal time/skill offer flow and private service-request flow.
- My service operations with private incident reporting.
- Verified Partner registration and partner service-offer flow after staff verification.
- Account/privacy/terms/deletion surfaces.

### Courier experience

- Role-gated task list scoped to assigned deliveries.
- Minimum operational contact/location details.
- Pickup and delivery PIN verification.
- Event-level GPS capture, not continuous background tracking.
- Failure/no-show/reschedule reporting.

### Admin/supervisor experience

- Role-gated operations home.
- Service areas and staff creation/assignment.
- Reviewed-needs moderation.
- Category V2 item-match candidate review.
- Item delivery assignment to courier/vehicle.
- Time/skills offer review and service matching.
- Verified Partner review/suspension.
- Private service-incident review.
- Contribution verification after physical cash receipt confirmation.
- Risk review, user management and suspension.
- Delivery/economics/courier/community-impact reports.
- Recovery/inventory screen with warehouse intake, A–D inspection, processing queue, recycling confirmation, and impact summary.

## Android / OAuth identity

- Application ID: `com.ruhamaa.app`
- Internal mobile callback: `com.ruhamaa.app://login-callback`
- Public domain: `https://ruhamaa.com`
- Future verified App Link callback: `https://ruhamaa.com/login-callback`
- Google Web OAuth callback through Supabase: `https://vclicpejajxadsbuakdw.supabase.co/auth/v1/callback`
- Android target SDK in the current project: API 36.

The old `io.sanad.app` identity is not part of the current release branch.

## CI / release hardening

- `flutter_ci.yml` validates unique Supabase migration versions, dependencies, `flutter analyze`, `flutter test`, debug APK build and artifact upload.
- A historical conflicting `0017_operating_economics.sql` migration was removed because its schema was superseded by the live staff-area/economics migration.
- The historical untracked/stale daily-report migration was replaced by `0052_staff_daily_reports_reconciliation.sql`, and the matching definition is recorded in the live migration history.
- `android_release_bundle.yml` is a manual signed-AAB workflow that requires GitHub Actions signing secrets and keeps signing passwords in environment variables rather than plaintext CI files.
- Gradle refuses release builds without a complete upload-signing configuration.
- Keystore and `key.properties` files are gitignored.
- Public Privacy Policy, Terms, account-deletion page and Play Data Safety source-of-truth have been updated for item, service and partner behavior.
- GitHub Pages is configured to publish production site content from `main` after merge.

## Remaining external release gates

These cannot be completed from repository/database automation alone:

1. Run the physical-device UAT in `docs/UAT_CATEGORY_V2_PARTNERS.md`, including Google OAuth using `com.ruhamaa.app` for both a normal user and the primary admin.
2. Confirm Supabase Auth redirect allow-list contains `com.ruhamaa.app://login-callback`.
3. Finish Google Auth Platform branding/authorized-domain setup for `ruhamaa.com`.
4. Create the Android upload keystore, back it up securely and configure the four documented GitHub Actions secrets.
5. Merge the release branch to `main` so the manual signed-AAB workflow and production Pages workflow exist on the default branch.
6. Build the first signed AAB and upload it to Google Play Internal Testing.
7. Obtain the **Play App Signing** SHA-256 and publish the real `site/.well-known/assetlinks.json`.
8. Verify Android App Links on a Play-installed build before switching production OAuth to the HTTPS callback.
9. Complete the current Play Console Store Listing, Data Safety, App Access, content rating and other required declarations against the exact shipped build.

## Pilot target

The operating target remains the first **1,000 successful item handoffs/services in Marib**, with measurement of fulfillment, time-to-match, delivery/service completion, operational cost, contribution coverage, reviewed-needs inspiration, no-show, partner capacity and safety-review outcomes.
