# Ruhamaa.com DNS / GitHub Pages runbook

_Last reviewed against GitHub Pages documentation: 7 September 2026._

This runbook is the remaining DNS step for publishing the Ruhamaa public policy/release site. At the time this file was added, an external probe could not resolve `ruhamaa.com`, so DNS must be configured/verified before relying on the public Privacy Policy, Terms, deletion page, or HTTPS App Link.

## Production publishing model

- Repository: `msorori-mh/Rohamaa`
- Site source: `site/`
- Production Pages deployment: GitHub Actions from `main`
- Custom apex domain: `ruhamaa.com`
- Recommended `www` alias: `www.ruhamaa.com`
- GitHub Pages account host: `msorori-mh.github.io`

The production workflow deliberately does **not** deploy the feature branch. Merge the release candidate to `main` only after the physical-device/UAT decision.

## 1. Verify the domain in GitHub first

GitHub recommends verifying a custom domain before pointing DNS at Pages to reduce takeover risk.

For a personal account:

1. GitHub profile → **Settings** → **Pages**.
2. Add `ruhamaa.com` under verified domains.
3. GitHub will display a unique TXT record name/value such as a `_github-pages-challenge-...` record.
4. Add that exact TXT record at the DNS provider.
5. Keep the TXT record after verification.

Do not invent or reuse a TXT challenge value; it is generated specifically by GitHub.

## 2. Apex (`ruhamaa.com`) records

Use either your provider's ALIAS/ANAME support **or** the GitHub Pages A records below. A records are the most portable option.

Create four `A` records for host `@`:

```text
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

Optional IPv6 support: create four `AAAA` records for host `@`:

```text
2606:50c0:8000::153
2606:50c0:8001::153
2606:50c0:8002::153
2606:50c0:8003::153
```

If the provider supports `ALIAS`/`ANAME` at the apex, it may instead point to:

```text
msorori-mh.github.io
```

Do **not** mix unrelated apex A/AAAA/ALIAS records with the Pages target; extra records can prevent HTTPS certificate issuance.

## 3. `www` record

GitHub recommends configuring `www` even when the apex domain is primary.

Create:

```text
Type:  CNAME
Host:  www
Value: msorori-mh.github.io
```

Point directly to `msorori-mh.github.io` — do not append `/Rohamaa` and do not use a URL path.

GitHub Pages can then redirect between `www.ruhamaa.com` and `ruhamaa.com` according to the configured custom domain.

## 4. Avoid wildcard DNS

Do not create a wildcard such as:

```text
*.ruhamaa.com
```

for the Pages setup. GitHub warns that wildcard DNS can increase custom-domain takeover risk.

## 5. Configure the Pages custom domain

After domain verification and DNS setup:

1. Repository → **Settings** → **Pages**.
2. Set the custom domain to:

```text
ruhamaa.com
```

3. Keep **Enforce HTTPS** enabled once GitHub has issued the certificate.
4. The repository already contains `site/CNAME`, but the production deployment uses a custom GitHub Actions workflow; GitHub's documentation notes that a CNAME file is not required for custom Actions publishing. The repository file is retained as an explicit project record of the intended domain.

DNS propagation can take time; GitHub documents that changes may take up to 24 hours, and HTTPS certificate availability can lag behind DNS convergence.

## 6. Verify from Windows PowerShell

Run:

```powershell
Resolve-DnsName ruhamaa.com -Type A
Resolve-DnsName ruhamaa.com -Type AAAA
Resolve-DnsName www.ruhamaa.com -Type CNAME
```

Expected IPv4 answers for the apex are the four GitHub Pages addresses above. If IPv6 was not configured, an empty AAAA result is acceptable.

Then verify HTTPS pages:

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

## 8. DNS change checklist

Before considering DNS complete:

- [ ] GitHub domain ownership TXT challenge verified and retained.
- [ ] Four apex A records point to GitHub Pages (or a correct apex ALIAS/ANAME is used).
- [ ] `www` CNAME points to `msorori-mh.github.io`.
- [ ] No conflicting old apex A/AAAA/ALIAS records remain.
- [ ] No wildcard Pages record is used.
- [ ] GitHub repository Pages custom domain is `ruhamaa.com`.
- [ ] HTTPS is issued/enforced.
- [ ] Privacy, Terms, deletion and login-callback pages are publicly reachable.
- [ ] Play App Signing SHA-256 is added later to the real `assetlinks.json` and verified on-device.

Official reference: GitHub Docs → Managing a custom domain for your GitHub Pages site / Verifying your custom domain for GitHub Pages.
