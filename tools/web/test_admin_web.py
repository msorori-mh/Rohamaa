import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import admin_web  # noqa: E402

LOADER = 'var d="https://www.gstatic.com/flutter-canvaskit/abc/";var u="https://unpkg.com/x";'


class BootstrapCheck(unittest.TestCase):
    def test_default_strings_in_loader_with_local_config_pass(self):
        text = LOADER + '_flutter.buildConfig = {"engineRevision":"abc","builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]};' + 'config={canvasKitBaseUrl:"canvaskit/",fontFallbackBaseUrl:"assets/fonts/"}'
        self.assertEqual(admin_web.check_bootstrap(text), [])

    def test_assignment_to_gstatic_fails_with_context(self):
        text = LOADER + 'config={"canvasKitBaseUrl":"https://www.gstatic.com/flutter-canvaskit/abc/"}'
        problems = admin_web.check_bootstrap(text)
        self.assertEqual(len(problems), 1)
        self.assertIn("gstatic.com/flutter-canvaskit", problems[0])
        self.assertIn("Context:", problems[0])

    def test_build_config_pointing_at_cdn_fails(self):
        text = LOADER + '_flutter.buildConfig = {"x":"https://fonts.gstatic.com/s/"};'
        self.assertTrue(admin_web.check_bootstrap(text))


if __name__ == "__main__":
    unittest.main()
