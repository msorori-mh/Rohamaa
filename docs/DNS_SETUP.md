# Ruhamaa.com DNS / GitHub Pages runbook

_Last reviewed against GitHub Pages documentation and live DNS: 7 September 2026._

## Current verified DNS state

DNS Inspector confirmed the public DNS configuration for `ruhamaa.com` and `www.ruhamaa.com` on 7 September 2026:

### Apex `ruhamaa.com`

IPv4 A records are correctly pointed to GitHub Pages:

```text
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

No apex AAAA record is currently published; IPv6 is optional for the Pages setup.

Mail remains separately configured through Hostinger MX records, so the Pages web records do not replace the mail configuration.

### `www.ruhamaa.com`

The `www` host is correctly configured as:

```text
CNAME www → msorori-mh.github.io
```

DNS resolution also returns the GitHub Pages IPv4 and IPv6 endpoints through that CNAME.

Therefore **basic DNS routing to GitHub Pages is already in place**. The remaining production-site gates are GitHub Pages domain ownership/custom-domain configuration, deploying the updated `site/` content from `main`, HTTPS availability, and later Android `assetlinks.json` verification.

## Production publishing model

- Repository: `msorori-mh/Rohamaa`
- Site source: `site/`
- Production Pages deployment: GitHub Actions from `main`
- Custom apex domain: `ruhamaa.com`
- `www` alias: `www.ruhamaa.com`
- GitHub Pages account host: `msorori-mh.github.io`

The production workflow deliberately does **not** deploy the feature branch. Merge the release candidate to `main` only after the physical-device/UAT decision.

## 1. Verify the domain in GitHub

GitHub recommends verifying a custom domain to reduce takeover risk.

For a personal account:

1. GitHub profile → **Settings** → **Pages**.
2. Add `ruhamaa.com` under verified domains.
3. GitHub will display a unique TXT record name/value such as a `_github-pages-challenge-...` record.
4. Add that exact TXT record at the DNS provider.
5. Keep the TXT record after verification.

Do not invent or reuse a TXT challenge value; it is generated specifically by GitHub. The DNS lookup used here can inspect ordinary domain records but cannot verify the underscore-prefixed GitHub challenge label through the connected DNS widget, so GitHub Settings remains the source of truth for this step.

## 2. Apex (`ruhamaa.com`) records

The current apex A records already match GitHub Pages:

```text
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

Optional IPv6 support could add the GitHub Pages AAAA records:

```text
2606:50c0:8000::153
2606:50c0:8001::153
2606:50c0:8002::153
2606:50c0:8003::153
```

IPv6 is not required for release readiness. Do **not** remove the existing mail MX/TXT records when editing web DNS.

Do not mix unrelated apex web A/AAAA/ALIAS records with the Pages target; conflicting web records can prevent HTTPS certificate issuance.

## 3. `www` record

The current `www` CNAME is already correct:

```text
Type:  CNAME
Host:  www
Value: msorori-mh.github.io
```

Point directly to `msorori-mh.github.io` — do not append `/Rohamaa` and do not use a URL path.

## 4. Avoid wildcard DNS

Do not create a wildcard such as:

```text
*.ruhamaa.com
```

for the Pages setup. GitHub warns that wildcard DNS can increase custom-domain takeover risk.

## 5. Configure the Pages custom domain

After GitHub domain verification:

1. Repository → **Settings** → **Pages**.
2. Set the custom domain to:

```text
ruhamaa.com
```

3. Keep **Enforce HTTPS** enabled once GitHub has issued the certificate.
4. The repository already contains `site/CNAME`, but the production deployment uses a custom GitHub Actions workflow; GitHub's documentation notes that a CNAME file is not required for custom Actions publishing. The repository file is retained as an explicit project record of the intended domain.

The updated Privacy Policy, Terms, account deletion and callback pages are currently on the release branch. They become production content after the branch is merged to `main` and the production Pages workflow succeeds.

## 6. Verify from Windows PowerShell

Run:

```powershell
Resolve-DnsName ruhamaa.com -Type A
Resolve-DnsName www.ruhamaa.com -Type CNAME
```

Expected results are the four GitHub Pages A addresses and `www → msorori-mh.github.io`.

Then verify HTTPS pages after the production Pages deployment:

```powershell
$Urls = @(
  'https://ruhamaa.com/',
  'https://ruhamaa.com/privacy/',
  'https://ruhamaa.com/terms/',
  'https://ruhamaa.com/delete-account/',
  'https://ruhamaa.com/login-callback'
)

foreach ($Url in $Urls) {
  try {
    $r = Invoke-WebRequest -Uri $Url -MaximumRedirection 5 -UseBasicParsing
    "{0} {1}" -f $r.StatusCode, $Url
  } catch {
    "FAIL $Url — $($_.Exception.Message)"
  }
}
```

Release gate: all public policy/deletion URLs must return HTTPS successfully without login authentication.

## 7. Android App Links comes later

DNS/Pages availability is necessary but **not sufficient** for Android App Links.

Do not create the real:

```text
https://ruhamaa.com/.well-known/assetlinks.json
```

until Google Play Internal Testing provides the **Play App Signing certificate SHA-256**.

After that fingerprint is placed into the real `assetlinks.json` and deployed, verify on the Play-installed build:

```powershell
adb shell pm verify-app-links --re-verify com.ruhamaa.app
adb shell pm get-app-links com.ruhamaa.app
adb shell am start -W -a android.intent.action.VIEW -d "https://ruhamaa.com/login-callback"
```

Only after the domain is verified by Android and the HTTPS callback opens Ruhamaa should production OAuth be switched from the internal custom scheme to `https://ruhamaa.com/login-callback`, if desired.

## 8. DNS / Pages checklist

- [x] Apex A records point to GitHub Pages.
- [x] `www` CNAME points to `msorori-mh.github.io`.
- [x] Existing MX/SPF mail configuration remains separate and intact.
- [ ] GitHub domain ownership TXT challenge verified and retained in GitHub Settings.
- [ ] GitHub repository Pages custom domain confirmed as `ruhamaa.com`.
- [ ] Release branch merged and production Pages deployment succeeds from `main`.
- [ ] HTTPS is issued/enforced.
- [ ] Privacy, Terms, deletion and login-callback pages are publicly reachable.
- [ ] Play App Signing SHA-256 is added later to the real `assetlinks.json` and verified on-device.

Official reference: GitHub Docs → Managing a custom domain for your GitHub Pages site / Verifying your custom domain for GitHub Pages.
