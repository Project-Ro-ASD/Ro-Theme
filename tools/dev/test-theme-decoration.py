#!/usr/bin/env python3
"""Yerel uygulama ve tanının üretilmiş dekorasyon kararını izlemesini sınar."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ThemeDecoration(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.home = self.root / "user"
        self.home.mkdir()
        self.calls = self.root / "calls.jsonl"
        self.calls.touch()
        self.active = self.root / "active.json"
        self.active.write_text("{}")
        self.env = os.environ | {
            # Yalnız alt süreçte kullanılan geçici kullanıcı evi; masaüstüne erişim yok.
            "HOME": str(self.home), "PATH": str(self.bin),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "RO_THEME_LIVE_PLASMASHELL": "0", "RO_TEST_CALLS": str(self.calls),
            "RO_TEST_ACTIVE": str(self.active),
        }
        for name in ("bash", "dirname", "sed", "grep", "tail", "cmp"):
            (self.bin / name).symlink_to(shutil.which(name))
        for name in ("tools/dev/apply-theme.sh", "scripts/diagnose.sh"):
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
        checker = self.root / "scripts/check-plasma-runtime.sh"
        checker.write_text("#!/bin/bash\nexit 0\n")
        checker.chmod(0o755)
        for mode in ("dark", "light"):
            name = "Ro" + mode.title()
            source = ROOT / f"platform/plasma/look-and-feel/org.ro.{mode}/contents/defaults"
            dest = self.defaults(mode)
            dest.parent.mkdir(parents=True)
            shutil.copyfile(source, dest)
            installed = self.home / f".local/share/plasma/look-and-feel/org.ro.{mode}"
            for relative in ("metadata.json", "contents/defaults",
                             "contents/layouts/org.kde.plasma.desktop-layout.js",
                             "contents/lockscreen/assets/login.jpg"):
                path = installed / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source.read_text() if relative == "contents/defaults" else "fixture")
            for relative in (f"color-schemes/{name}.colors", f"ro-theme/wallpapers/{mode}.jpg",
                             *(f"plasma/desktoptheme/{name}/{p}" for p in ("metadata.json", "colors", "plasmarc"))):
                path = self.home / ".local/share" / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
        self.stub("kreadconfig6", '''
import configparser
args = sys.argv[1:]
file = args[args.index("--file") + 1]
key = args[args.index("--key") + 1]
groups = [args[i + 1] for i, arg in enumerate(args) if arg == "--group"]
if os.path.isabs(file):
    if os.environ.get("RO_TEST_READER_FAIL"):
        sys.exit(1)
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    config.read(file)
    print(config.get("][".join(groups), key, fallback=""))
else:
    values = json.loads(Path(os.environ["RO_TEST_ACTIVE"]).read_text())
    print(values.get("/".join([file, *groups, key]), ""))
''')
        for name in ("kwriteconfig6", "kwriteconfig5", "plasma-apply-colorscheme",
                     "plasma-apply-wallpaperimage", "qdbus6"):
            self.stub(name, '''
with open(os.environ["RO_TEST_CALLS"], "a") as log:
    log.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + "\\n")
''')
        self.stub("rpm", "sys.exit(1)\n")

    def stub(self, name, body):
        script = self.bin / name
        script.write_text(f"#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\n" + body)
        script.chmod(0o755)

    def defaults(self, mode):
        return self.root / f"platform/plasma/look-and-feel/org.ro.{mode}/contents/defaults"

    def run_script(self, relative, *args):
        return subprocess.run([str(self.bin / "bash"), str(self.root / relative), *args],
                              env=self.env, capture_output=True, text=True)

    def writes(self):
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        return {call[call.index("--key") + 1]: call[-1] for call in calls
                if call[0].startswith("kwriteconfig") and "--delete" not in call}

    def set_active(self, mode, library="org.kde.kwin.aurorae.v2", theme=None):
        name = "Ro" + mode.title()
        self.active.write_text(json.dumps({
            "kdeglobals/KDE/LookAndFeelPackage": f"org.ro.{mode}",
            "kdeglobals/General/ColorScheme": name,
            "plasmarc/Theme/name": name, "ksplashrc/KSplash/Theme": f"org.ro.{mode}",
            "kscreenlockerrc/Greeter/WallpaperPlugin": "org.kde.image",
            "kscreenlockerrc/Greeter/Wallpaper/org.kde.image/General/Image":
                f"file:///fixture/plasma/look-and-feel/org.ro.{mode}/contents/lockscreen/assets/login.jpg",
            "kwinrc/org.kde.kdecoration2/library": library,
            "kwinrc/org.kde.kdecoration2/theme": theme if theme is not None else f"__aurorae__svg__{name}",
        }))

    def test_apply_both_modes_match_generated_defaults(self):
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                result = self.run_script("tools/dev/apply-theme.sh", mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.writes()["library"], "org.kde.kwin.aurorae.v2")
                self.assertEqual(self.writes()["theme"], f"__aurorae__svg__Ro{mode.title()}")
                self.assertEqual(self.writes()["widgetStyle"], "Breeze")

    def test_apply_reads_values_instead_of_repeating_them(self):
        self.defaults("dark").write_text("[kwinrc][org.kde.kdecoration2]\nlibrary=fixture.engine\ntheme=fixture.theme\n")
        result = self.run_script("tools/dev/apply-theme.sh", "dark")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.writes()["library"], "fixture.engine")
        self.assertEqual(self.writes()["theme"], "fixture.theme")

    def assert_apply_stops_before_mutation(self):
        result = self.run_script("tools/dev/apply-theme.sh", "dark")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no theme settings were changed", result.stderr)
        self.assertEqual(self.calls.read_text(), "")

    def test_missing_defaults_stops_before_mutation(self):
        self.defaults("dark").unlink()
        self.assert_apply_stops_before_mutation()

    def test_missing_key_stops_before_mutation(self):
        self.defaults("dark").write_text("[kwinrc][org.kde.kdecoration2]\nlibrary=fixture.engine\n")
        self.assert_apply_stops_before_mutation()

    def test_missing_reader_stops_before_mutation(self):
        (self.bin / "kreadconfig6").unlink()
        self.assert_apply_stops_before_mutation()

    def test_reader_failure_stops_before_mutation(self):
        self.env["RO_TEST_READER_FAIL"] = "1"
        self.assert_apply_stops_before_mutation()

    def test_kreadconfig5_fallback(self):
        (self.bin / "kreadconfig6").rename(self.bin / "kreadconfig5")
        result = self.run_script("tools/dev/apply-theme.sh", "light")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.writes()["theme"], "__aurorae__svg__RoLight")

    def test_diagnosis_accepts_matching_ro_decoration_in_both_modes(self):
        for mode in ("dark", "light"):
            with self.subTest(mode=mode):
                self.set_active(mode)
                result = self.run_script("scripts/diagnose.sh", "--local")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("[WARN] KWin decoration", result.stderr)
                self.assertNotIn("cannot read KWin decoration", result.stderr)
                self.assertEqual(self.calls.read_text(), "")

    def test_diagnosis_reports_breeze_override(self):
        self.set_active("dark", library="org.kde.breeze", theme="Breeze")
        result = self.run_script("scripts/diagnose.sh", "--local")
        self.assertIn("library mismatch: expected org.kde.kwin.aurorae.v2", result.stderr)
        self.assertIn("theme mismatch: expected __aurorae__svg__RoDark", result.stderr)

    def test_diagnosis_reports_wrong_ro_variant(self):
        self.set_active("light", theme="__aurorae__svg__RoDark")
        result = self.run_script("scripts/diagnose.sh", "--local")
        self.assertIn("theme mismatch: expected __aurorae__svg__RoLight", result.stderr)

    def test_diagnosis_reports_missing_active_decoration(self):
        self.set_active("dark", library="", theme="")
        result = self.run_script("scripts/diagnose.sh", "--local")
        self.assertIn("library mismatch:", result.stderr)
        self.assertIn("got empty", result.stderr)
        self.assertIn("theme mismatch:", result.stderr)

    def test_diagnosis_reports_unreadable_defaults(self):
        self.set_active("dark")
        self.env["RO_TEST_READER_FAIL"] = "1"
        result = self.run_script("scripts/diagnose.sh", "--local")
        self.assertIn("cannot read KWin decoration defaults", result.stderr)


if __name__ == "__main__":
    unittest.main()
