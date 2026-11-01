"""Kurulu ağaç (paketleme) denetimlerinin geçen ve kalan senaryoları."""
from __future__ import annotations

import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from tests.helpers import ROOT
from rotheme import manifest
from rotheme.cli import main
from rotheme.validate import Context, run_checks

XDG_TEXT = {
    "kdeglobals": "[General]\nXftAntialias=true\n\n[WM]\nactiveFont=a,b\n",
    "kcmfonts": "[General]\nforceFontDPI=0\n",
    "breezerc": "[Style]\nMenuOpacity=60\n",
    "plasmarc": "[Theme]\nname=RoDark\n",
    "ksplashrc": "[KSplash]\nEngine=KSplashQML\nTheme=org.ro.dark\n",
    "kscreenlockerrc": "[Greeter]\nWallpaperPlugin=org.kde.image\n",
    "kwinrc": "[org.kde.kdecoration2]\nButtonsOnLeft=M\n",
}


def dest(root: Path, entry: manifest.Entry) -> Path:
    return root / entry.dest.format(**manifest.DIRS).lstrip("/")


def build_installed(root: Path):
    for entry in manifest.INSTALL:
        path = dest(root, entry)
        source = ROOT / entry.src
        directory = source.is_dir() if source.exists() else (not entry.config and path.suffix == "")
        if directory:
            path.mkdir(parents=True, exist_ok=True)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("", encoding="utf-8")
    for rel in manifest.INSTALLED_REQUIRED:
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("", encoding="utf-8")
    for name, text in XDG_TEXT.items():
        path = root / "etc/xdg" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


class InstalledChecksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = tempfile.TemporaryDirectory()
        build_installed(Path(cls.template.name))

    @classmethod
    def tearDownClass(cls):
        cls.template.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "root"
        shutil.copytree(self.template.name, self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def assert_fails(self, check):
        results = run_checks(Context(self.root, installed=True), check_id=check)
        self.assertTrue(any(r.status == "FAIL" for r in results), f"{check}: FAIL bekleniyordu")

    def test_all_installed_checks_pass(self):
        results = run_checks(Context(self.root, installed=True))
        self.assertTrue(results)
        self.assertEqual([], [r.message for r in results if r.status != "OK"])

    def test_manifest_target_failure(self):
        (self.root / "usr/share/color-schemes/RoLight.colors").unlink()
        self.assert_fails("VAL-PKG-01")

    def test_required_path_failure(self):
        (self.root / "usr/share/ro-theme/qml/RoTokens.qml").unlink()
        self.assert_fails("VAL-PKG-02")

    def test_user_home_isolation_failure(self):
        (self.root / "etc/xdg/autostart").mkdir(parents=True)
        self.assert_fails("VAL-PKG-03")

    def test_config_file_failure(self):
        (self.root / "etc/xdg/kwinrc").unlink()
        self.assert_fails("VAL-PKG-04")

    def test_cli_json_output_is_valid(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = main(["validate", "--installed", str(self.root), "--json"])
        self.assertEqual(0, code)
        data = json.loads(out.getvalue())
        self.assertEqual(0, data["errors"])
        self.assertGreater(len(data["results"]), 0)


if __name__ == "__main__":
    unittest.main()
