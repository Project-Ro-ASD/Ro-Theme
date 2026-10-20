#!/usr/bin/env python3
"""RPM test aracının yol, seçenek ve en yeni paket seçimini yalıtılmış dosyalarla sınar."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("test-rpm.sh").resolve()
# Seçim testlerinin paket içeriğinden bağımsız çalışması için geçerli örnek liste.
PAYLOAD = """/usr/share/color-schemes/RoLight.colors
/usr/share/color-schemes/RoDark.colors
/usr/share/plasma/desktoptheme/RoLight/metadata.json
/usr/share/plasma/desktoptheme/RoLight/colors
/usr/share/plasma/desktoptheme/RoLight/plasmarc
/usr/share/plasma/desktoptheme/RoDark/metadata.json
/usr/share/plasma/desktoptheme/RoDark/colors
/usr/share/plasma/desktoptheme/RoDark/plasmarc
/usr/share/plasma/look-and-feel/org.ro.light/metadata.json
/usr/share/plasma/look-and-feel/org.ro.dark/metadata.json
/usr/share/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js
/usr/share/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js
/usr/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg
/usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
/usr/share/ro-theme/wallpapers/light.jpg
/usr/share/ro-theme/wallpapers/dark.jpg
/usr/share/ro-theme/wallpapers/login.jpg
/usr/share/wallpapers/RoLight/metadata.json
/usr/share/wallpapers/RoLight/contents/images/1920x1080.jpg
/usr/share/wallpapers/RoLight/contents/images/3840x2160.jpg
/usr/share/wallpapers/RoDark/metadata.json
/usr/share/wallpapers/RoDark/contents/images/1920x1080.jpg
/usr/share/wallpapers/RoDark/contents/images/3840x2160.jpg
/usr/share/plymouth/themes/ro-theme/ro-theme.plymouth
/usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf
/usr/bin/ro-theme-diagnose
/usr/libexec/ro-theme/apply-dark-defaults
/usr/libexec/ro-theme/check-plasma-runtime
/etc/xdg/kdeglobals
/etc/xdg/kcmfonts
/usr/share/ro-theme/qml/RoTokens.qml
/etc/xdg/breezerc
/etc/xdg/plasmarc
/etc/xdg/ksplashrc
/etc/xdg/kscreenlockerrc
/etc/xdg/kwinrc
"""


class RpmSelection(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.repo = self.root / "source with spaces"
        self.script = self.repo / "tools/dev/test-rpm.sh"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.script)
        self.home = self.root / "user with spaces"
        self.home.mkdir()
        self.caller = self.root / "caller"
        self.caller.mkdir()
        self.calls = self.root / "calls.jsonl"
        self.calls.touch()
        self.payload = self.root / "payload"
        self.payload.write_text(PAYLOAD)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("bash", "dirname", "find", "sort", "sed", "tail", "mktemp", "grep", "cat", "rm"):
            (self.bin / name).symlink_to(shutil.which(name))
        rpm = self.bin / "rpm"
        rpm.write_text(f'#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\n'
                       'with open(os.environ["RO_TEST_CALLS"], "a") as log:\n'
                       '    log.write(json.dumps(sys.argv[1:]) + "\\n")\n'
                       'if sys.argv[1] == "-qlp":\n'
                       '    print(Path(os.environ["RO_TEST_PAYLOAD"]).read_text(), end="")\n')
        rpm.chmod(0o755)
        self.env = os.environ | {"HOME": str(self.home), "PATH": str(self.bin),
                                 "TMPDIR": str(self.root), "RO_TEST_CALLS": str(self.calls),
                                 "RO_TEST_PAYLOAD": str(self.payload)}

    def artifact(self, base, name="ro-theme-1.1.3-1.noarch.rpm", timestamp=10):
        path = base / "rpmbuild/RPMS/noarch" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
        os.utime(path, (timestamp, timestamp))
        return path

    def run_check(self, *args):
        return subprocess.run([str(self.bin / "bash"), str(self.script), *map(str, args)],
                              cwd=self.caller, env=self.env, capture_output=True, text=True)

    def assert_tested(self, expected, *args):
        result = self.run_check(*args)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        paths = [Path(call[-1]).resolve() for call in calls if call[0] in ("-K", "-qip", "-qlp", "-Uvh")]
        self.assertEqual(paths, [expected.resolve()] * 4)
        return calls

    def test_newer_workspace_package_wins_over_older_home_package(self):
        expected = self.artifact(self.repo / "build", timestamp=20)
        self.artifact(self.home, timestamp=10)
        self.assert_tested(expected)

    def test_newer_home_package_wins(self):
        self.artifact(self.repo / "build", timestamp=10)
        expected = self.artifact(self.home, timestamp=20)
        self.assert_tested(expected)

    def test_workspace_only(self):
        self.assert_tested(self.artifact(self.repo / "build"))

    def test_home_only(self):
        self.assert_tested(self.artifact(self.home))

    def test_automatic_selection_ignores_source_and_other_architectures(self):
        expected = self.artifact(self.repo / "build", timestamp=10)
        self.artifact(self.home, name="ro-theme-new.src.rpm", timestamp=30)
        self.artifact(self.home, name="ro-theme-new.x86_64.rpm", timestamp=40)
        self.assert_tested(expected)

    def test_relative_path_uses_callers_directory(self):
        expected = self.caller / "my package.rpm"
        expected.touch()
        self.assert_tested(expected, expected.name)

    def test_explicit_path_wins_over_newer_automatic_candidate(self):
        expected = self.artifact(self.repo / "build", timestamp=10)
        self.artifact(self.home, timestamp=30)
        self.assert_tested(expected, expected)

    def test_verify_option_before_or_after_explicit_path(self):
        expected = self.caller / "new.rpm"
        expected.touch()
        for args in (("--verify-installed", expected), (expected, "--verify-installed")):
            with self.subTest(args=args):
                self.calls.write_text("")
                calls = self.assert_tested(expected, *args)
                self.assertIn(["-V", "ro-theme"], calls)

    def test_verify_option_with_automatic_selection(self):
        expected = self.artifact(self.repo / "build")
        calls = self.assert_tested(expected, "--verify-installed")
        self.assertIn(["-V", "ro-theme"], calls)

    def test_missing_package_runs_no_rpm_command(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls.read_text(), "")

    def test_unknown_option_runs_no_rpm_command(self):
        self.artifact(self.repo / "build")
        result = self.run_check("--unknown-option")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown argument", result.stderr)
        self.assertEqual(self.calls.read_text(), "")

    def test_multiple_paths_are_rejected(self):
        expected = self.artifact(self.repo / "build")
        result = self.run_check(expected, expected)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls.read_text(), "")

    def test_help_runs_no_rpm_command(self):
        result = self.run_check("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stdout)
        self.assertEqual(self.calls.read_text(), "")


if __name__ == "__main__":
    unittest.main()
