#!/usr/bin/env python3
"""GTK CSS kapısının bozuk/eksik girdiyi gerçek ayrıştırıcıyla reddetmesini sınar."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("check-gtk-css.py")


class GtkCss(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ro-gtk-css-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "source with spaces"
        self.files = {}
        for version in ("3.0", "4.0"):
            path = self.root / "platform/gtk/Ro-GTK" / f"gtk-{version}" / "gtk.css"
            path.parent.mkdir(parents=True)
            path.write_text("button { color: #ffffff; }\n")
            self.files[version] = path

    def run_check(self, env=None):
        return subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root)],
                              env=env, text=True, capture_output=True, timeout=70)

    def test_valid_css_for_both_versions(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("[OK] GTK 3.0:", result.stdout)
        self.assertIn("[OK] GTK 4.0:", result.stdout)

    def test_invalid_css_for_each_version(self):
        for version, path in self.files.items():
            with self.subTest(version=version):
                original = path.read_text()
                path.write_text("button { color: ; }\n")
                try:
                    result = self.run_check()
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn(f"[FAIL] GTK {version}:", result.stderr)
                    self.assertIn(str(path), result.stderr)
                finally:
                    path.write_text(original)

    def test_missing_css_for_each_version(self):
        for version, path in self.files.items():
            with self.subTest(version=version):
                original = path.read_text()
                path.unlink()
                try:
                    result = self.run_check()
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn(f"[FAIL] GTK {version}: missing CSS file:", result.stderr)
                finally:
                    path.write_text(original)

    def test_relative_import_is_parsed(self):
        for path in self.files.values():
            path.with_name("base.css").write_text("@define-color ro_test #ffffff;\n")
            path.write_text("@import url('base.css'); button { color: @ro_test; }\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_invalid_import_is_rejected(self):
        for path in self.files.values():
            path.with_name("base.css").write_text("button { color: ; }\n")
            path.write_text("@import url('base.css');\n")
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[FAIL] GTK 3.0:", result.stderr)
        self.assertIn("[FAIL] GTK 4.0:", result.stderr)

    def test_unavailable_parser_is_not_skipped(self):
        # Ayrıştırıcı bağımlılığının yokluğunu çocuk süreçlerde de görünür kıl.
        missing_gi = Path(self.temporary.name) / "missing-gi"
        missing_gi.mkdir()
        (missing_gi / "gi.py").write_text("raise ImportError('simulated missing PyGObject')\n")
        result = self.run_check(dict(os.environ, PYTHONPATH=str(missing_gi)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("parser unavailable", result.stderr)


if __name__ == "__main__":
    unittest.main()
