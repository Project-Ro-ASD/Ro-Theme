"""ro smoke için hermetik testler: gerçek oturuma ve gerçek KDE ayarlarına dokunmaz."""
from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from tests.helpers import ROOT  # noqa: F401  (rotheme'i import yoluna ekler)
from rotheme import manifest, smoke


class SmokeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.config = self.base / "config"
        self.data = self.base / "data"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.config),
            "XDG_DATA_HOME": str(self.data),
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        }
        self.config.mkdir()
        (self.config / "plasma-org.kde.plasma.desktop-appletsrc").write_text("panel=eski\n")
        (self.config / "kdeglobals").write_text("[General]\nColorScheme=RoDark\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_onay_verilmezse_hicbir_sey_yapmaz(self):
        with mock.patch.object(smoke, "_run_step") as step, \
                mock.patch("builtins.input", return_value="hayır"):
            self.assertEqual(smoke.run(yes=False, env=self.env), 1)
        step.assert_not_called()
        self.assertFalse((self.data / manifest.BACKUP_DIR).exists())

    def test_yes_yedek_alir_ve_adimlari_sirayla_calistirir(self):
        calls = []

        def fake_step(name, command, env):
            calls.append((name, command))
            return True

        with mock.patch.object(smoke, "_run_step", side_effect=fake_step), \
                mock.patch.object(smoke, "_crashes", return_value=(True, [])):
            self.assertEqual(smoke.run(yes=True, env=self.env), 0)

        self.assertEqual([name for name, _ in calls], [name for name, _ in smoke.STEPS])
        backups = list((self.data / manifest.BACKUP_DIR).glob("yedek-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "plasma-org.kde.plasma.desktop-appletsrc").read_text(),
                         "panel=eski\n")
        self.assertTrue((backups[0] / "kdeglobals").is_file())

    def test_basarisiz_adimda_durur(self):
        calls = []

        def fake_step(name, command, env):
            calls.append(name)
            return len(calls) < 2

        with mock.patch.object(smoke, "_run_step", side_effect=fake_step), \
                mock.patch.object(smoke, "_crashes", return_value=(True, [])):
            self.assertEqual(smoke.run(yes=True, env=self.env), 1)
        self.assertEqual(calls, ["generate --check", "validate"])

    def test_cokme_denetimi_coredumpctl_ile(self):
        tool = self.bin / "coredumpctl"
        tool.write_text('#!/bin/sh\necho "Mon 2026-11-02 10:00:00 UTC 1 1 1 plasmashell"\n')
        tool.chmod(0o755)
        env = dict(self.env, PATH=str(self.bin))
        ok, lines = smoke._crashes(datetime.now(), env)
        self.assertFalse(ok)
        self.assertEqual(len(lines), 1)

        tool.write_text("#!/bin/sh\nexit 0\n")
        tool.chmod(0o755)
        ok, lines = smoke._crashes(datetime.now(), env)
        self.assertTrue(ok)
        self.assertEqual(lines, [])


if __name__ == "__main__":
    unittest.main()
