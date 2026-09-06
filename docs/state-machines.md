# Sanad V1 State Machines

## Donation

```text
draft
  -> submitted
  -> under_review
  -> available
  -> matched
  -> pickup_scheduled
  -> picked_up
  -> out_for_delivery
  -> delivered
```

Terminal/exception states: `cancelled`, `rejected`.

## Need

```text
submitted
  -> waiting
  -> candidate_found
  -> confirmed
  -> matched
  -> delivery_scheduled
  -> fulfilled
```

Terminal/exception states: `cancelled`, `expired`.

## Delivery

```text
assigned
  -> heading_to_pickup
  -> picked_up
  -> heading_to_recipient
  -> delivered
```

Exception states: `failed`, `rescheduled`.

## Operational contribution

```text
pending -> verified
pending -> rejected
verified -> refunded
```

## Key invariants

1. A donation cannot be `delivered` unless its delivery is `delivered`.
2. A need cannot be `fulfilled` unless the corresponding delivery is `delivered`.
3. Pickup and delivery must use different PINs.
4. Donor and beneficiary must not receive each other's private profile/address data.
5. A verified payment reference cannot be reused.
6. Risk flags never silently delete or alter user requests; sensitive action requires a documented review decision.
7. Courier access is scoped to assigned deliveries only.
