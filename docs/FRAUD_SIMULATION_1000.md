# Fraud Simulation — 1,000 Synthetic Operations

This is an adversarial synthetic test, not a prediction of real Marib fraud rates. Abuse frequency was intentionally elevated to expose gaps before pilot launch.

Seed: `260906`

## Generated population

| Scenario | Count |
|---|---:|
| Legitimate | 786 |
| Fake / high-velocity need | 49 |
| Repeat-category / potential resale | 35 |
| PIN attack | 30 |
| No-show | 29 |
| Bad / misrepresented item | 23 |
| Fake payment evidence | 20 |
| Collusion | 16 |
| Address churn / abuse | 12 |
| **Total** | **1,000** |

Potential abuse cases in this stress test: **214**.

## Coverage by rules implemented through migration 0006 + existing controls

Detected synthetic abuse cases: **138 / 214 (64.5%)**.

- High request velocity: 49/49 flagged.
- Recently fulfilled same category: 35/35 flagged.
- Invalid delivery PIN attempts: 30/30 flagged.
- Address churn: 12/12 flagged.
- Duplicate payment-reference behavior: 12/20 surfaced by uniqueness/reference checks in this generated sample.

The simulation produced zero synthetic false positives among the generated `legit` category because the generator deliberately kept legitimate behavior below the configured thresholds. **This does not imply a zero real-world false-positive rate.** Every signal must remain a manual-review signal, not an automatic fraud conviction.

## Current gaps exposed

### 1. No-show / repeated cancellation

29 generated cases are not covered by the current automatic rules. Add delivery failure reason codes and rolling no-show/cancellation counters. Recommended policy: signal after repeated failed appointments; do not suspend on a single miss.

### 2. Misrepresented / unusable donations

23 generated cases are not reliably detectable from metadata. Operational control should be courier pickup inspection + pickup photo + rejection reason. High-risk/high-value categories should require manual review.

### 3. Collusion

16 generated cases are difficult to identify reliably without enough history. V1 should collect audit events sufficient for later graph analysis: courier, donation, need, timestamps, approximate operational locations, payment references, and repeated pairings. Do not build invasive device fingerprinting for the pilot.

### 4. Fake payment evidence

Reference uniqueness catches reuse but not a completely fabricated unique reference. Payment stays `pending` until a human verifies it against the receiving account. Screenshots never verify payment.

## Next controls to implement

1. Delivery failure/reschedule reason table and no-show risk rule.
2. Courier pickup condition confirmation and optional pickup evidence image.
3. High-value-category review rule.
4. Contribution reconciliation export/view for manual account checking.
5. Risk resolution workflow with documented reasons (backend RPC added in migration 0006).
6. After the first 250 real operations, tune thresholds from observed legitimate behavior before increasing automation.
