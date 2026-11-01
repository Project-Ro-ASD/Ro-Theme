#!/usr/bin/env python3
"""Görünüm sıfırlama aracını gerçek kullanıcı ayarlarına dokunmadan sınar."""
import os
from pathlib import Path
import shlex
import shutil
import stat
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/apply-dark-defaults.sh"
ORIGINAL = "[General]\nColorScheme=Personal\nUnrelated=keep\n"
SECOND = "[General]\nforceFontDPI=120\nOther=keep\n"


class AppearanceReset(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.config = self.root / "user"
        self.system = self.root / "system"
        self.bin = self.root / "bin"
        for directory in (self.config, self.system, self.bin):
            directory.mkdir()
        self.user_file = self.config / "kdeglobals"
        self.user_file.write_text(ORIGINAL)
        self.user_file.chmod(0o640)
        (self.system / "kdeglobals").write_text("[General]\nColorScheme=RoDark\n")
        (self.config / "ro-theme").mkdir()
        self.marker = self.config / "ro-theme/default-dark-applied"
        self.marker.write_text("legacy\n")

    def second_file(self):
        (self.config / "kcmfonts").write_text(SECOND)
        (self.system / "kcmfonts").write_text("[General]\nforceFontDPI=0\n")

    def stub(self, command, condition):
        real = shlex.quote(shutil.which(command))
        path = self.bin / command
        path.write_text(f'#!/bin/bash\n{condition}\nexec {real} "$@"\n')
        path.chmod(0o755)

    def run_reset(self, *args):
        options = {}
        if os.geteuid() == 0:
            # CI konteyneri root çalışır; aracı yine gerçek yetkisiz UID ile sına.
            for directory, dirs, files in os.walk(self.root):
                for path in [Path(directory), *(Path(directory) / p for p in dirs + files)]:
                    os.chown(path, 65534, 65534, follow_symlinks=False)
            options = {"user": 65534, "group": 65534, "extra_groups": []}
        return subprocess.run(
            ["bash", str(SCRIPT), *args], capture_output=True, text=True,
            env=os.environ | {"XDG_CONFIG_HOME": str(self.config),
                              "RO_THEME_SYSTEM_XDG": str(self.system),
                              "TMPDIR": str(self.root),
                              "PATH": str(self.bin) + ":" + os.environ["PATH"]},
            **options,
        )

    def assert_clean(self):
        self.assertEqual(list(self.config.glob(".ro-theme-reset.*")), [])
        self.assertEqual({p.name for p in self.root.iterdir()}, {"user", "system", "bin"})

    def assert_failed_unchanged(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("settings reset to the system defaults:", result.stdout)
        self.assertEqual(self.user_file.read_text(), ORIGINAL)
        self.assertTrue(self.marker.exists())
        self.assert_clean()

    def test_reset_preserves_other_keys_permissions_and_exact_backup(self):
        result = self.run_reset()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.user_file.read_text(), "[General]\nUnrelated=keep\n")
        self.assertEqual(stat.S_IMODE(self.user_file.stat().st_mode), 0o640)
        backups = list((self.config / "ro-theme").glob("backup-*/kdeglobals"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), ORIGINAL)
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o640)
        self.assertFalse(self.marker.exists())
        self.assert_clean()

    def test_dry_run_writes_no_settings_or_backups(self):
        result = self.run_reset("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("would reset: kdeglobals [General] ColorScheme", result.stdout)
        self.assertEqual(self.user_file.read_text(), ORIGINAL)
        self.assertTrue(self.marker.exists())
        self.assertEqual(list((self.config / "ro-theme").glob("backup-*")), [])
        self.assert_clean()

    def test_backup_parent_failure_preserves_original(self):
        self.marker.unlink()
        self.marker.parent.rmdir()
        self.marker.parent.write_text("blocked\n")
        result = self.run_reset()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.user_file.read_text(), ORIGINAL)
        self.assertNotIn("settings reset to the system defaults:", result.stdout)
        self.assert_clean()

    def test_second_backup_failure_preserves_all_configs(self):
        self.second_file()
        self.stub("cp", '[[ "${@: -1}" == */backup-*/kcmfonts ]] && exit 1')
        result = self.run_reset()
        self.assert_failed_unchanged(result)
        self.assertEqual((self.config / "kcmfonts").read_text(), SECOND)

    def test_system_read_failure_is_not_silently_ignored(self):
        self.stub("awk", '[[ "${@: -1}" == */system/kdeglobals ]] && exit 1')
        self.assert_failed_unchanged(self.run_reset())

    def test_filter_failure_does_not_count_as_removed_settings(self):
        self.stub("awk", '[[ "$1" == -F* ]] && { echo "simulated read failure" >&2; exit 1; }')
        self.assert_failed_unchanged(self.run_reset())

    def test_unreadable_user_file(self):
        self.user_file.chmod(0)
        result = self.run_reset()
        self.user_file.chmod(0o640)
        self.assert_failed_unchanged(result)

    def test_staging_write_failure_preserves_original(self):
        self.stub("cat", '[[ "$1" == *.out ]] && { printf "partial"; exit 1; }')
        self.assert_failed_unchanged(self.run_reset())

    def test_permission_copy_failure_preserves_original(self):
        self.stub("chmod", "exit 1")
        self.assert_failed_unchanged(self.run_reset())

    def test_replace_failure_preserves_original(self):
        self.stub("mv", "exit 1")
        self.assert_failed_unchanged(self.run_reset())

    def test_later_replace_failure_keeps_backups_and_reports_error(self):
        self.second_file()
        self.stub("mv", '[[ "${@: -1}" == */kcmfonts ]] && exit 1')
        result = self.run_reset()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("settings reset to the system defaults:", result.stdout)
        self.assertTrue(self.marker.exists())
        self.assertEqual((self.config / "kcmfonts").read_text(), SECOND)
        backups = list((self.config / "ro-theme").glob("backup-*"))
        self.assertEqual((backups[0] / "kdeglobals").read_text(), ORIGINAL)
        self.assertEqual((backups[0] / "kcmfonts").read_text(), SECOND)
        self.assertIn("Backup directory:", result.stderr)
        self.assert_clean()

    def test_concurrent_edit_is_not_overwritten(self):
        self.stub("chmod", 'printf "[General]\\nNew=concurrent\\n" > "$XDG_CONFIG_HOME/kdeglobals"')
        result = self.run_reset()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.user_file.read_text(), "[General]\nNew=concurrent\n")
        self.assertTrue(self.marker.exists())
        self.assert_clean()

    def test_localized_and_deleted_keys_and_legacy_keys(self):
        self.user_file.write_text('[General]\nColorScheme[tr]=Kişisel\nColorScheme[$d]\nUnrelated=keep\n\n[KDE]\nColorScheme=Legacy\nOther=stay\n')
        result = self.run_reset()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("3 setting(s)", result.stdout)
        self.assertEqual(self.user_file.read_text(), "[General]\nUnrelated=keep\n\n[KDE]\nOther=stay\n")

    def test_empty_managed_list_keeps_unmanaged_file(self):
        original = "[General]\nUnrelated=keep\n\n"
        self.user_file.write_text(original)
        (self.config / "plasmarc").write_text(original)
        (self.system / "plasmarc").touch()
        result = self.run_reset()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0 setting(s)", result.stdout)
        self.assertEqual(self.user_file.read_text(), original)
        self.assertEqual((self.config / "plasmarc").read_text(), original)
        self.assertEqual(list((self.config / "ro-theme").glob("backup-*")), [])

    def test_symlink_is_rejected_without_replacing_or_following_it(self):
        target = self.config / "linked-config"
        self.user_file.rename(target)
        self.user_file.symlink_to(target.name)
        self.assert_failed_unchanged(self.run_reset())
        self.assertTrue(self.user_file.is_symlink())
        self.assertEqual(target.read_text(), ORIGINAL)


if __name__ == "__main__":
    unittest.main()
