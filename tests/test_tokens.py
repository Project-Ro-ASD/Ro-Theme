import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tests.helpers import ROOT
from rotheme import tokens as tok


class TokenLoadTest(unittest.TestCase):
    def test_repo_tokens_are_valid(self):
        t = tok.load(ROOT)
        self.assertEqual(t.dark.accent, "#7DA2E8")
        self.assertEqual(t.version, (ROOT / "VERSION").read_text().strip())

    def test_missing_key_names_the_file(self):
        t = tok.load(ROOT)
        with self.assertRaisesRegex(tok.TokenError, "spacing.json: 'yok' anahtarı yok"):
            t.spacing["yok"]

    def test_schema_error_stops_loading(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            shutil.copytree(ROOT / "core", root / "core")
            shutil.copy(ROOT / "VERSION", root / "VERSION")
            path = root / "core/tokens/colors.dark.json"
            data = json.loads(path.read_text())
            data["accent"] = "mavi"
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(tok.TokenError, "'accent' #RRGGBB"):
                tok.load(root)


class ConversionTest(unittest.TestCase):
    def test_rgb(self):
        self.assertEqual(tok.rgb("#213966"), "33,57,102")

    def test_mix_rounds_half_to_even(self):
        # 1*0.5 + 2*0.5 = 1.5 -> 2 ; 3*0.5 + 2*0.5 = 2.5 -> 2
        self.assertEqual(tok.mix("#010301", "#020202", 0.5), "#020202")

    def test_num(self):
        self.assertEqual([tok.num(8.0), tok.num(0.5), tok.num(12.345), tok.num(-0.00001)], ["8", "0.5", "12.345", "0"])

    def test_font_string_has_19_fields(self):
        s = tok.font_string({"family": "Noto Sans", "pointSize": 10, "weight": 400, "styleName": "Regular"})
        self.assertEqual(len(s.split(",")), 19)
        self.assertTrue(s.startswith("Noto Sans,10,-1,5,400,"))


if __name__ == "__main__":
    unittest.main()
