# Ruhamaa — 1,000-operation synthetic abuse stress test

This document records an **early adversarial simulation**, not a prediction of Marib abuse rates and not a current measured detection rate. The generator intentionally overrepresented abuse to expose design gaps before pilot operation.

Original seed: `260906`

## Original generated population

| Scenario | Count |
|---|---:|
| Legitimate | 786 |
| Fake / high-velocity need | 49 |
| Repeat-category / potential resale | 35 |
| PIN attack | 30 |
| No-show | 29 |
| Bad / misrepresented item | 23 |
| Legacy fake-payment-evidence scenario | 20 |
| Collusion | 16 |
| Address churn / abuse | 12 |
| **Total** | **1,000** |

Potential abuse cases in the early stress set: **214**.

## How to interpret the old result

The original baseline reported 138/214 synthetic abuse cases surfaced by the controls available at that early point. That percentage must **not** be presented as the current Ruhamaa fraud-detection rate:

- the simulation was synthetic;
- thresholds were deliberately chosen around the generated data;
- the product and controls have changed materially since then;
- real false-positive and false-negative rates are unknown until pilot data exists.

Every signal remains a review input, not automatic proof that a person is abusing the service.

## Scenario status under the current product

### High request velocity / repeated equivalent needs

These remain useful risk signals. Reviewed-needs abuse safeguards and operational risk flags can surface unusual request patterns for human review. They do not automatically reduce eligibility.

### PIN attacks

Pickup and delivery use separate PINs, and invalid verification attempts can be recorded as security/risk events. PINs are operational handoff controls, not identity scores.

### No-show / rescheduling

Delivery failure/reschedule reason records now exist, giving the pilot enough history to identify repeated no-show patterns. Policy remains: a single missed appointment is not automatic proof of abuse.

### Misrepresented or unusable items

Metadata alone cannot reliably determine item quality. Human/courier inspection, clear condition description/photos and an operational rejection/failure path are more appropriate than automated accusations.

### Legacy fake-payment-evidence scenario

The original simulation assumed transfer/payment-reference evidence. **That is no longer the new contribution flow.** New contributions use `cash_to_courier`; there is no in-app transfer reference or screenshot-verification process.

Current risk is instead false/manual cash-receipt confirmation or operational reconciliation error. A contribution remains `pending` until physical receipt is confirmed and staff verifies it. Contribution status never increases a user’s eligibility priority.

Historical `manual_transfer` rows may remain for compatibility with old records only.

### Collusion

Collusion remains difficult to infer reliably in a low-volume pilot. Ruhamaa keeps operational/audit records sufficient for later pattern review (participant IDs, courier, match, timestamps and relevant event locations) but intentionally avoids invasive device fingerprinting or an automated social-credit system.

### Address churn

Unusual address/location changes can be a review signal when paired with other behavior, but legitimate displacement or movement must not be treated as fraud by default.

### Service / partner abuse (added after the original simulation)

The current product also needs to detect operational problems not represented in the original item-only simulation:

- partner/provider requests an undisclosed charge;
- partner photographs/markets a beneficiary;
- repeated provider/requester no-show;
- unsafe conduct or materially poor execution;
- partner attempts a service category outside its verified activity;
- partner exceeds stated monthly capacity.

Current controls include partner verification/suspension, backend category scope, monthly candidate-capacity enforcement, bilateral consent, private service incidents and admin review.

## Pilot tuning plan

After real Marib operations begin:

1. Separate **signals**, **staff-reviewed concerns**, and **confirmed abuse** in reporting.
2. Measure false positives/false negatives from reviewed cases rather than assuming synthetic rates.
3. Tune request-velocity/repeat/no-show thresholds only after enough legitimate behavior is observed.
4. Review high-impact safety cases manually even if their statistical frequency is low.
5. Keep contribution behavior out of beneficiary priority scoring.
6. Review partner incident patterns and capacity breaches separately from beneficiary eligibility.
7. Avoid adding invasive device/fingerprint surveillance unless a documented safety problem cannot be solved with less intrusive controls.

The pilot goal is not to maximize automatic flagging; it is to protect resources and participants while preserving dignity and avoiding unjust exclusion.
