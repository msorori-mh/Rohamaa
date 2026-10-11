# Ataa Android release signing

This document defines the release-signing path for the Android app. Release signing secrets must never be committed to the repository.

## Release identity

- Package / application ID: `com.ruhamaa.app`
- Current app version in `app/pubspec.yaml`: `0.1.0+1`
- Production domain: `https://ruhamaa.com`
- OAuth callback used by current builds: `com.ruhamaa.app://login-callback`
- HTTPS App Link callback, only after App Link verification: `https://ruhamaa.com/login-callback/`
- Flutter version pinned in Flutter CI and in the release workflow: 3.47.3 (stable)

Status on 11 October 2026: there is no record of this workflow having produced a signed bundle. It cannot run until the repository owner creates the environment, variables and secrets in section 2.

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

## 2. Configure the protected `release` environment

The manual workflow `.github/workflows/android_release_bundle.yml` runs its signing job in a GitHub Environment named **`release`**. The environment is what protects the signing key: a job cannot read an environment secret until the environment's protection rules pass.

### 2.1 Create the environment and its protection rules

Repository **Settings → Environments → New environment**, name it exactly `release`, then:

1. **Required reviewers**: add at least one person other than the one who normally starts releases (two are better). Enable **Prevent self-review** so the person who starts a run cannot approve it.
2. **Deployment branches and tags**: choose *Selected branches and tags* and add the branch `main` and the tag pattern `v*`. The workflow also refuses any other ref on its own, before approval is requested.
3. Leave *Allow administrators to bypass configured protection rules* **off**.

Also protect `main` itself (pull request required, status checks required), otherwise the branch rule above protects nothing.

### 2.2 Signing secrets — environment secrets, not repository secrets

Add these four as **secrets of the `release` environment**. If they already exist as repository-level secrets, delete those copies: a repository secret can be read by any workflow on any branch, an environment secret only after approval.

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

Paste that clipboard value into `ANDROID_KEYSTORE_BASE64`. Never paste these secrets into source files, issues, PR comments, or chat logs.

### 2.3 Client configuration — variables

The app reads three compile-time values (`String.fromEnvironment` in `app/lib/main.dart` and `app/lib/src/features/auth/login_screen.dart`). The workflow passes them as `--dart-define` and stops before building if any is empty. Add them under **Settings → Secrets and variables → Actions → Variables**, either as repository variables or as variables of the `release` environment (an environment variable wins when both exist):

| Variable | Value | Notes |
| --- | --- | --- |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | https origin only, no path |
| `SUPABASE_ANON_KEY` | the project's **anon / publishable** key | public by design: it is compiled into every installed app and protected by Row Level Security, so it is a variable, not a secret. The workflow rejects a `service_role` or `sb_secret_` key |
| `AUTH_REDIRECT_URL` | `com.ruhamaa.app://login-callback` | switch to `https://ruhamaa.com/login-callback/` only after App Link verification (section 4). The same string must be in the Supabase Auth redirect allow-list |

A bundle built without `SUPABASE_URL` and `SUPABASE_ANON_KEY` installs and opens, but shows only the "incomplete configuration" screen. That is why the workflow fails early instead.

## 3. Build a signed AAB

Open GitHub Actions, choose **Android Release Bundle**, select the branch `main` (or a `v*` tag) and run it. Supply:

- `build_name`: three numeric parts, for example `0.1.0`
- `build_number`: integer versionCode; it must increase for every Google Play upload

A reviewer of the `release` environment then approves the run. The workflow performs:

1. ref and input validation in a job without secrets (`main` or `v*` only; `build_name` must match `^[0-9]+\.[0-9]+\.[0-9]+$`, `build_number` must match `^[0-9]+$`). Inputs reach the shell through environment variables, never by text substitution into a script
2. wait for environment approval
3. checkout; verification that the three variables and four secrets are present and well-formed
4. Java 17 and Flutter 3.47.3 setup, without restored build caches
5. `flutter pub get` (`--enforce-lockfile` once `app/pubspec.lock` is committed)
6. `flutter analyze`
7. `flutter test`
8. upload-keystore materialization in the runner's temporary directory, immediately before the build
9. `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` with the three `--dart-define` values
10. deletion of the temporary keystore
11. SHA-256 generation
12. artifact `ataa-release-aab-<name>-<number>` (the AAB and its `.sha256`), kept for **3 days**
13. artifact `ataa-release-symbols-<name>-<number>` (Dart symbol files and the R8 `mapping.txt`), kept for 30 days

