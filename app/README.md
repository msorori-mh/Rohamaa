# Ruhamaa Flutter app

## Requirements

- Flutter 3.24+ / Dart 3.4+
- Android device/emulator
- Supabase project configured with Google OAuth

## Android identity

- Application ID: `com.ruhamaa.app`
- Internal/mobile OAuth callback: `com.ruhamaa.app://login-callback`
- Production domain: `https://ruhamaa.com`
- Production App Link callback after verification: `https://ruhamaa.com/login-callback`

The Android host is committed. Do not regenerate `app/android` with a different `--org`, because that can overwrite signing, App Links, and release configuration.

## Run

Never commit keys. Use runtime defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://vclicpejajxadsbuakdw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=AUTH_REDIRECT_URL=com.ruhamaa.app://login-callback
```

The service-role key must never be used in the Flutter application.

## Google OAuth

Google's Web OAuth callback through Supabase remains:

`https://vclicpejajxadsbuakdw.supabase.co/auth/v1/callback`

Supabase Auth must allow the mobile redirect:

`com.ruhamaa.app://login-callback`

After `ruhamaa.com` Android App Links are verified with the Google Play App Signing SHA-256 certificate, production builds can use:

`https://ruhamaa.com/login-callback`
