# Ruhamaa — Google Play + ruhamaa.com Release Checklist

## 0. One decision before the first AAB upload

Current Android application ID: `io.sanad.app`.

Once the first app bundle is uploaded to a Play Console app, the package/application ID becomes effectively permanent for that Play listing. If the brand should use a reverse-domain ID such as `com.ruhamaa.app`, make that change before the first AAB upload. Do not change it after production distribution begins.

This checklist assumes the current ID `io.sanad.app` until that decision is changed deliberately.

## 1. Public domain

Production URLs:

- Homepage: `https://ruhamaa.com/`
- Privacy policy: `https://ruhamaa.com/privacy/`
- Terms: `https://ruhamaa.com/terms/`
- Account deletion: `https://ruhamaa.com/delete-account/`
- Future OAuth App Link callback: `https://ruhamaa.com/login-callback`
- Android Digital Asset Links: `https://ruhamaa.com/.well-known/assetlinks.json`

The repository contains a static site under `site/` and a GitHub Pages deployment workflow. Enable GitHub Pages with GitHub Actions, then configure the domain DNS.

## 2. DNS for GitHub Pages

At the domain registrar/DNS provider, for the apex domain `ruhamaa.com`, add the four GitHub Pages A records:

- `185.199.108.153`
- `185.199.109.153`
- `185.199.110.153`
- `185.199.111.153`

Optional IPv6 AAAA records:

- `2606:50c0:8000::153`
- `2606:50c0:8001::153`
- `2606:50c0:8002::153`
- `2606:50c0:8003::153`

For `www`, use a CNAME to the repository owner's GitHub Pages domain if desired. Avoid wildcard DNS records.

After DNS resolves, enable **Enforce HTTPS** in GitHub Pages.

PowerShell checks:

```powershell
Resolve-DnsName ruhamaa.com -Type A
Invoke-WebRequest https://ruhamaa.com/ -UseBasicParsing
Invoke-WebRequest https://ruhamaa.com/privacy/ -UseBasicParsing
```

## 3. Mailboxes that must exist before submission

Create and test at least:

- `support@ruhamaa.com` — Play Store user support
- `privacy@ruhamaa.com` — privacy and account deletion

Do not publish the store listing until these addresses receive mail successfully.

## 4. Google Search Console / domain ownership

Using a Google account that is Owner/Editor of the Google Cloud OAuth project:

1. Add a **Domain property** for `ruhamaa.com` in Google Search Console.
2. Add the TXT record Search Console supplies to DNS.
3. Verify the domain.

Use the Domain property method rather than only a URL-prefix property.

## 5. Google Auth Platform / OAuth branding

Branding:

- App name: `Ruhamaa` / `رحماء`
- Application home page: `https://ruhamaa.com/`
- Privacy policy: `https://ruhamaa.com/privacy/`
- Terms of service: `https://ruhamaa.com/terms/`
- Authorized domain: `ruhamaa.com`
- Support email: an active project support email
- Developer contact email: an actively monitored address

Scopes should remain minimal:

- `openid`
- `https://www.googleapis.com/auth/userinfo.email`
- `https://www.googleapis.com/auth/userinfo.profile`

Do not add Gmail, Drive, Contacts, or other scopes unless a real feature requires them.

Current Google Web OAuth redirect URI via Supabase remains:

`https://vclicpejajxadsbuakdw.supabase.co/auth/v1/callback`

The mobile redirect can remain `io.sanad.app://login-callback` for the first internal Play build. After Android App Links are verified, move the production mobile redirect to:

`https://ruhamaa.com/login-callback`

and add that exact URL to Supabase Auth redirect URLs.

## 6. Android target API

The project explicitly targets Android 16 / API 36 for release readiness.

Before every Play release:

```powershell
cd C:\src\Rohamaa\app
flutter doctor -v
flutter analyze
flutter test
```

## 7. Create an upload keystore

Generate the upload keystore locally. Never commit it.

```powershell
cd C:\src\Rohamaa\app\android

keytool -genkeypair -v `
  -keystore .\upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias ruhamaa-upload
