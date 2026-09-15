> **تحديث الهوية:** اعتمد اسم «عطاء» (Ataa). هذه وثيقة تاريخية؛ راجع [الهوية الحالية وخطوات التوافق](ATAA_IDENTITY.md).

# Website V2 — 14 September 2026

Scope: public Arabic RTL website in `site/`, on the existing GitHub Pages hosting path. This is a public information website, not a Flutter web build or an administrative portal. No backend schema or application changes.

## Implementation

- New responsive homepage: purpose, item/skill/need participation, workflow, privacy, partners, FAQ and truthful app availability.
- Custom lightweight SVG illustration and favicon; local Tajawal fonts and OFL license, reusing the application's existing font binaries.
- Shared navigation/footer and consistent legal layout. Privacy, terms and account-deletion card contents preserved.
- Contact page uses the existing support and privacy mailboxes via mailto. It does not collect or submit a form or promise response times.
- Accessible mobile disclosure menu, Escape/focus return, native FAQ disclosures and no-JavaScript fallback.
- Static login callback page: no authentication parameter parsing, forwarding, analytics or logging. `no-referrer` and `noindex,nofollow` are set there.
- Self-only CSP, no external assets or tracking, canonical/Open Graph text metadata, sitemap, robots and custom 404.

## Verification

`python3 tests/site/check_static.py` checks seven documents and all local links/assets/anchors.

`tests/site/browser.cjs` checks seven routes at 320, 390, 768 and 1440px, horizontal overflow, mobile navigation and keyboard behavior, native FAQs, no-JavaScript fallback, and console/network/CSP errors. The `Website checks` workflow runs the browser and uploads screenshots plus summary as `website-review`. These are focused checks, not a complete WCAG conformance audit.

Local browser download was blocked by network timeouts; visual verification is performed from GitHub Actions screenshots. Node syntax and Python static checks run locally. Runtime-only dependencies are pinned to Playwright 1.62.1 in the workflow; no npm build is required to serve this website.

## Review and deployment

Open the PR and inspect screenshots before merging. The existing Pages workflow publishes `site/` when main receives a site change; no hosting migration is required. Check that `site/CNAME` remains `ruhamaa.com` and that GitHub Pages custom-domain/HTTPS configuration is healthy. Production was not changed as part of preparing this branch.

Before public promotion, confirm that support@ruhamaa.com and privacy@ruhamaa.com receive mail. They were already published in the repository; mailbox delivery has not been independently verified. Confirm operational availability with the owner. Replace the app availability message with the verified Play URL only after that release is available; do not use an E2E APK or create a fictional store link.

Do not overwrite a real `site/.well-known/assetlinks.json` with the template. App Links/Google OAuth need separate signed-device verification. This website does not claim that those integrations or Push notifications are complete.

Post-deploy: verify HTTPS, homepage/mobile menu, privacy/terms/deletion/contact paths, true unknown-path 404 handling, and the authentication callback with the release owner. Roll back the website commit to restore the prior static files if needed; there are no data migrations.
