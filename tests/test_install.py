import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests import fakes
from tests.helpers import ROOT  # noqa: F401
from rotheme import install
from rotheme.cli import build_parser


def parse(*args):
    return build_parser().parse_args(list(args))


class SystemInstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.src = fakes.make_source(self.base / "src")
        self.dest = self.base / "dest"
        self.list = self.base / "files.list"

    def tearDown(self):
        self.tmp.cleanup()

    def run_install(self):
        with mock.patch.object(install, "ROOT", self.src):
            return install.main(parse("install", "--destdir", str(self.dest),
                                      "--record-files", str(self.list)))

    def test_destdir_install_and_record(self):
        self.assertEqual(self.run_install(), 0)
        colors = self.dest / "usr/share/color-schemes/RoLight.colors"
        self.assertTrue(colors.is_file())
        self.assertEqual(stat.S_IMODE(colors.stat().st_mode), 0o644)
        diagnose = self.dest / "usr/bin/ro-theme-diagnose"
        self.assertEqual(stat.S_IMODE(diagnose.stat().st_mode), 0o755)

        index = self.dest / "usr/share/icons/ro-icons-light/index.theme"
        self.assertIn("Name=Ro Icons (Light)", index.read_text())
        self.assertIn("Inherits=Papirus-Light", index.read_text())
        actions = self.dest / "usr/share/icons/ro-icons-light/actions"
        self.assertTrue(actions.is_symlink())
        self.assertEqual(os.readlink(actions), "../ro-icons/actions")

        lib = self.dest / "usr/share/ro-theme/lib/rotheme"
        self.assertTrue((lib / "bin/ro-theme-diagnose").is_file())
        self.assertFalse((lib / "__pycache__").exists())
        self.assertFalse((lib / "tests").exists())

        recorded = self.list.read_text()
        self.assertIn("%config(noreplace) /etc/xdg/kdeglobals", recorded)
        self.assertIn("%dir /var/lib/ro-theme", recorded)
        self.assertIn("%ghost /var/lib/ro-theme/plymouth.sha256", recorded)
        self.assertIn("/usr/share/icons/ro-icons-light/index.theme", recorded)
        self.assertNotIn("LICENSE", recorded)
        self.assertNotIn("README", recorded)

    def test_identical_images_are_hardlinked(self):
        self.assertEqual(self.run_install(), 0)
        light = self.dest / "usr/share/wallpapers/RoLight/contents/images/1920x1080.jpg"
        dark = self.dest / "usr/share/wallpapers/RoDark/contents/images/1920x1080.jpg"
        self.assertEqual(light.stat().st_ino, dark.stat().st_ino)

    def test_missing_source_is_reported_and_nothing_written(self):
        (self.src / "platform/plasma/color-schemes/RoLight.colors").unlink()
        with mock.patch("sys.stderr") as stderr:
            self.assertEqual(self.run_install(), 1)
        self.assertIn("eksik kaynak", "".join(str(c) for c in stderr.write.call_args_list))
        self.assertFalse((self.dest / "usr").exists())
        self.assertFalse(self.list.exists())


class LocalInstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.src = fakes.make_source(self.base / "src")
        self.home = self.base / "home"
        self.data = self.base / "data"
        self.env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.data),
                    "XDG_CONFIG_HOME": str(self.base / "config"),
                    "PATH": "/usr/bin:/bin"}

    def tearDown(self):
        self.tmp.cleanup()

    def test_local_install_backs_up_previous_tree(self):
        fakes.write(self.data / "ro-theme/old.txt", "eski")
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(install, "ROOT", self.src):
            self.assertEqual(install.main(parse("install", "--local", "--files-only")), 0)

        self.assertTrue((self.data / "ro-theme/qml/RoTokens.qml").is_file())
        self.assertTrue((self.data / "icons/ro-icons-light/index.theme").is_file())
        backups = list((self.data / "ro-theme").glob("yedek-*"))
        self.assertEqual(len(backups), 1)
        self.assertTrue((backups[0] / "old.txt").is_file())
        self.assertFalse((self.home / ".local/share").exists())

    def test_uninstall_keeps_backup_and_removes_components(self):
        fakes.write(self.data / "ro-theme/old.txt", "eski")
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(install, "ROOT", self.src):
            self.assertEqual(install.main(parse("install", "--local")), 0)
            self.assertEqual(install.main(parse("uninstall")), 0)

        self.assertFalse((self.data / "ro-theme/qml").exists())
        self.assertFalse((self.data / "icons/ro-icons-light").exists())
        self.assertEqual(len(list((self.data / "ro-theme").glob("yedek-*"))), 1)


if __name__ == "__main__":
    unittest.main()