```

Let `keytool` prompt for passwords; do not put passwords on the command line.

Create the local signing properties file:

```powershell
Copy-Item .\key.properties.example .\key.properties
notepad .\key.properties
```

Set the local-only values:

```text
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=ruhamaa-upload
storeFile=../upload-keystore.jks
```

Both `key.properties` and keystore files are gitignored.

## 8. Build the first signed Android App Bundle

First internal-track build: keep the legacy OAuth callback until Play App Signing SHA-256 is available.

```powershell
cd C:\src\Rohamaa\app

$SUPABASE_URL = 'https://vclicpejajxadsbuakdw.supabase.co'
$SUPABASE_KEY = '<SUPABASE_PUBLISHABLE_KEY>'

flutter clean
flutter pub get
flutter analyze
flutter test

flutter build appbundle --release `
  "--dart-define=SUPABASE_URL=$SUPABASE_URL" `
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_KEY" `
  "--dart-define=AUTH_REDIRECT_URL=io.sanad.app://login-callback"
```

Expected AAB:

`build\app\outputs\bundle\release\app-release.aab`

Do not upload a debug-signed bundle.

## 9. Play App Signing and Android App Links

Create the app in Play Console and upload the first signed AAB to **Internal testing**. New apps use Play App Signing.

Then open:

**Test and release / Setup / App integrity / App signing** (wording may vary)

Copy the **SHA-256 certificate fingerprint for the App signing key**. Do not use the upload-key fingerprint for production `assetlinks.json`.

Create `site/.well-known/assetlinks.json` from the included template and replace:

`REPLACE_WITH_GOOGLE_PLAY_APP_SIGNING_SHA256`

with the Play App Signing SHA-256 fingerprint.

After deploying, verify:

```powershell
Invoke-WebRequest https://ruhamaa.com/.well-known/assetlinks.json -UseBasicParsing
adb shell pm verify-app-links --re-verify io.sanad.app
adb shell pm get-app-links io.sanad.app
```

When the domain reports verified, add this Supabase Auth redirect URL:

`https://ruhamaa.com/login-callback`

Then build the next bundle with:

```powershell
"--dart-define=AUTH_REDIRECT_URL=https://ruhamaa.com/login-callback"
```

Keep `io.sanad.app://login-callback` in Android as a fallback until the HTTPS callback has been proven in the Play-distributed build.

## 10. Play Console app creation

Suggested configuration:

- App name (Arabic): `رحماء`
- Localized English name: `Ruhamaa`
- Type: App
- Pricing: Free
- Category: Lifestyle (recommended; review before final submission)
- Contains ads: No
- Target audience: Adults / 18+ only
- Website: `https://ruhamaa.com/`
- Privacy policy: `https://ruhamaa.com/privacy/`
- Support email: `support@ruhamaa.com`

### Suggested Arabic short description

`يوصل الأشياء التي لا تحتاجها إلى من يحتاجها بخصوصية وكرامة.`

### Suggested Arabic full description

رحماء منصة مجتمعية تساعد على إيصال الأشياء التي لم يعد أصحابها بحاجة إليها إلى أشخاص سجلوا احتياجهم مسبقًا، مع الحفاظ على الخصوصية والكرامة.

يسجل المستفيد احتياجه دون تصفح تبرعات الآخرين. وعندما يصل تبرع مناسب، يراجع رحماء المطابقة ويُرسل عرضًا خاصًا للمستفيد. بعد الموافقة، يتولى مندوب رحماء الاستلام والتوصيل دون كشف هوية المتبرع للمستفيد أو هوية المستفيد للمتبرع.

يمكن استخدام رحماء للملابس والأحذية، الكتب والمستلزمات التعليمية، مستلزمات الأطفال، الأدوات المنزلية والأثاث الخفيف، مستلزمات المناسبات، وبعض الأدوات والأجهزة البسيطة وفق قواعد السلامة.

المساهمة في تكاليف التوصيل اختيارية تمامًا ولا تحدد الاستحقاق ولا تمنع الخدمة عند عدم القدرة على المساهمة. لا توجد مدفوعات أو تحويلات مالية داخل التطبيق؛ وإذا اختار المستخدم المساهمة التشغيلية فتُسلَّم نقدًا للمندوب عند الاستلام أو التوصيل.

