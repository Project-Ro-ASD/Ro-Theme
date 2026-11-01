import unittest

from tests.helpers import ROOT  # noqa: F401
from rotheme.kconfig import KConfig, bare_key


class KConfigTest(unittest.TestCase):
    TEXT = "# başlık\n\n[General]\nName=Ro\nName[tr]=Ro\n\n[Colors:Header][Inactive]\nBackgroundNormal=1,2,3\n"

    def test_roundtrip_keeps_order_and_nested_groups(self):
        cfg = KConfig.parse(self.TEXT)
        self.assertEqual(list(cfg.groups), ["[General]", "[Colors:Header][Inactive]"])
        self.assertEqual(cfg.get("[General]", "Name[tr]"), "Ro")
        self.assertEqual(KConfig.parse(cfg.dump()).groups, cfg.groups)

    def test_set_remove_and_empty_groups_are_dropped(self):
        cfg = KConfig.parse(self.TEXT)
        cfg.set("[KDE]", "contrast", 4)
        cfg.set("[KDE]", "flag", True)
        self.assertTrue(cfg.remove("[Colors:Header][Inactive]", "BackgroundNormal"))
        out = cfg.dump()
        self.assertIn("[KDE]\ncontrast=4\nflag=true\n", out)
        self.assertNotIn("Inactive", out)

    def test_bare_key(self):
        self.assertEqual(bare_key("ColorScheme[$d]"), "ColorScheme")
        self.assertEqual(bare_key("Name[tr]"), "Name")


if __name__ == "__main__":
    unittest.main()
