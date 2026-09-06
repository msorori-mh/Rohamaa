# Sanad Flutter app

## Requirements

- Flutter 3.24+ / Dart 3.4+
- Android device/emulator
- Supabase project configured with Google OAuth

## Generate platform folders (first clone only)

From `app/` run:

```bash
flutter create . --platforms=android,ios --org io.sanad
flutter pub get
```

Keep the committed `lib/` and `pubspec.yaml` when Flutter asks about existing files.

## Run

Never commit keys. Use runtime defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://vclicpejajxadsbuakdw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_ANON_KEY
```

The service-role key must never be used in the Flutter application.

## Google OAuth

In Supabase Auth > Providers > Google, configure the Google client credentials and add the mobile deep-link callback used by the app:

`io.sanad.app://login-callback`

Platform-specific URL schemes / intent filters are generated in the next mobile-platform setup step.
