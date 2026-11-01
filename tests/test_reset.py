import io
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import fakes
from tests.helpers import ROOT  # noqa: F401
from rotheme import manifest, reset
from rotheme.cli import build_parser


def parse(*args):
    return build_parser().parse_args(list(args))


SYSTEM_KDEGLOBALS = """# sistem
[General]
ColorScheme=RoDark
shadeSortColumn=true
[KDE]
LookAndFeelPackage=org.ro.dark
contrast=4
[Colors:Window]
BackgroundNormal=0,0,0
ForegroundNormal=255,255,255
"""

SYSTEM_KWINRC = """[org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__RoDark
[Plugins]
ro-login-revealEnabled=true
"""

USER_KDEGLOBALS = """# kullanıcı başlığı

[General]
ColorScheme=RoDark
Personal=keep
Name[tr]=Deneme

[KDE]
LookAndFeelPackage=org.ro.dark
contrast=4

[Colors:Window]
BackgroundNormal=1,2,3

[Personal]
X=1
"""

USER_KWINRC = """[org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__RoDark
[Plugins]
ro-login-revealEnabled=true
magiclampEnabled=true
kwin4_effect_scaleEnabled=true
"""


class ResetTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.config = self.base / "config"
        self.system = self.base / "etc/xdg"
        self.env = {"XDG_CONFIG_HOME": str(self.config), "RO_THEME_SYSTEM_XDG": str(self.system),
                    "TMPDIR": str(self.base / "tmp"), "HOME": str(self.base / "home")}
        (self.base / "tmp").mkdir()
        fakes.write(self.system / "kdeglobals", SYSTEM_KDEGLOBALS)
        fakes.write(self.system / "kwinrc", SYSTEM_KWINRC)
        for name in manifest.XDG_FILES:
            if not (self.system / name).exists():
                fakes.write(self.system / name, "[General]\nforceFontDPI=0\n")
        fakes.write(self.config / "kdeglobals", USER_KDEGLOBALS, 0o640)
        fakes.write(self.config / "kwinrc", USER_KWINRC)
        self.marker = self.config / manifest.LEGACY_MARKER
        fakes.write(self.marker, "x")

    def tearDown(self):
        self.tmp.cleanup()

    def run_reset(self, *args):
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(reset.os, "geteuid", lambda: 1000):
            return reset.main(parse("reset-defaults", *args))

    def test_dry_run_changes_nothing(self):
        before = (self.config / "kdeglobals").read_text()
        out = io.StringIO()
        with mock.patch("sys.stdout", out):
            self.assertEqual(self.run_reset("--dry-run"), 0)
        self.assertIn("would reset:", out.getvalue())
        self.assertEqual((self.config / "kdeglobals").read_text(), before)
        self.assertEqual(list((self.config / "ro-theme").glob("backup-*")), [])

    def test_reset_removes_managed_keys_and_backs_up(self):
        self.assertEqual(self.run_reset(), 0)
        text = (self.config / "kdeglobals").read_text()
        self.assertNotIn("ColorScheme", text)
        self.assertNotIn("LookAndFeelPackage", text)
        self.assertNotIn("Colors:Window", text)
        self.assertIn("Personal=keep", text)
        self.assertIn("Name[tr]=Deneme", text)
        self.assertIn("# kullanıcı başlığı", text)

        kwin = (self.config / "kwinrc").read_text()
        self.assertNotIn("ro-login-revealEnabled", kwin)
        self.assertNotIn("kwin4_effect_scaleEnabled", kwin)
        self.assertIn("magiclampEnabled=true", kwin)

        backups = list((self.config / "ro-theme").glob("backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertIn("ColorScheme=RoDark", (backups[0] / "kdeglobals").read_text())
        self.assertEqual(stat.S_IMODE((backups[0] / "kdeglobals").stat().st_mode), 0o640)
        self.assertFalse(self.marker.exists())

    def test_symlink_is_rejected(self):
        (self.config / "kwinrc").unlink()
        target = self.base / "hedef"
        fakes.write(target, USER_KWINRC)
        os.symlink(target, self.config / "kwinrc")
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            self.assertEqual(self.run_reset(), 1)
        self.assertIn("expected a regular, non-symlink config file", err.getvalue())
        self.assertEqual(target.read_text(), USER_KWINRC)

    def test_root_is_rejected(self):
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(reset.os, "geteuid", lambda: 0), mock.patch("sys.stderr") as err:
            self.assertEqual(reset.main(parse("reset-defaults")), 2)
        self.assertIn("run this as your own user, not as root.",
                      "".join(str(c) for c in err.write.call_args_list))

    def test_removed_flags_are_rejected(self):
        for flag in ("--all-users", "--force"):
            with mock.patch.dict(os.environ, self.env, clear=False), \
                    mock.patch.object(reset.os, "geteuid", lambda: 1000), mock.patch("sys.stderr") as err:
                self.assertEqual(reset.main(parse("reset-defaults", flag)), 2)
            self.assertIn("was removed; the tool only changes the current user's own settings.",
                          "".join(str(c) for c in err.write.call_args_list))

    def test_concurrent_change_stops(self):
        real = reset.sysutil.sha256
        calls = {"n": 0}

        def fake(path):
            calls["n"] += 1
            return real(path) if calls["n"] == 1 else "degisti"

        with mock.patch.object(reset.sysutil, "sha256", fake), mock.patch("sys.stderr") as err:
            self.assertEqual(self.run_reset(), 1)
        self.assertIn("changed during reset; stopping.",
                      "".join(str(c) for c in err.write.call_args_list))


if __name__ == "__main__":
    unittest.main()
