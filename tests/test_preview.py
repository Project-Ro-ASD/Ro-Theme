"""ro system-preview için hermetik testler: geçici kök ve sahte PATH kullanır."""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.helpers import ROOT  # noqa: F401  (rotheme'i import yoluna ekler)
from rotheme import manifest, preview
from rotheme.cli import build_parser


def parse(*args):
    return build_parser().parse_args(["system-preview", *args])


class PreviewTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.src = self.base / "src"
        for entry in manifest.PREVIEW_ENTRIES:
            source = self.src / entry.src
            if source.suffix == "":
                source.mkdir(parents=True)
                (source / f"{manifest.PLYMOUTH_THEME}.plymouth").write_text("[Plymouth Theme]\n")
                (source / "bullet.png").write_bytes(b"png")
            else:
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes(b"kaynak-" + entry.src.encode())
        self.root = self.base / "root"
        self.xdg = self.root / "etc/xdg/kdeglobals"
        self.xdg.parent.mkdir(parents=True)
        self.xdg.write_text("[General]\nColorScheme=Yonetici\n")
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.log = self.base / "plymouth.log"
        self.activation = self.bin / "plymouth-set-default-theme"
        self.activation.write_text('#!/bin/sh\necho "$*" >> "$RO_PLYMOUTH_LOG"\nexit "${RO_PLYMOUTH_STATUS:-0}"\n')
        self.activation.chmod(0o755)
        self.env = {
            "RO_THEME_SYSROOT": str(self.root),
            "PATH": str(self.bin),
            "RO_PLYMOUTH_LOG": str(self.log),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def target(self, entry):
        return self.root / entry.dest.format(**manifest.DIRS).lstrip("/")

    def run_preview(self, *args, euid=0):
        with mock.patch.dict(os.environ, self.env, clear=False), \
                mock.patch.object(preview, "ROOT", self.src), \
                mock.patch.object(preview.os, "geteuid", return_value=euid):
            return preview.main(parse(*args))

    def test_root_degilse_calismaz(self):
        self.assertEqual(self.run_preview(euid=1000), 1)
        self.assertFalse(self.log.exists())

    def test_kurulum_manifest_yollarini_kullanir_ve_etc_xdg_degismez(self):
        before = self.xdg.read_bytes()
        self.assertEqual(self.run_preview(), 0)
        for entry in manifest.PREVIEW_ENTRIES:
            target = self.target(entry)
            self.assertTrue(target.exists(), target)
        wallpaper = next(e for e in manifest.PREVIEW_ENTRIES if e.src.endswith("loginv2.jpg"))
        self.assertEqual(self.target(wallpaper).read_bytes(),
                         (self.src / wallpaper.src).read_bytes())
        self.assertEqual(self.log.read_text().strip(), "-R ro-theme")
        self.assertEqual(self.xdg.read_bytes(), before)

    def test_remove_kurulanlari_siler_ve_plymouthu_sifirlar(self):
        self.assertEqual(self.run_preview(), 0)
        self.log.unlink()
        self.assertEqual(self.run_preview("--remove"), 0)
        for entry in manifest.PREVIEW_ENTRIES:
            self.assertFalse(self.target(entry).exists(), self.target(entry))
        self.assertEqual(self.log.read_text().strip(), "--reset -R")
        self.assertTrue(self.xdg.is_file())

    def test_eksik_kaynak_mevcut_kurulumu_bozmaz(self):
        self.assertEqual(self.run_preview(), 0)
        self.log.unlink()
        entry = next(e for e in manifest.PREVIEW_ENTRIES if e.src.endswith("loginv2.jpg"))
        target = self.target(entry)
        before = target.read_bytes()
        (self.src / entry.src).unlink()
        self.assertEqual(self.run_preview(), 1)
        self.assertEqual(target.read_bytes(), before)
        self.assertFalse(self.log.exists())

    def test_plymouth_komutu_yoksa_dosyalar_kurulur(self):
        self.activation.unlink()
        self.assertEqual(self.run_preview(), 0)
        for entry in manifest.PREVIEW_ENTRIES:
            self.assertTrue(self.target(entry).exists())
        self.assertFalse(self.log.exists())

    def test_rpm_ile_kuruluysa_uyarip_cikar(self):
        rpm = self.bin / "rpm"
        rpm.write_text("#!/bin/sh\nexit 0\n")
        rpm.chmod(0o755)
        self.assertEqual(self.run_preview(), 1)
        for entry in manifest.PREVIEW_ENTRIES:
            self.assertFalse(self.target(entry).exists())


if __name__ == "__main__":
    unittest.main()
