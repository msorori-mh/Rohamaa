#!/usr/bin/env bash
set -euo pipefail

# This modification exists only in the disposable CI checkout. Release and
# distributed APK settings are not changed or published by this test lane.
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p = Path('app/android/app/src/debug/AndroidManifest.xml')
android = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', android)
tree = ET.parse(p)
application = tree.getroot().find('application')
if application is None:
    application = ET.SubElement(tree.getroot(), 'application')
application.set('{' + android + '}usesCleartextTraffic', 'true')
tree.write(p, encoding='unicode')
PY

test_device=$(adb devices | awk '/^emulator-.*device$/ {print $1}')
if [[ -z "$test_device" || "$test_device" == *$'\n'* ]]; then
  echo 'Expected exactly one test emulator' >&2
  exit 1
fi
adb -s "$test_device" reverse tcp:54321 tcp:54321
adb -s "$test_device" logcat -c
adb -s "$test_device" logcat '*:E' flutter:I > test-results/android-device.log 2>&1 &
logcat_pid=$!
# Install and grant permissions before launching the test process. Changing
# runtime permissions while Flutter attaches can interrupt the VM connection.
trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT
cd app
flutter build apk --debug --target=integration_test/live_app_test.dart \
  --dart-define-from-file="$RUNNER_TEMP/ui-defines.json" 2>&1 | tee ../test-results/android-build.log
adb -s "$test_device" install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb -s "$test_device" emu geo fix 45.3 15.4 > ../test-results/android-permission-setup.log
timeout --signal=INT --kill-after=30s 10m flutter test integration_test/live_app_test.dart -d "$test_device" \
  --dart-define-from-file="$RUNNER_TEMP/ui-defines.json" 2>&1 | tee ../test-results/android.log
