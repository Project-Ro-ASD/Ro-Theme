import unittest

from tests.helpers import ROOT
from rotheme import generate, manifest, tokens
from rotheme.kconfig import KConfig


class XdgTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("xdg",))

    def cfg(self, name):
        return KConfig.parse(self.files[f"platform/plasma/defaults/xdg/{name}"].decode())

    def test_yedi_dosya_uretilir(self):
        self.assertEqual(len(self.files), 7)
        self.assertEqual({p.rsplit("/", 1)[-1] for p in self.files}, set(manifest.XDG_FILES))

    def test_kdeglobals_kde_grubunda_colorscheme_yok(self):
        cfg = self.cfg("kdeglobals")
        self.assertIsNone(cfg.get("[KDE]", "ColorScheme"))
        self.assertEqual(cfg.get("[General]", "ColorScheme"), "RoDark")

    def test_kwinrc_plugins_yalnizca_ro_login_reveal(self):
        cfg = self.cfg("kwinrc")
        self.assertEqual(cfg.groups["[Plugins]"], {"ro-login-revealEnabled": "true"})

    def test_breezerc_animasyon_suresi(self):
        cfg = self.cfg("breezerc")
        self.assertEqual(cfg.get("[Style]", "AnimationsDuration"), str(self.t.motion.fastMs))

    def test_depodaki_xdg_dosyalari_bayt_bayt_ayni(self):
        for name in ("kcmfonts", "breezerc", "plasmarc", "ksplashrc", "kwinrc"):
            path = f"platform/plasma/defaults/xdg/{name}"
            self.assertEqual(self.files[path], (ROOT / path).read_bytes(), path)


if __name__ == "__main__":
    unittest.main()
