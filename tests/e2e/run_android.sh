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
cd app
flutter test integration_test/live_app_test.dart -d "$test_device" \
  --dart-define-from-file="$RUNNER_TEMP/ui-defines.json" 2>&1 | tee ../test-results/android.log
