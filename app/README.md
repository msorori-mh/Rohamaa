# Ataa Flutter app

## Requirements

- Flutter 3.47.3 (the version pinned in CI); the package accepts Flutter 3.35+ / Dart 3.9+
- Android device/emulator
- Supabase project configured with Google OAuth (community users) and email/password (operations staff)

## Android identity

- Application ID: `com.ruhamaa.app`
- OAuth callback used by current builds: `com.ruhamaa.app://login-callback`
- Production domain: `https://ruhamaa.com`
- Production App Link callback after verification: `https://ruhamaa.com/login-callback/`

The Android host is committed. Do not regenerate `app/android` with a different `--org`, because that can overwrite signing, App Links, and release configuration.

## Run

Never commit keys. The app reads exactly three compile-time defines: `SUPABASE_URL` and `SUPABASE_ANON_KEY` (required; without them the app shows only a configuration error screen) and `AUTH_REDIRECT_URL` (optional; defaults to `com.ruhamaa.app://login-callback`). `SUPABASE_ANON_KEY` is the public anon/publishable key.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://vclicpejajxadsbuakdw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=AUTH_REDIRECT_URL=com.ruhamaa.app://login-callback
```

The service-role key must never be used in the Flutter application.

Release bundles are built by the `Android Release Bundle` workflow, which passes the same three defines from repository variables; see `docs/ANDROID_RELEASE.md`.

## Android hardening in this host

- Cloud backup and device-to-device transfer are disabled (`allowBackup="false"`, `res/xml/data_extraction_rules.xml`), so a session never leaves the phone through a backup.
- The App Link intent filter accepts the `/login-callback` path prefix on `https://ruhamaa.com` only; plain `http` is not handled.
- Release builds are minified and resource-shrunk with `app/proguard-rules.pro`, and refuse to build without a complete signing configuration.

## Google OAuth

Google's Web OAuth callback through Supabase remains:

`https://vclicpejajxadsbuakdw.supabase.co/auth/v1/callback`

Supabase Auth must allow the mobile redirect:

`com.ruhamaa.app://login-callback`

After `ruhamaa.com` Android App Links are verified with the Google Play App Signing SHA-256 certificate, production builds can use:

`https://ruhamaa.com/login-callback/`
