import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.helpers import ROOT
from rotheme import generate, manifest
from rotheme.cli import main


class GenerateFrameworkTest(unittest.TestCase):
    def fake(self, files):
        return mock.patch.object(generate, "collect", return_value={k: v.encode() for k, v in files.items()})

    def test_writes_then_check_passes(self):
        with tempfile.TemporaryDirectory() as d, self.fake({"a/b.txt": "x\n"}):
            self.assertEqual(generate.run(ROOT, outdir=Path(d)), 0)
            self.assertEqual((Path(d) / "a/b.txt").read_text(), "x\n")
            self.assertEqual(generate.run(ROOT, outdir=Path(d), check=True), 0)

    def test_check_reports_stale_without_writing(self):
        with tempfile.TemporaryDirectory() as d, self.fake({"a.txt": "yeni\n"}):
            (Path(d) / "a.txt").write_text("eski\n")
            self.assertEqual(generate.run(ROOT, outdir=Path(d), check=True), 1)
            self.assertEqual((Path(d) / "a.txt").read_text(), "eski\n")

    def test_module_failure_writes_nothing(self):
        with tempfile.TemporaryDirectory() as d, mock.patch.object(generate, "collect", side_effect=RuntimeError):
            with self.assertRaises(RuntimeError):
                generate.run(ROOT, outdir=Path(d))
            self.assertEqual(list(Path(d).iterdir()), [])


class ManifestTest(unittest.TestCase):
    def test_sources_exist_or_are_generated(self):
        generated = set(generate.collect(generate.Context(__import__("rotheme.tokens").tokens.load(ROOT), ROOT)))
        for e in manifest.INSTALL:
            path = ROOT / e.src
            self.assertTrue(path.exists() or e.src in generated or any(g.startswith(e.src + "/") for g in generated)
                            or e.src.startswith("platform/plasma/defaults/xdg/")
                            or e.src.startswith(("platform/plasma/color-schemes/", "platform/cursor/")),
                            e.src)

    def test_svg_contracts_are_filled(self):
        # Boş bir yeniden tanım SVG kimlik denetimlerini sessizce kapatır
        self.assertGreater(len(manifest.SVG_CONTRACTS), 20)

    def test_destinations_are_unique(self):
        dests = [e.dest for e in manifest.INSTALL]
        self.assertEqual(len(dests), len(set(dests)))


class CliTest(unittest.TestCase):
    def test_every_command_has_a_handler(self):
        from rotheme.cli import build_parser
        sub = next(a for a in build_parser()._actions if a.dest == "command")
        for name, parser in sub.choices.items():
            self.assertTrue(callable(parser.get_default("func")), name)

    def test_generate_list_runs(self):
        self.assertEqual(main(["generate", "--list"]), 0)


if __name__ == "__main__":
    unittest.main()
