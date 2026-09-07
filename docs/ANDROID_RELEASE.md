# Ruhamaa Android release signing

This document defines the release-signing path for the Android app. Release signing secrets must never be committed to the repository.

## Release identity

- Package / application ID: `com.ruhamaa.app`
- Current app version in `app/pubspec.yaml`: `0.1.0+1`
- Production domain: `https://ruhamaa.com`
- Internal OAuth callback: `com.ruhamaa.app://login-callback`
- Production App Link callback: `https://ruhamaa.com/login-callback`

## 1. Create the upload keystore once

Run this on the trusted Windows development machine in PowerShell. Store the keystore outside the repository and back it up securely.

```powershell
$RuhamaaKeys = Join-Path $env:USERPROFILE ".ruhamaa"
New-Item -ItemType Directory -Force -Path $RuhamaaKeys | Out-Null

keytool -genkeypair -v `
  -keystore (Join-Path $RuhamaaKeys "upload-keystore.jks") `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias "ruhamaa-upload"
```

Do not place the keystore under `C:\src\Rohamaa` and do not commit `key.properties`.

## 2. Configure GitHub Actions secrets

The manual workflow `.github/workflows/android_release_bundle.yml` requires four repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

To generate the base64 value locally without modifying the keystore:

```powershell
$Keystore = Join-Path $env:USERPROFILE ".ruhamaa\upload-keystore.jks"
$Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Keystore))
$Base64 | Set-Clipboard
```

Paste that clipboard value into the `ANDROID_KEYSTORE_BASE64` GitHub Actions secret. Enter the other three values directly into GitHub Actions secrets. Never paste these secrets into source files, issues, PR comments, or chat logs.

## 3. Build a signed AAB

Open GitHub Actions and run **Android Release Bundle** manually. Supply:

- `build_name`: for example `0.1.0`
- `build_number`: integer versionCode; it must increase for every Google Play upload

The workflow performs:

1. Java/Flutter setup
2. secret-presence validation
3. temporary keystore materialization on the runner
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. signed `flutter build appbundle --release`
8. SHA-256 generation
9. signed AAB artifact upload
10. deletion of temporary signing files from the runner workspace

If any signing secret is missing, the workflow stops before building.

## 4. Google Play Internal Testing

After the first successful signed AAB:

1. Create the app in Google Play Console with package `com.ruhamaa.app`.
2. Enable Play App Signing.
3. Upload the signed AAB to **Internal testing**.
4. Complete the required App content, Data safety, App access, Store listing and content declarations.
5. Obtain the **App signing certificate SHA-256** from Play Console (not the upload certificate SHA-256).
6. Put that fingerprint into `site/.well-known/assetlinks.json` using `site/.well-known/assetlinks.json.template` as the source structure.
7. Deploy the site and verify `https://ruhamaa.com/.well-known/assetlinks.json` is publicly reachable as JSON without redirects to a login page.
8. Then switch production OAuth redirect to `https://ruhamaa.com/login-callback` only after Supabase redirect allow-list and Android App Link verification are confirmed.

## 5. Local release build (optional)

For a local release bundle, create `app/android/key.properties` only temporarily:

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=ruhamaa-upload
storeFile=<path relative to app/android/app, e.g. ../upload-keystore.jks>
```

Then:

```powershell
cd C:\src\Rohamaa\app
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Delete `app/android/key.properties` and any copied keystore immediately after the build. The repository Gradle configuration intentionally refuses release builds when `android/key.properties` is missing, which protects against accidentally shipping an unsigned or debug-signed release.

## 6. Certificate roles

Keep these separate:

- **Upload key**: generated and controlled by Ruhamaa; used to sign uploads to Google Play.
- **Play App Signing key**: controlled by Google Play after enrollment; its SHA-256 is the fingerprint that belongs in `assetlinks.json` for production App Links.

Do not publish private keys or passwords. Certificate SHA-256 fingerprints are public identifiers and may be published in `assetlinks.json`.
