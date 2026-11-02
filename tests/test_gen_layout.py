import unittest

from tests.helpers import ROOT
from rotheme import generate, manifest, tokens


class LayoutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("layout",))
        cls.template = (f"platform/plasma/layout-templates/{manifest.LAYOUT_TEMPLATE}"
                        "/contents/layout.js")
        cls.global_layouts = [
            f"platform/plasma/look-and-feel/{manifest.THEMES[theme][1]}"
            "/contents/layouts/org.kde.plasma.desktop-layout.js"
            for theme in ("light", "dark")
        ]

    def test_uc_js_dosyasi_uretilir(self):
        self.assertEqual(len([p for p in self.files if p.endswith(".js")]), 4)
        upd = self.files["platform/plasma/shells/org.kde.plasma.desktop/contents/updates/ro-peek-desktop.js"]
        upd = upd.decode() if isinstance(upd, bytes) else upd
        self.assertIn("org.kde.plasma.showdesktop", upd)
        self.assertNotIn(".remove()", upd)   # mevcut panellere dokunur, silmez
        self.assertIn(self.template, self.files)
        for path in self.global_layouts:
            self.assertIn(path, self.files)

    def test_sablon_panel_silmez(self):
        text = self.files[self.template].decode()
        self.assertNotIn(".remove()", text)

    def test_global_temalar_panelleri_siler_ve_duvar_kagidi_ayarlar(self):
        for path in self.global_layouts:
            text = self.files[path].decode()
            self.assertIn(".remove()", text)
            self.assertIn("org.kde.image", text)
            self.assertIn('writeConfig("Image"', text)

    def test_panel_yuksekligi_ve_icontasks(self):
        for path in (self.template, *self.global_layouts):
            text = self.files[path].decode()
            self.assertIn(f"bar.height = {self.t.spacing.panelHeight}", text)
            self.assertEqual(text.count("bar.height"), 1)
            self.assertIn("org.kde.plasma.icontasks", text)


if __name__ == "__main__":
    unittest.main()
