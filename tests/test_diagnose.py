import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import fakes
from tests.helpers import ROOT  # noqa: F401
from rotheme import diagnose, install
from rotheme.cli import build_parser


KREAD = """#!/usr/bin/python3
import os, sys
args = sys.argv[1:]
def val(flag):
    return args[args.index(flag) + 1] if flag in args else ""
file, key = val("--file"), val("--key")
group = "][".join(args[i + 1] for i, arg in enumerate(args) if arg == "--group")
answers = {
    ("kdeglobals", "KDE", "LookAndFeelPackage"): "org.ro.dark",
    ("kdeglobals", "General", "ColorScheme"): os.environ.get("FAKE_COLORSCHEME", "RoDark"),
    ("kdeglobals", "Icons", "Theme"): "ro-icons",
    ("plasmarc", "Theme", "name"): "RoDark",
    ("ksplashrc", "KSplash", "Theme"): "org.ro.dark",
    ("kscreenlockerrc", "Greeter", "WallpaperPlugin"): "org.kde.image",
    ("kscreenlockerrc", "Greeter][Wallpaper][org.kde.image][General", "Image"):
        "file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg",
    ("kscreenlockerrc", "Greeter][Wallpaper][org.kde.image][General", "Blur"): "false",
    ("kwinrc", "org.kde.kdecoration2", "library"): "org.kde.kwin.aurorae.v2",
    ("kwinrc", "org.kde.kdecoration2", "theme"): "__aurorae__svg__RoDark",
}
print(answers.get((file, group, key), ""))
"""

RPM = """#!/bin/sh
case "$1" in
  -q) echo "ro-theme-2.0.0-1.fc44.noarch" ;;
  -V) exit 0 ;;
esac
"""


def parse(*args):
    return build_parser().parse_args(list(args))


class DiagnoseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.src = fakes.make_source(self.base / "src")
        self.home = self.base / "home"
        self.data = self.base / "data"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": str(self.base / "system"),
                    "XDG_CONFIG_HOME": str(self.base / "config"),
                    "QT_PLUGIN_PATH": "", "PATH": str(self.bin)}
        self.assertEqual(install.install(root=self.src, data_home=self.data, local=True), 0)
        fakes.write(self.bin / "kreadconfig6", KREAD, 0o755)
        fakes.tool(self.bin, "coredumpctl", "exit 0")

    def tearDown(self):
        self.tmp.cleanup()

    def run_diagnose(self, *args):
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(diagnose, "_runtime_results", lambda env: []):
            return diagnose.main(parse("diagnose", *args))

    def test_local_ok(self):
        self.assertEqual(self.run_diagnose("--local"), 0)

    def test_missing_file_fails(self):
        (self.data / "color-schemes/RoLight.colors").unlink()
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            self.assertEqual(self.run_diagnose("--local"), 1)
        self.assertIn("[FAIL]", err.getvalue())
        self.assertIn("eksik", err.getvalue())

    def test_absent_lockscreen_is_failure(self):
        fakes.write(self.data / "plasma/look-and-feel/org.ro.dark/contents/lockscreen/LockScreen.qml", "")
        self.assertEqual(self.run_diagnose("--local"), 1)

    def test_missing_reader_is_reported_separately(self):
        self.env["PATH"] = str(self.base / "bos")
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            self.assertEqual(self.run_diagnose("--local"), 0)
        self.assertIn(diagnose.NO_READER, err.getvalue())

    def test_kde_mismatch_warns(self):
        self.env["FAKE_COLORSCHEME"] = "Yanlis"
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            self.assertEqual(self.run_diagnose("--local"), 0)
        self.assertIn("beklenen RoDark", err.getvalue())

    def test_json(self):
        out = io.StringIO()
        with mock.patch("sys.stdout", out):
            self.assertEqual(self.run_diagnose("--local", "--json"), 0)
        payload = json.loads(out.getvalue())
        self.assertEqual(payload["mode"], "local")
        self.assertEqual(payload["errors"], 0)

    def test_system_with_sysroot(self):
        sysroot = self.base / "sysroot"
        self.assertEqual(install.install(root=self.src, destroot=sysroot), 0)
        fakes.write(self.bin / "rpm", RPM, 0o755)
        self.env["RO_THEME_SYSROOT"] = str(sysroot)
        self.assertEqual(self.run_diagnose("--system"), 0)

    def test_system_missing_file_fails(self):
        sysroot = self.base / "sysroot"
        self.assertEqual(install.install(root=self.src, destroot=sysroot), 0)
        fakes.write(self.bin / "rpm", RPM, 0o755)
        self.env["RO_THEME_SYSROOT"] = str(sysroot)
        (sysroot / "etc/xdg/kdeglobals").unlink()
        self.assertEqual(self.run_diagnose("--system"), 1)


if __name__ == "__main__":
    unittest.main()
