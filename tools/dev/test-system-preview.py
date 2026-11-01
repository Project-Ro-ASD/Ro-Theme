#!/usr/bin/env python3
"""Önizleme kurulumunu yalnız kök yetkili, geçici konteynerde gerçek dosya yollarıyla sınar."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/dev/install-system-preview.sh"
ISOLATED = os.geteuid() == 0 and any(Path(p).exists() for p in ("/run/.containerenv", "/.dockerenv"))
TARGETS = (
    Path("/etc/xdg/kdeglobals"),
    Path("/usr/share/ro-theme/wallpapers/login.jpg"),
    Path("/usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf"),
    Path("/usr/share/plymouth/themes/ro-theme"),
)


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def copy(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir() and not source.is_symlink():
        shutil.copytree(source, dest, symlinks=True)
    else:
        shutil.copy2(source, dest, follow_symlinks=False)


@unittest.skipUnless(ISOLATED, "Root Fedora CI/container required; host system is never modified")
class SystemPreview(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        # Konteynerin önceki dosyalarını her testten sonra geri yükle; bağlantıları izleme.
        self.saved = {}
        for index, target in enumerate(TARGETS):
            if target.exists() or target.is_symlink():
                backup = self.root / "backup" / str(index)
                copy(target, backup)
                self.saved[target] = backup
        self.addCleanup(self.restore)
        for target in TARGETS:
            remove(target)
            target.parent.mkdir(parents=True, exist_ok=True)
        TARGETS[0].write_text("[KDE]\nColorScheme=Administrator\n[General]\nColorScheme=Personal\n[Unrelated]\nKeep=1\n")
        TARGETS[0].chmod(0o640)
        TARGETS[1].write_bytes(b"old wallpaper")
        TARGETS[2].write_text("old login config\n")
        TARGETS[3].mkdir()
        (TARGETS[3] / "old-theme-marker").write_text("keep until sources are checked\n")
        self.before = self.snapshot()
        self.source = self.root / "source"
        self.script = self.source / "tools/dev/install-system-preview.sh"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.script)
        for relative in ("assets/wallpapers/loginv2.jpg", "platform/plasmalogin/20-ro-theme.conf",
                         "platform/plymouth/ro-theme"):
            copy(ROOT / relative, self.source / relative)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("bash", "dirname", "mkdir", "rm", "install", "cp", "chmod", "kwriteconfig6"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.log = self.root / "activation.log"
        self.log.touch()
        self.activation = self.bin / "plymouth-set-default-theme"
        self.activation.write_text('#!/bin/bash\necho "$*" >> "$RO_TEST_ACTIVATION_LOG"\necho "activation output" >&2\nexit "${RO_TEST_ACTIVATION_STATUS:-0}"\n')
        self.activation.chmod(0o755)
        self.env = os.environ | {"PATH": str(self.bin), "RO_TEST_ACTIVATION_LOG": str(self.log),
                                 "RO_TEST_ACTIVATION_STATUS": "0"}

    def restore(self):
        for target in TARGETS:
            remove(target)
            if target in self.saved:
                copy(self.saved[target], target)

    def snapshot(self):
        result = {}
        for target in TARGETS:
            files = target.rglob("*") if target.is_dir() else [target]
            for path in files:
                if path.is_file():
                    result[str(path)] = (path.read_bytes(), path.stat().st_mode, path.stat().st_mtime_ns)
        return result

    def run_preview(self, *args):
        return subprocess.run([str(self.bin / "bash"), str(self.script), *args], env=self.env,
                              capture_output=True, text=True)

    def assert_desktop_defaults_preserved(self):
        self.assertEqual(self.snapshot()[str(TARGETS[0])], self.before[str(TARGETS[0])])

    def test_success_preserves_admin_desktop_settings_and_installs_only_preview_resources(self):
        result = self.run_preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_desktop_defaults_preserved()
        self.assertEqual(TARGETS[1].read_bytes(), (self.source / "assets/wallpapers/loginv2.jpg").read_bytes())
        self.assertEqual(TARGETS[2].read_bytes(), (self.source / "platform/plasmalogin/20-ro-theme.conf").read_bytes())
        for original in (self.source / "platform/plymouth/ro-theme").rglob("*"):
            if original.is_file():
                self.assertEqual((TARGETS[3] / original.relative_to(self.source / "platform/plymouth/ro-theme")).read_bytes(), original.read_bytes())
        self.assertFalse((TARGETS[3] / "old-theme-marker").exists())
        self.assertEqual(self.log.read_text(), "ro-theme -R\n")

    def assert_missing_source_keeps_existing_installation(self, relative, directory=False):
        path = self.source / relative
        path.unlink()
        if directory:
            path.mkdir()
        result = self.run_preview()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), self.before)
        self.assertEqual(self.log.read_text(), "")

    def test_missing_wallpaper_preserves_existing_installation(self):
        self.assert_missing_source_keeps_existing_installation("assets/wallpapers/loginv2.jpg")

    def test_missing_login_config_preserves_existing_installation(self):
        self.assert_missing_source_keeps_existing_installation("platform/plasmalogin/20-ro-theme.conf")

    def test_missing_plymouth_descriptor_preserves_existing_installation(self):
        self.assert_missing_source_keeps_existing_installation("platform/plymouth/ro-theme/ro-theme.plymouth")

    def test_directory_instead_of_source_file_is_rejected_before_installation(self):
        self.assert_missing_source_keeps_existing_installation("assets/wallpapers/loginv2.jpg", directory=True)

    def test_activation_failure_returns_error_with_output_and_preserves_desktop_defaults(self):
        self.env["RO_TEST_ACTIVATION_STATUS"] = "7"
        result = self.run_preview()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("activation output", result.stderr)
        self.assertNotIn("System preview installed. Reboot", result.stdout)
        self.assert_desktop_defaults_preserved()

    def test_missing_plymouth_command_reports_files_only_installation(self):
        self.activation.unlink()
        result = self.run_preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Plymouth activation was skipped", result.stdout)
        self.assertNotIn("Reboot to test", result.stdout)
        self.assert_desktop_defaults_preserved()
        self.assertEqual(self.log.read_text(), "")

    def test_help_runs_no_installation(self):
        result = self.run_preview("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Usage:", result.stdout)
        self.assertEqual(self.snapshot(), self.before)
        self.assertEqual(self.log.read_text(), "")

    def test_unknown_option_runs_no_installation(self):
        result = self.run_preview("--dry-run")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown argument", result.stderr)
        self.assertEqual(self.snapshot(), self.before)
        self.assertEqual(self.log.read_text(), "")


if __name__ == "__main__":
    if "--require-container" in sys.argv:
        sys.argv.remove("--require-container")
        if not ISOLATED:
            raise SystemExit("These installation tests require root inside a disposable container.")
    unittest.main()
