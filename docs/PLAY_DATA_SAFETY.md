# Google Play Data Safety source of truth — Ataa

This file is an internal release checklist for completing Google Play's Data Safety form. It describes the current app behavior; the Play Console answers must still be checked against the exact wording shown by Google at submission time.

Aligned with the public privacy policy (`site/privacy/index.html`) dated 11 October 2026. If the two ever disagree, fix both before a release; the public policy is what users were told.

## Core declarations

- Ataa does **not sell personal data**.
- Ataa does **not use personal data for targeted advertising**.
- The app does not request Gmail, Google Drive, contacts, calendar, microphone, SMS, call log, or health-data access.
- Google is used for basic sign-in by community users; operations staff sign in with an email address and password issued by the administration. Supabase provides authentication, database, storage and backend services.
- Data is transmitted over HTTPS.
- Users can request account deletion in-app and through `https://ruhamaa.com/delete-account/`; the request is reviewed and executed by the team (see "Security and deletion").
- **Precise location is collected.** Declare "Location → Precise location" as collected, not only approximate location.
- The current product is for adults age 18+.

## Data handled by the current app

| Data family | Examples in Ataa | Why it is used |
| --- | --- | --- |
| Personal info | name, email, user ID, phone; staff email and role | authentication, contact, operational coordination |
| Location — precise | GPS coordinates saved with the user's address when the user pins it; coordinates captured by the courier's device at a pickup, delivery or failure event | pickup, delivery, service coordination, handoff/failure event evidence |
| Location — approximate | service area, city, free-text address description | matching by area, routing |
| Photos / files | donation item photos selected by the user | item review and matching |
| User-generated content | donation/need descriptions, category attributes, service offers/requests, availability notes | matching and fulfillment |
| App activity / operational records | match responses, handoff events, delivery/service states, courier accept/decline and reason, no-show and risk events | product functionality, safety, fraud prevention, operations |
| Warehouse and inspection records | intake, A–D inspection grade, cleaning/repair notes, readiness, recycling evidence attached to a donation | item quality and safe redistribution |
| In-app notifications | notification text, type, creation time, read state | telling the user about status changes; no third-party push service is used |
| Account-deletion requests | request time, status, staff decision | executing the user's deletion request |
| Safety reports | private service incidents and staff resolution notes | safety, abuse prevention and dispute handling |
| Optional contribution records | desired cash contribution amount, courier confirmation of cash receipt, verification status | operational cost support; no electronic payment credentials are collected |
| Partner information | business display name/type, contact phone, capacity, verification state, terms acceptance | verification and delivery of approved community services |

## Sharing / disclosure review

Do not answer the Play Console's “data shared” question mechanically from this document. Apply Google's current definitions and exemptions.

- Supabase and Google act as technical service providers for the functions described above.
- In item-delivery workflows, donor and beneficiary identity are not disclosed to each other; Ataa staff/couriers receive only operational data required for their assigned task.
- In an in-person service match, after the required parties accept and Ataa coordinates the match, the minimum contact/location/scheduling data necessary to perform the service may be disclosed to the matched provider or verified partner.
- A verified partner is prohibited from using beneficiary data for marketing, photography/publication, unrelated sales, or building a customer list from Ataa data.
- Before selecting “no data shared” in Play Console, explicitly determine whether disclosure to an external verified partner qualifies for Google's user-initiated/service-provider exemption under the current Data Safety definitions. If it does not, declare the applicable shared data categories instead of understating collection/sharing.

## Location notes

- The manifest requests `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`. **Precise location is collected and stored**: with the user's address when they choose to pin it, and at specific courier events (pickup, delivery, failure report). Answer the Data Safety location questions accordingly; do not declare approximate location only.
- Collection is tied to a user action in the foreground. There is no `ACCESS_BACKGROUND_LOCATION` permission and no continuous tracking of users or couriers.
- A courier sees a party's coordinates only during the phase of the delivery that needs them.
- Purpose to declare: app functionality (and fraud prevention/security for event evidence). Not advertising, not analytics.

## Financial-data notes

- There is no Google Play Billing flow and no in-app electronic payment in the current product.
- Optional delivery-operation contributions are cash-to-courier pledges/records.
- Ataa does not collect card numbers, bank-account credentials, wallet credentials, or payment authentication secrets.
- Re-check Google's current Data Safety definition of “financial info / purchase history / other financial info” before submission to decide whether the contribution amount/status belongs in a financial-data category.

## Security and deletion

- Supabase Row Level Security and role checks restrict access to operational tables.
- Donation image storage is private.
- Sensitive server credentials are not embedded in the mobile app.
- Pickup/delivery PINs are stored hashed, expire after 10 minutes and are limited to 5 attempts.
- Android cloud backup and device-to-device transfer are disabled for the app.
- Hosting: Supabase. The hosting region is not yet recorded in this repository; confirm it in the Supabase dashboard and state it in the privacy policy (the policy currently says the region is being confirmed).

Account deletion as implemented (this is what the Play "Data deletion" answers and the deletion URL must describe):

1. The user requests deletion in the app (Privacy & Account → Delete account and data) or by email to `msorori692022@gmail.com` when they cannot sign in. The public page is `https://ruhamaa.com/delete-account/`.
2. The request is not automatic: the team reviews it in an admin queue and closes any open pickup, delivery or service operation first. The user sees the request status in the app and can cancel while it is still pending.
3. On approval, identifying data is removed: name, phone number, addresses and their coordinates, sign-in identity, and donation photos.
4. Operation records are kept in anonymised form, without personal identifiers, for record integrity and fraud prevention. Declare this retention in the Data Safety form where it asks whether some data is retained after a deletion request.
5. Target handling time: 30 days from the request.
6. Operations-staff accounts are created and removed by the administration and do not use the self-service path.

## Store submission cross-check

Before every Play release, verify all of the following still match the shipped build:

1. `site/privacy/index.html`
2. `site/terms/index.html`
3. `site/delete-account/index.html`
4. Android manifest permissions
5. Flutter dependencies / SDKs
6. Supabase tables and storage behavior
7. Service/partner data disclosure behavior
8. Data Safety answers in Play Console

If a new SDK, permission, payment method, analytics tool, ad SDK, messaging feature, health feature, or background-location feature is added, this document and the public privacy policy must be reviewed before release.