يستخدم رحماء بيانات التواصل والموقع بالحد الأدنى اللازم للتشغيل والتوصيل، ويتيح للمستخدم مراجعة سياسة الخصوصية وطلب حذف حسابه وبياناته.

النسخة الأولى تستهدف التشغيل التجريبي في مأرب، اليمن.

## 11. Store listing graphics

Required/important assets:

- Play Store app icon: PNG, 512×512, max 1024 KB
- Feature graphic: JPEG or 24-bit PNG, 1024×500
- At least 2 phone screenshots; use current UI and do not show real user PII
- Recommended screenshots: login/privacy, home, add donation, add need, match offer, handoff status

Before screenshots, replace any test names, phone numbers, exact addresses, emails, coordinates, or private donation photos with safe demo data.

## 12. App content declarations — prepared answers

### Privacy policy

`https://ruhamaa.com/privacy/`

### Ads

`No, the app does not contain ads.`

### App access / sign-in details

Select that some/all functionality is restricted by login. Provide reusable reviewer accounts and English instructions. Do not provide a real user's credentials.

Prepare at least:

1. Community demo account with operational profile/address populated.
2. Staff/admin demo account if Google needs to review restricted operational screens.

The credentials must remain valid throughout review and must not require OTP/MFA that the reviewer cannot obtain.

### Target audience

18+ only. The service does not support independent minor accounts.

### Content rating

Complete the IARC questionnaire truthfully. Current product has no public social feed, no donor-beneficiary direct chat, no gambling, sexual, violent, or drug content by design. User-entered donation/need text and images are operational/private and should still be considered when answering any user-generated-content questions.

### Financial features

The current app does not provide banking, loans, wallets, money transfer, investment, crypto, BNPL, or digital payment processing. The delivery contribution is an optional offline cash operational contribution and does not unlock digital features. Review the declaration at submission time and select the answer that accurately reflects the live build; the intended answer for the current build is **My app doesn't provide any financial features**.

### News / government / health

- News app: No
- Government app: No
- Health app/medical functionality: No

## 13. Data Safety draft

Review the final live build and every SDK before submitting. Based on the current code, expect to disclose collection of:

- Personal info: name, email address, user ID, phone number, address/contact details
- Location: approximate and precise location used for operational delivery
- Photos: donation photos uploaded by users
- User-generated content: donation descriptions, need descriptions/reasons, operational notes
- App/service activity: matching, fulfillment, handoff and safety/abuse-prevention events where applicable

Primary purposes:

- App functionality
- Account management
- Fraud prevention, security and compliance
- Operational analytics/service performance where applicable

Security:

- Data encrypted in transit: Yes
- Account deletion request available: Yes
- Data sale: No
- Targeted advertising: No

Supabase is used as a service provider for authentication, database, storage and Edge Functions; Google is used for OAuth sign-in. Confirm Google Play's current service-provider definition when answering whether data is "shared".

## 14. Permissions

Current Android manifest requests:

- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`

Do not request background location unless a future feature makes it essential and the Play policy declaration is completed. Current design does not need continuous tracking.

## 15. Testing requirement for newer personal Play accounts

If the Play developer account is a **personal account created after 13 Nov 2023**, production access requires a closed test with at least 12 opted-in testers continuously for 14 days before applying for production access. Organisation accounts are handled differently.

Start with Internal testing, then Closed testing if the account requires it.

## 16. Final pre-submission gate

Do not send for review until all are true:

- `https://ruhamaa.com/` is public over HTTPS
- Privacy, terms and delete-account pages load publicly
- `support@ruhamaa.com` and `privacy@ruhamaa.com` work
- Package ID decision is final
- Release AAB is signed with upload key
- Target SDK is API 36+
- `flutter analyze` passes
- `flutter test` passes
- Google login works in a Play-installed build
- Demo reviewer credentials are valid
- Account deletion request works
- No real PII appears in screenshots
- Data Safety answers match the exact live code/SDKs
- Ads, target audience, content rating and financial declarations are completed
- Android App Links are verified before switching production OAuth callback to `ruhamaa.com`
