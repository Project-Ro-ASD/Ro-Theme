import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import fakes
from tests.helpers import ROOT  # noqa: F401
from rotheme import apply, install
from rotheme.cli import build_parser


LOG_TOOL = """#!/bin/sh
echo "$0 $*" >> "$APPLY_LOG"
exit 0
"""


def parse(*args):
    return build_parser().parse_args(list(args))


class ApplyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.src = fakes.make_source(self.base / "src")
        self.home = self.base / "home"
        self.data = self.base / "data"
        self.config = self.base / "config"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "apply.log"
        self.env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.data),
                    "XDG_CONFIG_HOME": str(self.config),
                    "XDG_DATA_DIRS": str(self.base / "system"), "PATH": str(self.bin),
                    "APPLY_LOG": str(self.log)}
        self.assertEqual(install.install(root=self.src, data_home=self.data, local=True), 0)
        for name in ("kdeglobals", "plasmarc", "kwinrc", "ksplashrc", "kscreenlockerrc"):
            fakes.write(self.config / name, f"[Eski]\n{name}=1\n")
        for name in ("plasma-apply-colorscheme", "kwriteconfig6",
                     "plasma-apply-wallpaperimage", "qdbus6"):
            fakes.tool(self.bin, name, LOG_TOOL.replace("#!/bin/sh\n", ""))

    def tearDown(self):
        self.tmp.cleanup()

    def run_apply(self, *args):
        with mock.patch.dict(os.environ, self.env, clear=False):
            return apply.main(parse("apply", *args))

    def test_apply_dark_writes_keys_and_reconfigures(self):
        self.assertEqual(self.run_apply("dark"), 0)
        log = self.log.read_text()
        self.assertIn("plasma-apply-colorscheme RoDark", log)
        self.assertIn("--file kdeglobals --group KDE --key LookAndFeelPackage org.ro.dark", log)
        self.assertIn("--file plasmarc --group Theme --key name RoDark", log)
        self.assertIn("--file kscreenlockerrc --group Greeter --group Wallpaper "
                      "--group org.kde.image --group General --key Blur false", log)
        self.assertIn(f"plasma-apply-wallpaperimage {self.data}/ro-theme/wallpapers/dark.jpg", log)
        self.assertIn("org.kde.KWin /KWin reconfigure", log)
        self.assertIn("--key kwin4_effect_scaleEnabled --delete", log)
        backups = list((self.config / "ro-theme").glob("backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertTrue((backups[0] / "kdeglobals").is_file())

    def test_apply_light_uses_light_defaults(self):
        self.assertEqual(self.run_apply("light"), 0)
        log = self.log.read_text()
        self.assertIn("plasma-apply-colorscheme RoLight", log)
        self.assertIn("--file kdeglobals --group KDE --key LookAndFeelPackage org.ro.light", log)
        self.assertIn(f"wallpapers/light.jpg", log)

    def test_missing_defaults_fails_before_changes(self):
        (self.data / "plasma/look-and-feel/org.ro.dark/contents/defaults").unlink()
        self.assertEqual(self.run_apply("dark"), 1)
        self.assertFalse(self.log.exists())
        self.assertFalse((self.config / "ro-theme").exists())

    def test_missing_required_key_fails_closed(self):
        path = self.data / "plasma/look-and-feel/org.ro.dark/contents/defaults"
        text = path.read_text().replace("theme=__aurorae__svg__RoDark", "theme=")
        fakes.write(path, text)
        self.assertEqual(self.run_apply("dark"), 1)
        self.assertFalse(self.log.exists())

    def test_command_failure_returns_1(self):
        fakes.tool(self.bin, "plasma-apply-colorscheme", "exit 1")
        self.assertEqual(self.run_apply("dark"), 1)

    def test_live_shell_refresh(self):
        self.assertEqual(self.run_apply("dark", "--live-plasmashell"), 0)
        self.assertIn("org.kde.PlasmaShell /PlasmaShell evaluateScript", self.log.read_text())


if __name__ == "__main__":
    unittest.main()
