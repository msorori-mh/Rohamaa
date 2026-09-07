# Ruhamaa V1 Architecture

## Product boundary

Ruhamaa is a need-first social-impact platform for the Marib pilot. It matches unused physical items, donated time/skills and verified-partner capacity to privately registered needs. It intentionally does **not** expose a donation marketplace, provider marketplace, public beneficiary directory or social feed.

Operational item chain:

`donor → Ruhamaa courier → Ruhamaa → Ruhamaa courier → beneficiary`

For in-person services, Ruhamaa privately matches a requester to an approved individual provider or verified partner and reveals only the information needed after the required consent/coordination stage.

## Client surfaces

### Community Android app

- Google sign-in via Supabase Auth.
- Profile, phone, addresses, service area and operational location.
- Category System V2 donation/need creation.
- Reviewed-needs donor-inspiration cards without beneficiary identity.
- Private item-match offers and handoff tracking.
- Optional delivery-operation cash contribution intent.
- Personal time/skill offers and private service requests.
- Private service match consent/history and incident reporting.
- Verified Partner registration and partner service offers after verification.
- Privacy, terms and account-deletion request.

### Courier mode

- Assigned pickup/drop-off tasks only.
- Minimum necessary phone/location data for the assigned task.
- Distinct pickup and delivery PIN confirmation.
- GPS captured only at relevant handoff/failure events.
- Failure/reschedule/no-show reporting.
- No donor/beneficiary stories or unrelated history.

### Admin / supervisor mode

- City/service-area scope and staff management.
- Reviewed-needs moderation.
- Category V2 item matching and private offer creation.
- Courier/vehicle assignment.
- Individual service-offer review and service matching.
- Verified Partner approval/suspension and activity-scope enforcement.
- Service incident review.
- Cash-contribution verification after physical receipt confirmation.
- Risk/user management.
- Operational and community-impact reports.

## Identity and role model

A community user is not permanently classified as donor or beneficiary. One account may give an item, register an item need, offer time/skill, request a service or own a partner application.

Staff hierarchy:

`primary admin → supervisor → courier → community user`

Database role enum values are `user`, `courier`, `supervisor`, `admin`.

## Item privacy model

- Donor does not receive beneficiary identity, phone, exact address or Google identity.
- Beneficiary does not receive donor identity, phone, exact address or Google identity.
- A courier may physically meet each party to perform the assigned task, so the product promise is separation between the parties, not that field staff can never see them.
- Staff/courier access is restricted to the minimum operational data required for the role/task.
- Donation photos are stored privately, not as a public gallery.

## Service privacy model

- Requesters do not browse provider identities or partner directories.
- Providers/partners do not browse beneficiary lists.
- Before a service match is accepted/coordinated, identifying contact/location data remains private.
- After the required parties accept, Ruhamaa may disclose only the contact/location/scheduling data required to perform the service.
- Provider/partner access does not include the user’s other needs, donations, contribution history or unrelated operations.
- Service incidents are private operational reports; there are no public stars/comments.

## Category System V2

New item records use:

- `category_version`
- `category`
- `category_group`
- `item_type_key`
- `item_attributes` (`jsonb`)

The Flutter taxonomy supports eight top-level categories and precise subgroups/types. Legacy categories such as `books`, `home` and `furniture` are mapped to canonical V2 roots for compatibility.

## Item matching model

Item matching is deterministic scoring plus human approval. Current logic considers, as available:

- canonical category compatibility;
- precise type/group compatibility;
- structured attributes such as size, grade, subject or age range;
- age of the need;
- operational distance;
- account trust/safety context;
- previous same-category fulfillment as a fairness control.

**Operational contribution amount and previous giving do not add match-priority points.** A user who cannot contribute is not deprioritized for that reason.

## Reviewed-needs discovery

Reviewed-needs cards are an inspiration layer, not fulfillment reservation:

- staff publishes a neutral anonymized card derived from a real need;
- the donor can start a prefilled V2 donation from the card;
- the donation records which card inspired it for impact measurement;
- final routing still uses the private matching workflow;
- the card does not expose beneficiary contact details and disappears when the need advances into fulfillment.

## Time / skills / partner matching

Individual service offers and service requests use category/type, area, availability/hours and operational age. Provider/requester responses are independent; scheduling requires the required consent state.

Verified Partner Services adds:

- a separate `service_partners` profile;
- explicit server-timestamped Partner Safety Terms acceptance;
- staff verification state (`pending`, `verified`, `rejected`, `suspended`);
- business-kind → allowed-service-category enforcement;
- monthly case capacity in candidate eligibility;
- private incident reporting and staff resolution.

V1 partner pricing is restricted to `free` or `materials_only`; it is not an open commercial marketplace.

## Contribution model

Operational contributions are optional and separate from eligibility. The current flow records one of the fixed YER amounts and uses `payment_method='cash_to_courier'` for new contributions.

There is no in-app card/bank/wallet/transfer flow for new contributions. The contribution remains `pending` until physical receipt is confirmed and staff verifies it. Legacy `manual_transfer` records may remain for compatibility with historical data only.

## Fraud and safety model

Signals are evidence for human review, not automatic proof of abuse. Current controls include:

- unusual request velocity / repeated-equivalent need signals;
- delivery PIN validation;
- repeated delivery failure/no-show history;
- account suspension controls;
- reviewed-needs abuse flags;
- partner verification/suspension and scope enforcement;
- private service incident reports;
- immutable/audited privileged operations where implemented.

The pilot deliberately avoids invasive device fingerprinting or an automated social-credit score.

## Technology

- Flutter Android-first client plus role-gated staff surfaces in the same codebase.
- Supabase Auth, PostgreSQL, RLS, Storage and Edge Functions.
- `go_router` navigation and Arabic RTL visual system.
- Private Storage for item images.
- GitHub Actions for migration-version checks, Flutter analysis/tests/debug APK and secure signed-AAB generation.
- Production domain `ruhamaa.com` for public policy pages and future verified Android App Link.

No Supabase service-role key or Android signing secret may be embedded in the Flutter client or committed to Git.
