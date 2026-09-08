# Ruhamaa Visual Experience V2 — Approved Direction

Status: implemented baseline; Visual System V3 refines it with the approved high-depth card direction.

## Visual System V3

- Bundled `Tajawal` Arabic family (400/500/700/800/900), with no runtime font download.
- Deep Ruhamaa green hero gradient; the external reference's blue is not copied.
- White elevated cards with 28–30px corners and soft, low-opacity shadows.
- Colored circular or rounded-square icon badges that identify action families.
- Active-operation card with a clear status label, action chip and visual progress line.
- Light mint page gradient and a clean white bottom navigation bar.
- Compact-phone and RTL behavior remain release gates; no user data, matching logic or workflow is changed by this visual stage.

## Experience principles

Ruhamaa should feel:

- warm, not sentimental
- trustworthy, not bureaucratic
- human, not marketplace-like
- dignified for donor and beneficiary alike
- simple enough for first-time and low-literacy mobile users

## Core palette

- Primary trust green: `#226B5E`
- Primary dark: `#174D45`
- Soft green: `#E8F2EF`
- Warm sand/gold: `#D7A24B`
- Warm gold surface: `#FFF3DA`
- Warm surface: `#FFFDF8`
- App background: `#F7F8F5`
- Main text: `#1C2D29`
- Muted text: `#61706B`

## First-launch introduction

Shown on first app launch and persisted locally after completion or skip.

Four swipeable pages:

1. **Welcome to Ruhamaa**
   - purpose of the service
   - donation-to-need matching with dignity
2. **How it works**
   - add a donated item or register a need
   - Ruhamaa reviews/matches privately
   - Ruhamaa courier handles pickup and delivery
3. **Privacy first**
   - donor and beneficiary do not learn each other's identity
   - operations/courier see only what is needed to perform the task
4. **Delivery contribution is optional**
   - optional contribution amounts: 1000 / 2000 / 3000 / 4000 / 5000 YER
   - these are optional operating contributions, not a fixed service price
   - no in-app payment or transfer
   - cash is handed to the Ruhamaa courier
   - inability to contribute does not prevent service or reduce need priority

## Community home

Visual hierarchy:

1. Large primary action: **أعطي شيئًا**
2. Large primary action: **أحتاج شيئًا**
3. Secondary actions: **المطابقات** and **عملياتي**
4. Privacy reassurance
5. Bottom navigation: الرئيسية / المطابقات / عملياتي / حسابي

## Donation flow

- category grid instead of a dropdown
- human copy: **أرسل عطائي** rather than a transactional submit label
- condition choice chips
- photos are visually separated from text details
- donor identity reassurance stays visible

## Need flow

- category grid
- replace “لماذا تحتاجه؟” with **تفاصيل تساعدنا في فهم احتياجك**
- clearly state that details are private and not shown to the donor
- optional acceptance of used items in good condition
- no donation browsing

## Match moment

Treat a match as a positive success moment:

- **وجدنا شيئًا يناسب احتياجك ✨**
- item + condition
- explicit privacy card
- primary action: **نعم، ما زلت أحتاجه**
- secondary action: **لم أعد أحتاجه**

No donor identity or marketplace browsing.

## Delivery journey

Never expose raw technical states such as `assigned`, `picked_up`, or `heading_to_recipient` to the community user.

Use an Arabic visual journey:

1. تم قبول المطابقة
2. يجري ترتيب الاستلام
3. استلم الموصل العطاء
4. في الطريق للتسليم
5. تم التسليم

PIN copy must refer to **موصل رحماء**.

## Contribution screen

- lead with: **المساهمة اختيارية تمامًا**
- no payment inside the app
- cash only to the Ruhamaa courier at the relevant physical handoff
- no contribution-based priority
- keep amount selection visually simple

## Delivery profile

Lead with a privacy card:

- **موقعك خاص**
- exact location is for pickup/delivery operations only
- it is not shown to the other party

## Anti-patterns

Do not introduce:

- marketplace browsing
- public donor/beneficiary profiles
- leaderboards or competitive donation points
- poverty imagery or humiliating copy
- sadness-based engagement
- direct donor-beneficiary chat in V1
- financial contribution as eligibility/matching priority
