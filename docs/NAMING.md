# Naming: four names, one project

This project has been renamed more than once, and each name survives somewhere for a technical reason. This page says which name is correct where, so nobody "fixes" an identifier that must not change.

| Name | Where you see it | Status |
| --- | --- | --- |
| **عطاء / Ataa** | Everything a person reads: the app label and screens, the website, store listing, notifications, new documents | Current display name since September 2026. Use it for all user-facing text |
| **ruhamaa** / Ruhamaa | Android application ID `com.ruhamaa.app`, the OAuth scheme `com.ruhamaa.app://login-callback`, the domain `ruhamaa.com` and its mailboxes, the Dart package `package:ruhamaa/...`, class names such as `RuhamaaApp` and `RuhamaaColors`, the upload-key alias `ruhamaa-upload` | Previous display name, now technical identifiers only. Do not rename |
| **Rohamaa** | The GitHub repository `msorori-mh/Rohamaa` and local checkout paths such as `C:\src\Rohamaa` | A different transliteration of the same previous name. Repository name only |
| **Sanad** | The first line of early migrations (`0002`–`0017`), `supabase/seed.sql`, the `sanad_role` key written to `app_metadata` by the `admin-create-staff` Edge Function, and the alias `SanadRepository` in `app/lib/src/data/sanad_repository.dart` | The original working name. Legacy comments and two internal identifiers |

## Why the old identifiers stay

- **`com.ruhamaa.app`** is the identity Google Play, the signing key and installed copies are tied to. Changing it creates a different app.
- **`com.ruhamaa.app://login-callback`** is in the Supabase Auth redirect allow-list and in installed builds. Changing it breaks sign-in.
- **`ruhamaa.com`** is the only domain the project owns and has configured (Pages, mail, the future `assetlinks.json`).
- **`package:ruhamaa`** and the class names are invisible to users; renaming them would touch every import for no user benefit.
- **Applied migrations are history.** Their text, including the "Sanad" comments, is what ran against the database. Editing an applied migration makes the repository disagree with production.
- **`sanad_role`** is stored on existing staff accounts. Renaming the key needs a data migration, not a search and replace.

## Rules

1. Never write the previous Arabic name in app or site text. `tools/branding/check_identity.py` fails CI if it, or the previous Latin display name, appears as prose in `app/lib` or `site`.
2. `tools/branding/apply_identity.py` rewrites display prose after merging an older branch; `--check` reports what it would change without writing. It deliberately leaves identifiers, paths, URLs, this page and `ATAA_IDENTITY.md` alone.
3. New files, classes and migrations do not need the old names. Prefer neutral names (`delivery_...`, `account_...`) over any brand name in new identifiers.
4. A real rename of the application ID, domain or repository is a project of its own (store listing, DNS, mail, redirects, OAuth clients). It is not planned.

The decision record and the compatibility boundaries are in [ATAA_IDENTITY.md](ATAA_IDENTITY.md).
