# Sanad V1 — Pilot Execution Plan

Target: launch a controlled pilot in Marib with two couriers and two electric motorbikes, reach the first 1,000 completed handoffs, and measure social impact, fraud rate, delivery cost, and contribution coverage.

## Phase 0 — Foundation

- [x] Flutter/Supabase skeleton
- [x] Google-auth-ready bootstrap
- [x] Donations / needs / addresses / matches / deliveries / contributions schema
- [x] Private donation-image storage
- [x] Courier PIN verification baseline
- [x] Risk flags and audit logs

## Phase 1 — Security and database hardening

- [x] Role-based admin/courier authorization helpers
- [x] Admin queue RPCs
- [x] Matching score function and review queue
- [x] Contribution verification RPC
- [x] Courier minimum-information task RPC
- [x] Delivery creation with server-generated PIN hashes
- [ ] Apply all migrations to Supabase project `vclicpejajxadsbuakdw`
- [ ] Seed the two courier accounts and two electric motorbikes

Exit criteria: no direct donor↔beneficiary identity exposure; privileged writes require admin/courier role.

## Phase 2 — Community app

- [x] Arabic RTL shell
- [x] Google login screen
- [x] Profile/address capture
- [x] Donation creation
- [x] Need creation
- [ ] Force onboarding completion before operational actions
- [ ] Image picker + resize/compression + private upload
- [ ] Contribution selector (1,000–5,000 YER) attached to donation/need
- [ ] My donations / my needs / status history
- [ ] Impact summary

Exit criteria: a normal user can register, set delivery details, create a donation/need, contribute to operations, and track status without seeing another party's identity.

## Phase 3 — Operations/admin web UI (same Flutter codebase)

- [x] Backend admin queue primitives
- [ ] Role-aware route guard
- [ ] Dashboard KPIs
- [ ] Donation review queue
- [ ] Need review queue
- [ ] Match candidate review / approve
- [ ] Courier assignment
- [ ] Contribution verification
- [ ] Risk-review queue
- [ ] Vehicle/courier status

Exit criteria: pilot staff can run the full workflow without SQL console access.

## Phase 4 — Courier workflow

- [x] Assigned task list baseline
- [x] Pickup/delivery PIN verification baseline
- [ ] Minimum-information pickup/drop-off detail screen
- [ ] One-tap phone call only when operationally necessary
- [ ] GPS event capture at pickup/delivery
- [ ] Failure/reschedule reasons
- [ ] Daily completed-task summary

Exit criteria: courier can perform a task without seeing donor/beneficiary stories or unrelated data.

## Phase 5 — Fraud and abuse controls

- [x] Risk flags table
- [x] Invalid PIN risk event
- [x] Payment reference uniqueness for verified contributions
- [x] Matching score considers history and distance where available
- [ ] Repeated-same-category request rule
- [ ] High request velocity rule
- [ ] No-show / cancellation rule
- [ ] Suspicious multi-account/device signal (signal only, never automatic guilt)
- [ ] High-value-item manual review policy
- [ ] Admin resolution reasons and immutable audit records

Exit criteria: high-risk actions enter manual review and no sensitive social decision is made solely by AI.

## Phase 6 — Testing and pilot readiness

- [ ] Unit tests for scoring and state transitions
- [ ] RLS regression tests
- [ ] 1,000-operation synthetic fraud simulation dataset
- [ ] Failure-mode test: wrong PIN, duplicate payment, stale need, courier no-show, user cancellation
- [ ] Android release configuration and deep links
- [ ] Google OAuth production configuration
- [ ] Privacy policy / terms / prohibited items policy
- [ ] Backup/export procedure
- [ ] Pilot operations playbook

## Pilot KPIs

1. Fulfilled needs
2. Delivery success rate
3. Median time to match
4. Median time from match to delivery
5. Cost per fulfilled need
6. Contribution coverage = verified operational contributions / operating cost
7. Review/risk rate
8. Confirmed abuse rate
9. No-show rate
10. Repeat donor rate

## Cost-control rules

- One Flutter codebase for Android + admin web.
- Supabase/Postgres as the single backend for V1.
- No independent delivery routing platform in V1.
- No donor-beneficiary chat.
- No marketplace/feed.
- No SMS OTP dependency.
- No service-role key in client applications.
- Manual review is acceptable for the first 1,000 operations when automation would increase risk or cost.
