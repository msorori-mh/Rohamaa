# P2 UAT — Item recovery and inventory

This gate validates the complete non-food, non-medical recovery path on a physical Android device. Run it with one normal-user account and one admin account.

## Preconditions

- The build uses `com.ruhamaa.app` and the current Supabase project.
- The admin account can open **التأهيل والمخزون**.
- The normal user can create an item donation.
- Do not use food, medicine, treatment requests, or medical consumables in this test.

## A. Warehouse and intake

1. Sign in as admin and create one warehouse with a unique code and a clear internal name.
2. Sign in as a normal user, create a non-food item donation, and record its public code.
3. Return as admin. Confirm that the donation appears under **وارد ينتظر الاستلام** and in the main priority queue only once.
4. Receive it into the warehouse and optionally enter a shelf/bin reference.
5. Confirm that it leaves the intake list and appears in the inspection queue.
6. As the donor, open **مركز المتابعة** and confirm that only the public operational state is shown—no warehouse, shelf, staff note, cost, or partner detail.

## B. Grade A — ready directly

1. Inspect a fresh item as **A**.
2. Confirm that its recovery state becomes **جاهز للتوزيع** and the donation is available for normal matching.
3. Confirm that the donor receives one in-app status notification and can still scroll to the bottom of the page on the phone.

## C. Grade B — cleaning

1. Inspect a fresh item as **B** with an optional estimated cost.
2. Start the cleaning work order, then complete it with an optional actual cost.
3. Confirm the sequence: queued → cleaning → ready for distribution.
4. Confirm the actual cost is reflected in the recovery summary but is not visible to the donor.

## D. Grade C — repair

1. Inspect a fresh item as **C**.
2. Start and complete the repair order.
3. Confirm the item becomes ready for distribution and returns to the matching path.

## E. Grade D — recycling

1. Inspect a fresh item as **D**.
2. Confirm recycling with material type and, when known, weight and proceeds.
3. Confirm the recovery state becomes **تمت إعادة التدوير**, the donation no longer enters matching, and the proceeds are reflected in the summary.

## F. Authorization and regression

1. As a normal user, confirm there is no route to the admin recovery screen and no direct warehouse/inventory data is visible.
2. Confirm the main admin queue opens recovery items in the recovery screen.
3. Sign out and back in with the other account; verify page scrolling and the sign-out control on the relevant home screen.
4. Run `flutter analyze` and `flutter test` with no failures.

## PASS / HOLD

**PASS** only when A–F all succeed and donor-facing screens contain no internal location, note, cost, staff, or partner detail. Otherwise record the exact step, public code, device model, and screenshot, and mark **HOLD**.
