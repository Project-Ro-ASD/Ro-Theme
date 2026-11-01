import struct
import unittest

from tests.helpers import ROOT
from rotheme import generate, tokens
from rotheme.kconfig import KConfig

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PlymouthTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("plymouth",))

    def png(self, name):
        return self.files[f"platform/plymouth/ro-theme/{name}"]

    def test_dort_png_imzasi_ve_boyutlari(self):
        sizes = {
            "entry.png": (320, 40),
            "bullet.png": (10, 10),
            "lock.png": (34, 34),
            "capslock.png": (24, 28),
        }
        for name, size in sizes.items():
            data = self.png(name)
            self.assertTrue(data.startswith(PNG_SIGNATURE), name)
            self.assertEqual(data[12:16], b"IHDR", name)
            self.assertEqual(struct.unpack(">II", data[16:24]), size, name)

    def test_plymouth_yapilandirmasi(self):
        cfg = KConfig.parse(self.files["platform/plymouth/ro-theme/ro-theme.plymouth"].decode())
        self.assertEqual(cfg.get("[Plymouth Theme]", "ModuleName"), "two-step")
        self.assertEqual(cfg.get("[two-step]", "BackgroundStartColor"),
                         "0x" + self.t.dark.bootBackground.lstrip("#").lower())


if __name__ == "__main__":
    unittest.main()
