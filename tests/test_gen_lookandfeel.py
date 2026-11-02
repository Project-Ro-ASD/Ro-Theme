import json
import unittest

from tests.helpers import ROOT
from rotheme import generate, manifest, tokens
from rotheme.kconfig import KConfig
from rotheme.tokens import font_string


class LookAndFeelTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("lookandfeel",))

    def defaults(self, theme):
        look = manifest.THEMES[theme][1]
        path = f"platform/plasma/look-and-feel/{look}/contents/defaults"
        return KConfig.parse(self.files[path].decode())

    def metadata(self, theme):
        look = manifest.THEMES[theme][1]
        path = f"platform/plasma/look-and-feel/{look}/metadata.json"
        return json.loads(self.files[path])

    def test_genel_yazi_tipi_token_dizgisi(self):
        for theme in ("light", "dark"):
            cfg = self.defaults(theme)
            self.assertEqual(cfg.get("[kdeglobals][General]", "font"),
                             font_string(self.t.fonts.general))

    def test_simge_temalari(self):
        self.assertEqual(self.defaults("dark").get("[kdeglobals][Icons]", "Theme"), "ro-icons")
        self.assertEqual(self.defaults("light").get("[kdeglobals][Icons]", "Theme"), "ro-icons-light")

    def test_metadata_kimlik_ve_surum(self):
        for theme in ("light", "dark"):
            data = self.metadata(theme)
            self.assertEqual(data["KPlugin"]["Id"], manifest.THEMES[theme][1])
            self.assertEqual(data["KPlugin"]["Version"], self.ctx.version)


if __name__ == "__main__":
    unittest.main()
