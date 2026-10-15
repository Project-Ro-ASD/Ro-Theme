#!/usr/bin/env python3
"""Geçerli varlıklar ve bozuk paket girdileri için doğrulayıcı regresyonları."""
import importlib.util
import gzip
from pathlib import Path
import tempfile
import unittest

source = Path(__file__).resolve().parents[2] / "scripts/validate-assets.py"
spec = importlib.util.spec_from_file_location("asset_validator", source)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class AssetValidation(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.theme = self.root / "platform/icons/Test"
        self.icons = self.theme / "actions/16"
        self.icons.mkdir(parents=True)
        self.svg = self.icons / "arrow.svg"
        self.svg.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
        (self.theme / "index.theme").write_text(
            "[Icon Theme]\nDirectories=actions/16\n[actions/16]\nSize=16\n")

    def test_valid_assets_and_alias(self):
        (self.icons / "next.svg").symlink_to("arrow.svg")
        (self.root / "platform/metadata.json").write_text('{"name":"Test"}')
        errors, counts = validator.validate(self.root)
        self.assertEqual(errors, [])
        self.assertEqual(counts["symlinks"], 1)

    def test_malformed_svg(self):
        self.svg.write_text("<svg><path></svg>")
        self.assertTrue(validator.validate(self.root)[0])

    def test_non_svg_xml(self):
        self.svg.write_text("<html/>")
        self.assertTrue(validator.validate(self.root)[0])

    def test_broken_alias(self):
        (self.icons / "next.svg").symlink_to("missing.svg")
        self.assertTrue(validator.validate(self.root)[0])

    def test_external_alias(self):
        (self.icons / "next.svg").symlink_to(source)
        self.assertTrue(validator.validate(self.root)[0])

    def test_missing_icon_directory(self):
        (self.theme / "index.theme").write_text("[Icon Theme]\nDirectories=actions/32\n")
        self.assertTrue(validator.validate(self.root)[0])

    def test_invalid_json(self):
        (self.root / "platform/metadata.json").write_text("{broken}")
        self.assertTrue(validator.validate(self.root)[0])

    def test_compressed_svg(self):
        self.svg.with_suffix(".svgz").write_bytes(gzip.compress(self.svg.read_bytes()))
        self.assertEqual(validator.validate(self.root)[0], [])

    def test_truncated_compressed_svg(self):
        self.svg.with_suffix(".svgz").write_bytes(gzip.compress(self.svg.read_bytes())[:12])
        self.assertTrue(validator.validate(self.root)[0])


if __name__ == "__main__":
    unittest.main()
