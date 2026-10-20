#!/usr/bin/env python3
"""Yerel kurulumun dosya ve uygulama hatalarını geçici kullanıcı evinde sınar."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name("install-local.sh")


class LocalInstall(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.source = self.root / "source"
        self.home = self.root / "user"
        self.home.mkdir()
        self.steps = self.root / "steps"
        self.steps.touch()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = os.environ | {
            # Geçici ev yalnız test alt sürecine aittir; gerçek kullanıcı dosyaları kullanılmaz.
            "HOME": str(self.home), "PATH": str(self.bin),
            "RO_TEST_STEPS": str(self.steps),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
        }
        for name in ("bash", "dirname", "mkdir", "rm", "chmod"):
            (self.bin / name).symlink_to(shutil.which(name))
        cp = self.bin / "cp"
        cp.write_text('#!/bin/bash\nfor arg in "$@"; do\n'
                      '  if [[ -n "${RO_TEST_COPY_FAIL:-}" && "$arg" == "$RO_TEST_COPY_FAIL" ]]; then\n'
                      '    echo "injected copy failure" >&2; exit 7\n  fi\ndone\n'
                      f'exec {shlex.quote(shutil.which("cp"))} "$@"\n')
        cp.chmod(0o755)
        for relative, body in {
            "scripts/generate-theme.sh": 'echo generate >> "$RO_TEST_STEPS"; exit "${RO_TEST_GENERATE_STATUS:-0}"',
            "scripts/validate.sh": 'echo validate >> "$RO_TEST_STEPS"; exit "${RO_TEST_VALIDATE_STATUS:-0}"',
            "tools/dev/apply-theme.sh": 'echo "apply:$*" >> "$RO_TEST_STEPS"; echo "application output" >&2; exit "${RO_TEST_APPLY_STATUS:-0}"',
        }.items():
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("#!/bin/bash\n" + body + "\n")
            path.chmod(0o755)
        self.installer = self.source / "tools/dev/install-local.sh"
        shutil.copyfile(SCRIPT, self.installer)
        for relative in (
            "platform/plasma/desktoptheme/RoLight", "platform/plasma/desktoptheme/RoDark",
            "platform/plasma/look-and-feel/org.ro.light", "platform/plasma/look-and-feel/org.ro.dark",
            "platform/plasma/layout-templates/org.ro.desktop", "platform/kwin/aurorae/RoLight",
            "platform/kwin/aurorae/RoDark", "platform/gtk/Ro-GTK",
            "platform/icons/ro-icons", "platform/cursor/ro-cursor",
        ):
            path = self.source / relative
            path.mkdir(parents=True)
            (path / "index.theme").write_text("fixture\n")
        for relative in (
            "platform/plasma/color-schemes/RoLight.colors", "platform/plasma/color-schemes/RoDark.colors",
            "assets/wallpapers/light.jpg", "assets/wallpapers/dark.jpg", "dist/qml/RoTokens.qml",
            "assets/wallpapers/RoLight/metadata.json", "assets/wallpapers/RoDark/metadata.json",
        ):
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(relative + "\n")
        (self.source / "platform/icons/ro-icons/alias.theme").symlink_to("index.theme")

    def install(self, *args):
        return subprocess.run([str(self.bin / "bash"), str(self.installer), *args],
                              env=self.env, capture_output=True, text=True)

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Local install complete.", result.stdout)

    def test_default_install_applies_dark_after_validation(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.steps.read_text(), "generate\nvalidate\napply:dark\n")
        self.assertIn("Local install complete.", result.stdout)

    def test_files_only_installs_resources_without_applying_or_changing_config(self):
        config = self.home / ".config/kdeglobals"
        config.parent.mkdir()
        config.write_text("[General]\nColorScheme=Personal\n")
        result = self.install("--files-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.steps.read_text(), "generate\nvalidate\n")
        self.assertEqual(config.read_text(), "[General]\nColorScheme=Personal\n")
        self.assertIn("Active KDE settings were not changed", result.stdout)
        self.assertEqual((self.home / ".local/share/ro-theme/qml/RoTokens.qml").read_text(), "dist/qml/RoTokens.qml\n")
        self.assertTrue((self.home / ".themes/Ro-GTK/index.theme").is_file())
        self.assertTrue((self.home / ".local/share/icons/ro-cursor/index.theme").is_file())
        alias = self.home / ".local/share/icons/ro-icons/alias.theme"
        self.assertTrue(alias.is_symlink())
        self.assertEqual(alias.read_text(), "fixture\n")

    def test_icon_copy_failure_is_not_ignored(self):
        self.env["RO_TEST_COPY_FAIL"] = "platform/icons/ro-icons"
        result = self.install()
        self.assert_failed(result)
        self.assertIn("injected copy failure", result.stderr)
        self.assertNotIn("apply:", self.steps.read_text())

    def test_cursor_copy_failure_is_not_ignored(self):
        self.env["RO_TEST_COPY_FAIL"] = "platform/cursor/ro-cursor"
        result = self.install()
        self.assert_failed(result)
        self.assertNotIn("apply:", self.steps.read_text())

    def test_apply_failure_returns_failure_with_command_output(self):
        self.env["RO_TEST_APPLY_STATUS"] = "9"
        result = self.install()
        self.assert_failed(result)
        self.assertIn("Local files were installed, but applying", result.stderr)
        self.assertIn("application output", result.stderr)
        self.assertIn("apply:dark", self.steps.read_text())

    def test_generate_failure_stops_before_installation(self):
        self.env["RO_TEST_GENERATE_STATUS"] = "5"
        self.assert_failed(self.install())
        self.assertEqual(self.steps.read_text(), "generate\n")
        self.assertFalse((self.home / ".local").exists())

    def test_validation_failure_stops_before_installation(self):
        self.env["RO_TEST_VALIDATE_STATUS"] = "5"
        self.assert_failed(self.install())
        self.assertEqual(self.steps.read_text(), "generate\nvalidate\n")
        self.assertFalse((self.home / ".local").exists())

    def test_unknown_argument_stops_before_any_work(self):
        result = self.install("--unknown-option")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.steps.read_text(), "")
        self.assertFalse((self.home / ".local").exists())

    def test_help_performs_no_work(self):
        result = self.install("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--files-only", result.stdout)
        self.assertEqual(self.steps.read_text(), "")
        self.assertFalse((self.home / ".local").exists())

    def test_files_only_still_reports_copy_errors(self):
        self.env["RO_TEST_COPY_FAIL"] = "platform/icons/ro-icons"
        self.assert_failed(self.install("--files-only"))
        self.assertNotIn("apply:", self.steps.read_text())


if __name__ == "__main__":
    unittest.main()
