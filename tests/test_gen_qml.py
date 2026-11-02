import unittest

from tests.helpers import ROOT
from rotheme import generate, tokens
from rotheme.generate import qml


class QmlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.files = generate.collect(cls.ctx, ("qml",))

    def test_dosyalar_depodakiyle_bayt_bayt_ayni(self):
        self.assertEqual(len(self.files), 4)
        for path, content in self.files.items():
            self.assertEqual(content, (ROOT / path).read_bytes(), path)

    def test_qmldir_icerigi(self):
        text = self.files[f"{qml.MODULE_DIR}/qmldir"].decode("utf-8")
        self.assertEqual(text.splitlines(), [
            "module org.ro.theme",
            "singleton RoTokens 1.0 RoTokens.qml",
            "singleton RoBrand 1.0 RoBrand.qml",
            "DawnScene 1.0 DawnScene.qml",
        ])

    def test_robrand_logo_ve_surum(self):
        text = self.files[f"{qml.MODULE_DIR}/RoBrand.qml"].decode("utf-8")
        self.assertIn("pragma Singleton", text)
        self.assertIn('readonly property url logo: "file:///usr/share/ro-theme/brand/roasd-logo.png"', text)
        self.assertIn(f'readonly property string version: "{(ROOT / "VERSION").read_text().strip()}"', text)
        self.assertNotIn("color", text.lower())

    def test_iki_rotokens_ayni(self):
        self.assertEqual(self.files["dist/qml/RoTokens.qml"], self.files[f"{qml.MODULE_DIR}/RoTokens.qml"])

if __name__ == "__main__":
    unittest.main()
