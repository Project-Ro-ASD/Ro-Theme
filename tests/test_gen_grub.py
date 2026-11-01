import unittest

from tests.helpers import ROOT
from rotheme import generate, tokens


class GrubTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = generate.Context(tokens.load(ROOT), ROOT)
        cls.t = cls.ctx.tokens
        cls.files = generate.collect(cls.ctx, ("grub",))

    def test_tema_arka_plan_rengi_ve_yazi_tipi(self):
        text = self.files["platform/grub/ro/theme.txt"].decode()
        self.assertIn(f'desktop-color: "{self.t.dark.bootBackground}"', text)
        self.assertIn("Noto Sans Regular 16", text)


if __name__ == "__main__":
    unittest.main()
