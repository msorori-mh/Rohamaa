# Sanad V1 Architecture

## Product boundary

Sanad V1 launches in Marib and supports physical-item donations matched to pre-existing needs. It intentionally does not expose a free-item marketplace.

## Surfaces

### Community mobile app
- Google sign-in
- Profile and saved addresses
- Create donation
- Create need
- Track own requests/donations
- Confirm match
- View operational contribution status
- View impact summary

### Courier mode
- Assigned pickup/drop-off tasks only
- Minimum necessary contact/location data
- Pickup and delivery PIN confirmation
- GPS event capture only at relevant delivery events
- No visibility into beneficiary/donor stories

### Admin web dashboard
- Review new donations and needs
- Review suggested matches
- Assign couriers/vehicles
- Verify payment references
- Resolve risk flags
- Inspect delivery chain of custody
- Monitor unit economics and impact metrics

## Privacy model

Donor and beneficiary must never receive one another's identity, phone number, exact address, Google identity, or profile.

Operational staff receive only data required for their role.

## Matching model

V1 uses deterministic scoring plus human approval.

Suggested starting score:

- category/item compatibility: +40
- distance under 3 km: +20
- older need: +15
- no recent equivalent fulfillment: +10
- positive account history: +10
- optional operating contribution: max +5

Ability to contribute must never dominate eligibility.

## Fraud model

Signals are evidence for review, not automatic proof of abuse.

Initial rules include:
- unusually high request velocity
- repeated equivalent need after recent fulfillment
- repeated no-show/cancellation
- repeated high-value item requests
- suspicious location changes
- duplicated verified payment reference
- unusual multi-account patterns
- courier delivery event inconsistent with expected location

High-risk actions should be reviewed by an admin.

## Financial model

Operational contributions are voluntary and may be made by donor or beneficiary. Donation of the physical item remains separate from financial contribution.

The ledger stores amount, method, payment reference, verification state and related Sanad operation.

Screenshots alone are not considered sufficient proof of payment.

## Cost model

Primary operating costs:
- two couriers
- electric motorbike charging and maintenance
- connectivity
- backend/storage
- payment fees if applicable
- incidentals

Primary sustainability metrics:
- fulfilled needs
- cost per fulfilled need
- contribution coverage ratio

## Technology direction

- Flutter community app
- Supabase Auth + PostgreSQL + Storage
- server-side trusted operations using Supabase Edge Functions or equivalent
- admin dashboard using a lightweight web stack
- Firebase Cloud Messaging for push notifications if required

No service-role key may be embedded in the client application.
