# Staff portal on the web (`https://ruhamaa.com/admin/login`)

The Flutter app in `app/` also builds for the browser. The web build is **staff only**
(admin, supervisor, courier). It is published inside the existing GitHub Pages site under
`/admin/` by `.github/workflows/pages.yml`; nothing is committed under `site/admin/`.

## Behaviour

- Only the team sign-in (email and password) is shown. There is no Google button and no
  community wording. Forced password changes work as in the app.
- Routes other than login, legal, `/`, `/admin`, `/supervisor` and `/courier` redirect away.
- A signed-in account without a staff role sees an Arabic explanation, is signed out, and the
  login screen repeats the message (`WebStaffOnlyScreen`, `WebStaffNotice`).
- Phone behaviour is unchanged (`kIsWeb` guards only).

## Hosting

- `flutter build web --release --base-href /admin/ --no-web-resources-cdn`: CanvasKit is
  self-hosted, Tajawal is bundled; no Google CDN or Google Fonts at runtime.
- GitHub Pages has no SPA fallback, so `tools/web/admin_web.py finalize` also writes a copy of
  `index.html` to `/admin/login/index.html`. Other deep links (for example reloading
  `/admin/supervisor`) would be a 404; sign-in always lands on `/admin/`.
- `index.html` has a strict CSP meta tag (`script-src 'self' 'wasm-unsafe-eval'`, no inline
  script). `finalize` pins `connect-src`/`img-src` to the Supabase project host taken from
  `SUPABASE_URL`. `style-src` keeps `'unsafe-inline'` because the Flutter engine injects a
  `<style>` element.
- `robots.txt` disallows `/admin/`; the page also carries `noindex, nofollow`; it is not in
  the sitemap.

## Configuration (repository variables, not the `release` environment)

| Variable | Value |
| --- | --- |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` (origin only) |
| `SUPABASE_ANON_KEY` | the public anon / publishable key (never a service-role or `sb_secret_` key) |

If both are empty the Pages job deploys the public site without `/admin/` and prints a
warning. If only one is set, or the key is a secret key, the job fails. The Pages job does
not use the `release` environment, so it never sees signing secrets.

## Checks

- `Flutter CI` compiles the web build on every pull request and verifies the output
  (`admin_web.py finalize` against a placeholder host).
- `Website checks` run on `site/` before the portal is copied in.
- After deployment `tests/site/check_deployed.py` compares `/admin/` and `/admin/login/` with
  the built files.

## Local development

`flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
The CSP placeholder in `app/web/index.html` is not replaced in dev mode, so Supabase calls are
blocked by the CSP; test against a build processed by `tools/web/admin_web.py finalize`, or
temporarily edit the placeholder host.
