# Ataa V1 State Machines

This document mirrors the PostgreSQL enum/check states in `supabase/migrations` and, for each enum value, whether any committed function actually sets it. Last reconciled on 11 October 2026 against the migration chain up to `0060_courier_dispatch_v2_postdeploy_verification.sql` and `20260909235810_e2e_security_closure.sql`. Not every transition is legal from every preceding state; privileged workflow changes remain server/admin controlled.

"Reserved" below means: the value exists in the enum (PostgreSQL enum values cannot be dropped cheaply) but no committed function or policy writes it. Do not build UI or reports that wait for a reserved state.

## Donation (`donation_status`)

```text
submitted            set by the server on insert; a client cannot choose another initial status
  → under_review     staff review, or warehouse intake waiting for inspection
  → available        approved, or inspection/repair finished and ready for distribution
  → matched          a private match offer exists
  → pickup_scheduled admin_create_delivery
  → picked_up        courier verified the pickup PIN
  → delivered        courier verified the delivery PIN
```

Terminal/exception states: `cancelled` (`user_cancel_donation`, only before matching), `rejected` (review rejection, or the item was recycled after inspection).

Reserved, never set:

- `draft` — there is no draft-saving flow; a donation is created as `submitted`.
- `out_for_delivery` — the donation stays `picked_up` while the delivery is `heading_to_recipient`, then becomes `delivered`.

## Need (`need_status`)

```text
submitted              set by the server on insert
  → waiting            reviewed and waiting for a suitable donation
  → candidate_found    a candidate donation was identified
  → matched            the beneficiary accepted a private match offer
  → delivery_scheduled admin_create_delivery
  → fulfilled          courier verified the delivery PIN
```

Terminal/exception state: `cancelled` (`user_cancel_need`, only before matching).

Reserved, never set:

- `expired` — there is no expiry job; old needs stay in their last state until staff or the user acts.
- `confirmed` — accepted as a cancellable state by `user_cancel_need`, but no function moves a need into it.

## Delivery (`delivery_status`) — Courier Dispatch V2

Defined by `0059_courier_dispatch_v2.sql`; PIN expiry and attempt limits come from `20260909235810_e2e_security_closure.sql`.

```text
assigned               admin_create_delivery / admin_reassign_delivery
                       an offer to one courier; offer_expires_at = assigned_at + 30 minutes
  → heading_to_pickup  courier_respond_delivery(accept) before the offer expires
  → picked_up          verify_delivery_pin(kind = pickup)
  → heading_to_recipient  courier_start_dropoff
  → delivered          verify_delivery_pin(kind = delivery)
```

Rules that hold at each step:

- **Assignment is an offer, not an order.** The courier must accept. Declining requires a reason (`unavailable`, `too_far`, `vehicle_issue`, `schedule_conflict`, `other`), unassigns the courier and vehicle, and moves the delivery to `rescheduled`. An expired offer cannot be accepted; an admin reassigns it.
- **PINs are issued by the other party, on demand.** The donor can issue the pickup PIN only while the delivery is `heading_to_pickup`; the recipient can issue the delivery PIN only while it is `heading_to_recipient` (`user_issue_handoff_pin`). The admin does not see or set PINs.
- **A PIN is four digits, stored hashed, valid for 10 minutes and for at most 5 attempts.** A wrong, expired or exhausted PIN returns `false`, counts an attempt and raises an `INVALID_DELIVERY_PIN` risk flag. The hash is cleared after a successful verification.
- **Courier visibility is phase-scoped.** Pickup area is visible from `assigned`; the donor's address, coordinates and phone only in `heading_to_pickup`; the recipient's only in `picked_up` and `heading_to_recipient`.
- **Completion updates the item chain.** Pickup sets the donation to `picked_up`; delivery sets the donation to `delivered` and the need to `fulfilled`.
- Every transition writes a `delivery_events` row and an `audit_logs` row; `dispatch_attempt` increases on each reassignment.

Exception/recovery states (as refined by `20261011090000_audit_hardening.sql` and `20261011120000_review_fixes.sql`):

- `rescheduled` — reached when the courier declines the offer, reports a failure with `courier_report_delivery_failure` (allowed only in `heading_to_pickup`, `picked_up`, `heading_to_recipient`; after pickup the party cannot be the donor), or an admin pauses an accepted delivery with `admin_pause_delivery`. PIN material is cleared. The courier can take no action until an admin reassigns.
- `admin_reassign_delivery` is allowed from `assigned` and `rescheduled`, starts a new 30-minute offer and, on acceptance, resumes at the right phase: `heading_to_pickup` if the item was never collected, `picked_up` if it was. Once an item has been collected it cannot be reassigned to a different courier; the admin cancels instead so the item returns through intake.
- `failed` — terminal. Written only by `admin_cancel_delivery(delivery, reason)`: the match is cancelled, the need returns to `waiting`, and the donation returns to `available` (never collected) or `under_review` (already collected). `delivered` deliveries cannot be cancelled.
- PIN hashes are salted with the delivery id. A missing or expired PIN returns `false` without raising a risk flag; only a wrong guess against a live PIN raises `INVALID_DELIVERY_PIN`.
- Cash pledges (`cash_to_courier` contributions by the two parties) are shown to the assigned courier during the active legs and for 24 hours after delivery; the courier's received / not-received answer is write-once and an admin cannot verify a pledge the courier marked as not received.
- Repeated no-show style failures by the same donor or beneficiary within 60 days raise a `REPEATED_DELIVERY_NO_SHOW` risk flag for human review; they do not change eligibility automatically.

## Operational contribution (`contribution_status`)

```text
pending → verified
pending → rejected
```

New contributions use `cash_to_courier` and are created as `pending` by the server. Verification means staff has confirmed physical receipt; new flows do not depend on a transfer reference.

Reserved, never set: `refunded` — there is no refund flow, because no electronic payment is processed.

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
3. A delivery becomes `delivered` only when the assigned courier verifies the recipient-issued PIN; the same transaction sets the donation to `delivered` and the need to `fulfilled`.
4. Cash contribution status does **not** increase item/service eligibility or match priority.
5. New contributions remain `pending` until physical cash receipt is confirmed and verified by staff.
6. A service match requires the relevant provider/requester consent before scheduling.
7. A provider/partner receives only the operational information required for an accepted in-person service, not the user’s unrelated history.
8. An unverified/suspended partner cannot operate as an approved Ataa business provider.
9. Partner activity scope and monthly capacity are enforced server-side, not only in UI.
10. Risk flags and service incidents are review evidence; they do not silently delete needs or automatically convict/suspend a participant without the configured staff workflow.
11. Courier visibility remains scoped to assigned deliveries and to the current phase of each delivery.
12. The initial status of a donation, need or contribution is set by the server, never by the client.