Download both artifacts promptly. The AAB goes to Play Console. Store the symbols privately next to the release notes: without them a stack trace from this build cannot be read (`flutter symbolize -i <trace> -d <symbols dir>`), and they cannot be regenerated.

Signing passwords and alias are injected only into the release-build process environment. The workflow does not write them into `key.properties` or another plaintext file.

## 4. Google Play Internal Testing

After the first successful signed AAB:

1. Create the app in Google Play Console with package `com.ruhamaa.app`.
2. Enable Play App Signing.
3. Upload the signed AAB to **Internal testing**.
4. Complete the required App content, Data safety, App access, Store listing and content declarations.
5. Obtain the **App signing certificate SHA-256** from Play Console (not the upload certificate SHA-256).
6. Put that fingerprint into `site/.well-known/assetlinks.json` using `site/.well-known/assetlinks.json.template` as the source structure.
7. Deploy the site and verify `https://ruhamaa.com/.well-known/assetlinks.json` is publicly reachable as JSON without redirects to a login page. The Pages workflow pins `actions/upload-pages-artifact` v3, which publishes dot-directories; from v4 that action skips hidden files unless `include-hidden-files: true` is set, so keep that in mind when upgrading it.
8. Then switch production OAuth redirect to `https://ruhamaa.com/login-callback/` only after Supabase redirect allow-list and Android App Link verification are confirmed.

## 5. Local release build (optional)

### Option A — environment variables

This is the closest local equivalent to CI and avoids a plaintext password file:

```powershell
$env:ANDROID_KEYSTORE_PATH = Join-Path $env:USERPROFILE ".ruhamaa\upload-keystore.jks"
$env:ANDROID_KEYSTORE_PASSWORD = Read-Host "Keystore password"
$env:ANDROID_KEY_ALIAS = "ruhamaa-upload"
$env:ANDROID_KEY_PASSWORD = Read-Host "Key password"

cd C:\src\Rohamaa\app
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols `
  "--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co" `
  "--dart-define=SUPABASE_ANON_KEY=<anon or publishable key>" `
  "--dart-define=AUTH_REDIRECT_URL=com.ruhamaa.app://login-callback"

Remove-Item Env:ANDROID_KEYSTORE_PATH
Remove-Item Env:ANDROID_KEYSTORE_PASSWORD
Remove-Item Env:ANDROID_KEY_ALIAS
Remove-Item Env:ANDROID_KEY_PASSWORD
```

### Option B — temporary `key.properties`

For a local release bundle, `app/android/key.properties` remains supported for Android/Flutter tooling compatibility:

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=ruhamaa-upload
storeFile=<path relative to app/android/app, e.g. ../upload-keystore.jks>
```

Then run the same `flutter analyze`, `flutter test` and `flutter build appbundle --release ...` commands, including the three `--dart-define` values. Delete `app/android/key.properties` and any copied keystore immediately after the build.

The Gradle configuration intentionally refuses a release build unless all four signing values are present from environment variables or `android/key.properties`. This protects against accidentally shipping an unsigned or debug-signed release.

Release builds are minified and resource-shrunk (`isMinifyEnabled` / `isShrinkResources` in `app/android/app/build.gradle.kts`, rules in `app/android/app/proguard-rules.pro`). If R8 reports a missing class after a dependency upgrade, add the narrowest rule that fixes it to that file.

The Gradle wrapper (`gradle-wrapper.properties`) does not yet carry a `distributionSha256Sum`. Add it only with the checksum published by Gradle for the exact distribution in `distributionUrl` (https://gradle.org/release-checksums/), never with a value computed from an unverified download.

## 6. Certificate roles

Keep these separate:

- **Upload key**: generated and controlled by Ataa; used to sign uploads to Google Play.
- **Play App Signing key**: controlled by Google Play after enrollment; its SHA-256 is the fingerprint that belongs in `assetlinks.json` for production App Links.

Do not publish private keys or passwords. Certificate SHA-256 fingerprints are public identifiers and may be published in `assetlinks.json`.
