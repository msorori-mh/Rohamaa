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
# Grant only the disposable app's location permissions after Flutter installs it.
# Native permission-dialog UX is a separate hardware acceptance check.
(
  for attempt in $(seq 1 900); do
    if adb -s "$test_device" shell pm path com.ruhamaa.app | grep -q '^package:'; then
      adb -s "$test_device" shell pm grant com.ruhamaa.app android.permission.ACCESS_COARSE_LOCATION
      adb -s "$test_device" shell pm grant com.ruhamaa.app android.permission.ACCESS_FINE_LOCATION
      adb -s "$test_device" emu geo fix 45.3 15.4
      exit 0
    fi
    sleep 1
  done
) > test-results/android-permission-setup.log 2>&1 &
permissions_pid=$!
trap 'kill "$logcat_pid" "$permissions_pid" 2>/dev/null || true' EXIT
cd app
timeout --signal=INT --kill-after=30s 15m flutter test integration_test/live_app_test.dart -d "$test_device" \
  --dart-define-from-file="$RUNNER_TEMP/ui-defines.json" 2>&1 | tee ../test-results/android.log
