# Ruhamaa — Google Play / Android release checklist

This is the release checklist for the current Marib pilot build. Detailed signing commands live in `docs/ANDROID_RELEASE.md`; Data Safety source-of-truth lives in `docs/PLAY_DATA_SAFETY.md`. Do not duplicate secrets in this file.

## 1. Fixed Android identity

- Application ID: `com.ruhamaa.app`
- Internal/mobile OAuth callback: `com.ruhamaa.app://login-callback`
- Production domain: `https://ruhamaa.com`
- Future verified App Link callback: `https://ruhamaa.com/login-callback`
- Google Web OAuth callback through Supabase: `https://vclicpejajxadsbuakdw.supabase.co/auth/v1/callback`
- Current Android target SDK configured by the project: API 36

Do not change `com.ruhamaa.app` after the Play Console app is created/uploaded under that package.

## 2. Public web endpoints

The release expects these public URLs:

- `https://ruhamaa.com/`
- `https://ruhamaa.com/privacy/`
- `https://ruhamaa.com/terms/`
- `https://ruhamaa.com/delete-account/`
- `https://ruhamaa.com/login-callback`
- `https://ruhamaa.com/.well-known/assetlinks.json` — only after the Play App Signing SHA-256 is known

The repository contains the static site under `site/`. GitHub Pages is configured to deploy production content from `main` after merge.

Before store submission, verify the URLs in a normal unauthenticated browser and verify `support@ruhamaa.com` / `privacy@ruhamaa.com` receive mail.

## 3. Google Auth Platform

Branding/authorized-domain configuration should use:

- App name: `Ruhamaa` / `رحماء`
- Home page: `https://ruhamaa.com/`
- Privacy: `https://ruhamaa.com/privacy/`
- Terms: `https://ruhamaa.com/terms/`
- Authorized domain: `ruhamaa.com`

Keep OAuth scopes minimal: basic OpenID profile/email only. Do not add Gmail, Drive, Contacts or other scopes unless a real feature is introduced and the privacy/Data Safety review is updated.

Supabase Auth must allow `com.ruhamaa.app://login-callback` for the first internal mobile build. Do not switch the production mobile redirect to HTTPS until Android App Link verification is complete on a Play-installed build.

## 4. Physical-device release identity gate

Follow scenario 0 in `docs/UAT_CATEGORY_V2_PARTNERS.md`.

Required before first Play upload/reviewer use:

- installed package resolves as `com.ruhamaa.app`;
- normal-user Google OAuth returns to the app and creates/restores a session;
- primary-admin Google OAuth returns to the app and role gate is correct;
- no stale old-package deep-link loop remains.

## 5. Release signing

Follow `docs/ANDROID_RELEASE.md`.

Repository safeguards already in place:

- release Gradle tasks fail without complete signing configuration;
- keystore and `key.properties` are gitignored;
- CI signing passwords/alias are injected through environment variables;
- `.github/workflows/android_release_bundle.yml` builds a signed AAB only when the documented GitHub Actions secrets are configured.

The upload keystore must be generated once on a trusted machine, stored outside the repository and backed up securely. Never paste private-key material or passwords into issues, PR comments or source files.

## 6. First Internal Testing AAB

After the release workflow exists on the default branch and signing secrets are configured:

1. Run **Android Release Bundle** manually.
2. Use a monotonically increasing `build_number` / Android versionCode.
3. Download the resulting signed AAB artifact and verify its SHA-256.
4. Create/select the Play Console app with package `com.ruhamaa.app`.
5. Upload the AAB to Internal Testing and enroll in Play App Signing as required by the current Play flow.
6. Install the Play-distributed build and repeat login/UAT smoke tests.

Do not upload a debug-signed APK/AAB as a production artifact.

## 7. Play App Signing → Android App Links

After the first Play upload:

1. Copy the **App signing certificate SHA-256**, not the upload-certificate fingerprint.
2. Create `site/.well-known/assetlinks.json` from `assetlinks.json.template` and replace the placeholder fingerprint.
3. Merge/deploy the site and verify the JSON is publicly reachable.
4. Re-verify on the device:

```powershell
adb shell pm verify-app-links --re-verify com.ruhamaa.app
adb shell pm get-app-links com.ruhamaa.app
adb shell am start -W -a android.intent.action.VIEW -d "https://ruhamaa.com/login-callback"
```

