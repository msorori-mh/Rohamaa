# Google Play Data Safety source of truth — Ruhamaa

This file is an internal release checklist for completing Google Play's Data Safety form. It describes the current app behavior; the Play Console answers must still be checked against the exact wording shown by Google at submission time.

## Core declarations

- Ruhamaa does **not sell personal data**.
- Ruhamaa does **not use personal data for targeted advertising**.
- The app does not request Gmail, Google Drive, contacts, calendar, microphone, SMS, call log, or health-data access.
- Google is used for basic sign-in; Supabase provides authentication, database, storage and backend services.
- Data is transmitted over HTTPS.
- Users can request account deletion in-app and through `https://ruhamaa.com/delete-account/`.
- The current product is for adults age 18+.

## Data handled by the current app

| Data family | Examples in Ruhamaa | Why it is used |
| --- | --- | --- |
| Personal info | name, email, user ID, phone | authentication, contact, operational coordination |
| Location | service area, address description, precise coordinates when needed | pickup, delivery, service coordination, handoff/failure event evidence |
| Photos / files | donation item photos selected by the user | item review and matching |
| User-generated content | donation/need descriptions, category attributes, service offers/requests, availability notes | matching and fulfillment |
| App activity / operational records | match responses, handoff events, delivery/service states, no-show and risk events | product functionality, safety, fraud prevention, operations |
| Safety reports | private service incidents and staff resolution notes | safety, abuse prevention and dispute handling |
| Optional contribution records | desired cash contribution amount and verification status | operational cost support; no electronic payment credentials are collected |
| Partner information | business display name/type, contact phone, capacity, verification state, terms acceptance | verification and delivery of approved community services |

## Sharing / disclosure review

Do not answer the Play Console's “data shared” question mechanically from this document. Apply Google's current definitions and exemptions.

- Supabase and Google act as technical service providers for the functions described above.
- In item-delivery workflows, donor and beneficiary identity are not disclosed to each other; Ruhamaa staff/couriers receive only operational data required for their assigned task.
- In an in-person service match, after the required parties accept and Ruhamaa coordinates the match, the minimum contact/location/scheduling data necessary to perform the service may be disclosed to the matched provider or verified partner.
- A verified partner is prohibited from using beneficiary data for marketing, photography/publication, unrelated sales, or building a customer list from Ruhamaa data.
- Before selecting “no data shared” in Play Console, explicitly determine whether disclosure to an external verified partner qualifies for Google's user-initiated/service-provider exemption under the current Data Safety definitions. If it does not, declare the applicable shared data categories instead of understating collection/sharing.

## Location notes

- The app may process precise coordinates where needed for delivery/service operations.
- Ruhamaa does not perform continuous background location tracking in the current version.
- Courier/user location can be captured at specific operational events such as handoff or failure reporting.

## Financial-data notes

- There is no Google Play Billing flow and no in-app electronic payment in the current product.
- Optional delivery-operation contributions are cash-to-courier pledges/records.
- Ruhamaa does not collect card numbers, bank-account credentials, wallet credentials, or payment authentication secrets.
- Re-check Google's current Data Safety definition of “financial info / purchase history / other financial info” before submission to decide whether the contribution amount/status belongs in a financial-data category.

## Security and deletion

- Supabase Row Level Security and role checks restrict access to operational tables.
- Donation image storage is private.
- Sensitive server credentials are not embedded in the mobile app.
- Account deletion can be requested in-app and on the public deletion page.
- Open fulfillment/service operations may need to be closed before deletion is completed.
- Limited records may be retained where necessary for safety, fraud prevention, a live dispute/incident, or legal obligations, with personal data minimized where possible.

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
