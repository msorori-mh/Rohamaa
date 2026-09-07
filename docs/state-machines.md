# Ruhamaa V1 State Machines

This document mirrors the current live PostgreSQL enum/check states used by the Marib pilot. Not every transition is legal from every preceding state; privileged workflow changes remain server/admin controlled.

## Donation

```text
draft
  → submitted
  → under_review
  → available
  → matched
  → pickup_scheduled
  → picked_up
  → out_for_delivery
  → delivered
```

Terminal/exception states: `cancelled`, `rejected`.

## Need

```text
submitted
  → waiting
  → candidate_found
  → confirmed
  → matched
  → delivery_scheduled
  → fulfilled
```

Terminal/exception states: `cancelled`, `expired`.

## Delivery

```text
assigned
  → heading_to_pickup
  → picked_up
  → heading_to_recipient
  → delivered
```

Exception/recovery states: `failed`, `rescheduled`.

## Operational contribution

```text
pending → verified
pending → rejected
verified → refunded
```

New contributions use `cash_to_courier`. Verification means staff has confirmed physical receipt; new flows do not depend on a transfer reference.

## Service offer

Allowed status values:

```text
submitted → approved → matched → completed
          ↘ paused
          ↘ rejected
          ↘ cancelled
```

Verification values: `pending`, `verified`, `rejected`.

Provider kinds: `person`, `business`.

Pricing modes in V1: `free`, `materials_only`.

## Service request

```text
submitted → reviewing → matched → scheduled → completed
          ↘ rejected
          ↘ cancelled
```

## Service match / consent

Match status values:

```text
proposed → accepted → scheduled → completed
         ↘ declined
         ↘ cancelled
```

Provider response and requester response each independently use:

```text
pending → accepted
pending → declined
```

Scheduling is not permitted until the required acceptance state is reached.

## Verified Partner

Verification values:

```text
pending → verified
pending → rejected
verified → suspended
suspended → verified   (staff reactivation after review)
```

A business service offer is only valid when linked to an eligible partner owned by the provider account and the service category is allowed for that partner kind. Candidate selection also respects monthly case capacity.

## Service incident

```text
open → reviewing → resolved
                 ↘ dismissed
```

Incident types:

- `unexpected_charge`
- `privacy`
- `photo_marketing`
- `no_show`
- `conduct`
- `quality`
- `other`

Incidents are private operational reports, not public reviews.

## Core invariants

1. Donor and beneficiary do not receive each other’s private profile/address data in item operations.
2. Pickup and delivery use distinct PINs; user/courier access is scoped to the relevant operation.
3. A delivery becomes `delivered` only through the controlled delivery workflow; corresponding item fulfillment state follows the delivery chain.
4. Cash contribution status does **not** increase item/service eligibility or match priority.
5. New contributions remain `pending` until physical cash receipt is confirmed and verified by staff.
6. A service match requires the relevant provider/requester consent before scheduling.
7. A provider/partner receives only the operational information required for an accepted in-person service, not the user’s unrelated history.
8. An unverified/suspended partner cannot operate as an approved Ruhamaa business provider.
9. Partner activity scope and monthly capacity are enforced server-side, not only in UI.
10. Risk flags and service incidents are review evidence; they do not silently delete needs or automatically convict/suspend a participant without the configured staff workflow.
11. Courier visibility remains scoped to assigned deliveries.