5. Only after the domain reports verified and the HTTPS link opens Ruhamaa should the production build use:

```text
AUTH_REDIRECT_URL=https://ruhamaa.com/login-callback
```

Keep the custom scheme available as an internal/fallback path until the HTTPS callback has been proven in the Play-distributed build.

## 8. Store listing draft

Suggested names:

- Arabic: `رحماء`
- English: `Ruhamaa`

Suggested short description:

`يوصل الأشياء والوقت والمهارات إلى احتياجات مناسبة بخصوصية وكرامة.`

Suggested full-description direction:

> رحماء منصة مجتمعية في مأرب تربط الأشياء التي لم يعد أصحابها بحاجة إليها، والوقت والمهارات والخدمات المجانية التي يستطيع أفراد أو شركاء موثّقون تقديمها، باحتياجات مسجلة مسبقًا. لا يتصفح المستفيد التبرعات ولا يختار المتبرع المستفيد. يراجع رحماء المطابقات بخصوصية، وفي عمليات الأشياء لا تُكشف هوية المتبرع للمستفيد أو هوية المستفيد للمتبرع. يمكن أيضًا تسجيل احتياج خدمة أو تقديم وقت/مهارة، وتتم المطابقة الخاصة بعد المراجعة والموافقة. شركاء رحماء يمرون بتحقق منفصل ويلتزمون بقواعد تمنع التصوير والتسويق والرسوم غير المتفق عليها. المساهمة في تكاليف التوصيل اختيارية ولا تؤثر على الاستحقاق، ولا يوجد دفع إلكتروني داخل التطبيق في التدفق الحالي.

Use screenshots with safe demo data only—no real names, phone numbers, addresses, coordinates, emails or private item photos.

## 9. App access / reviewer path

The app is login-gated for operational functionality. Prepare stable reviewer access according to the current Play Console App Access form.

At minimum, reviewer instructions should explain:

- how to sign in;
- how to reach a community flow without creating real operational harm;
- whether staff/admin screens need separate reviewer access;
- that no OTP/MFA may depend on a reviewer receiving a code they cannot access.

Never use a real beneficiary/donor account as the review credential.

## 10. Data Safety / permissions

Use `docs/PLAY_DATA_SAFETY.md` as the internal source of truth and compare it against the exact Play Console wording at submission time.

Current manifest permissions are:

- `INTERNET`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`

There is no background-location permission in the current manifest and no continuous tracking design.

Current product behavior also includes:

- private donation photos;
- user-generated donation/need/service text;
- service/partner operational data;
- private safety incident records;
- optional cash-to-courier contribution amount/status records;
- no targeted advertising and no data sale;
- account-deletion request in-app and on the public site.

Do **not** hard-code “no data shared” or “no financial information” without checking Google Play’s current definitions. In-person verified-partner services can involve user-initiated disclosure of minimum contact/location/scheduling data, and contribution amount/status may fall into a Play data category depending on the current form wording.

## 11. Other Play declarations

Complete the exact current Console forms truthfully for:

- Ads
- Target audience / age
- Content rating
- App Access
- Data Safety
- Financial features, if Play asks
- Any other app-content declarations currently required

The current product is designed for adults 18+, contains no ad SDK, has no public social feed/direct donor-beneficiary chat, and does not provide banking/wallet/loan/crypto/payment processing. Reconfirm the shipped code before every declaration.

Testing/production-access requirements can vary by Play developer-account type and current policy. Follow the requirements shown in the actual Play Console account at submission time rather than relying on a hard-coded tester-count/date rule in repository docs.

## 12. Final pre-submission gate

Do not submit for review until all are true:

- latest branch/default-branch CI passes migration-version validation, analyze, tests and Android build;
- PR/release source is conflict-free;
- public privacy/terms/delete-account pages load over HTTPS;
- support/privacy contact mailboxes work;
- `com.ruhamaa.app` Google OAuth succeeds on a physical device;
- release AAB is signed with the backed-up upload key;
- Play-installed build passes basic community/admin UAT;
- reviewer access works;
- Data Safety and permissions match the exact shipped code;
- Store Listing/App Access/content declarations are complete;
- real PII is absent from screenshots;
- Android App Links are verified before switching production OAuth to HTTPS.
