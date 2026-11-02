import unittest

from tests.helpers import ROOT
from rotheme import generate, manifest, tokens
from rotheme.kconfig import KConfig
from rotheme.tokens import rgb


class ColorsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("colors",))

    def cfg(self, theme):
        name = manifest.THEMES[theme][0]
        return KConfig.parse(self.files[f"platform/plasma/color-schemes/{name}.colors"].decode())

    def test_dort_dosya_uretilir(self):
        self.assertEqual(len(self.files), 4)
        for theme in ("light", "dark"):
            name = manifest.THEMES[theme][0]
            self.assertIn(f"platform/plasma/color-schemes/{name}.colors", self.files)
            self.assertIn(f"platform/plasma/desktoptheme/{name}/colors", self.files)

    def test_koyu_sema_gorunum_ve_secim(self):
        cfg = self.cfg("dark")
        self.assertEqual(cfg.get("[Colors:View]", "BackgroundNormal"), rgb(self.t.dark.surface))
        self.assertEqual(cfg.get("[Colors:Selection]", "BackgroundNormal"), rgb(self.t.dark.accent))

    def test_acik_semada_tamamlayici_grup_karanlik_tokenlardan(self):
        cfg = self.cfg("light")
        self.assertEqual(cfg.get("[Colors:Complementary]", "BackgroundNormal"), rgb(self.t.dark.surface))
        self.assertEqual(cfg.get("[Colors:Complementary]", "BackgroundAlternate"), rgb(self.t.dark.surfaceAlt))
        self.assertEqual(cfg.get("[Colors:Complementary]", "ForegroundNormal"), rgb(self.t.dark.text))

    def test_masaustu_temasi_renk_dosyasi_semayla_ayni(self):
        for theme in ("light", "dark"):
            name = manifest.THEMES[theme][0]
            self.assertEqual(self.files[f"platform/plasma/desktoptheme/{name}/colors"],
                             self.files[f"platform/plasma/color-schemes/{name}.colors"])


if __name__ == "__main__":
    unittest.main()
