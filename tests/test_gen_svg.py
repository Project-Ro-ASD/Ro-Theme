"""Masaüstü teması SVG'leri ve Aurorae pencere dekorasyonu üreteç testleri."""
from __future__ import annotations

import json
import re
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from tests.helpers import ROOT
from rotheme import manifest, svg
from rotheme import tokens as tok
from rotheme.generate import Context, aurorae, desktoptheme, run


def _ids(root: ET.Element) -> set[str]:
    return {el.attrib["id"] for el in root.iter() if "id" in el.attrib}


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


class DesktopThemeSvgTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tokens = tok.load(ROOT)
        cls.ctx = Context(cls.tokens, ROOT)
        cls.files = desktoptheme.outputs(cls.ctx)

    def test_total_count_and_xml_validity(self):
        self.assertEqual(len(self.files), 58)
        for rel, content in self.files.items():
            self.assertTrue(rel.endswith(".svg"), rel)
            text = content.decode("utf-8") if isinstance(content, bytes) else content
            root = ET.fromstring(text)
            self.assertEqual(_local(root.tag), "svg", rel)
            self.assertNotIn("stroke=", text, rel)
            self.assertNotIn("<stroke", text, rel)

    def test_contracts_and_required_ids(self):
        self.assertEqual(len(manifest.SVG_CONTRACTS), 29)
        for theme_id, _, _, _ in manifest.THEMES.values():
            base = f"platform/plasma/desktoptheme/{theme_id}"
            for rel_svg, req_ids in manifest.SVG_CONTRACTS.items():
                full = f"{base}/{rel_svg}"
                self.assertIn(full, self.files)
                found = _ids(ET.fromstring(str(self.files[full])))
                missing = [i for i in req_ids if i not in found]
                self.assertEqual(missing, [], f"{full}: eksik kimlikler {missing}")

    def test_frame_rules_and_glass_opacity(self):
        glass_str = str(float(self.tokens.opacity.glass))
        solid_str = str(float(self.tokens.opacity.get("solid", 1.0)))
        for theme_id, _, _, _ in manifest.THEMES.values():
            base = f"platform/plasma/desktoptheme/{theme_id}"
            for rel_svg in desktoptheme.FRAME_FILES:
                text = str(self.files[f"{base}/{rel_svg}"])
                root = ET.fromstring(text)
                by_id = {el.attrib["id"]: el for el in root.iter() if "id" in el.attrib}
                self.assertEqual(_local(by_id["center"].tag), "g", rel_svg)
                self.assertEqual(_local(by_id["topleft"].tag), "g", rel_svg)
                self.assertNotIn("ColorScheme-", text, rel_svg)
                for part in ("topleft", "topright", "bottomleft", "bottomright", "top", "bottom", "left", "right"):
                    shapes = [ch for ch in by_id[part] if _local(ch.tag) in ("rect", "path")]
                    self.assertLessEqual(len(shapes), 1, f"{rel_svg}: {part}")
                for corner in ("topleft", "topright", "bottomleft", "bottomright"):
                    self.assertIn(" A ", by_id[corner][0].attrib.get("d", ""), f"{rel_svg}: {corner}")
                expected_op = solid_str if (rel_svg.startswith("solid/") or rel_svg.endswith("tooltip.svg")) else glass_str
                self.assertEqual(by_id["center"][0].attrib.get("fill-opacity"), expected_op, rel_svg)

    def test_controls_and_lineedit_pst22(self):
        for theme_id, _, _, _ in manifest.THEMES.values():
            base = f"platform/plasma/desktoptheme/{theme_id}"
            for name in ("lineedit.svg", "button.svg", "viewitem.svg", "frame.svg"):
                text = str(self.files[f"{base}/widgets/{name}"])
                self.assertIn('id="current-color-scheme"', text)
                self.assertIsNone(re.search(r'fill="#[0-9a-fA-F]+"', text), name)

            le_root = ET.fromstring(str(self.files[f"{base}/widgets/lineedit.svg"]))
            btn_root = ET.fromstring(str(self.files[f"{base}/widgets/button.svg"]))
            le_ids = {el.attrib["id"]: el for el in le_root.iter() if "id" in el.attrib}
            btn_ids = {el.attrib["id"]: el for el in btn_root.iter() if "id" in el.attrib}

            le_arc = re.search(r"A\s+([0-9.]+),([0-9.]+)", le_ids["base-topleft"][0].attrib["d"])
            btn_arc = re.search(r"A\s+([0-9.]+),([0-9.]+)", btn_ids["normal-topleft"][0].attrib["d"])
            self.assertEqual(le_arc.groups(), btn_arc.groups())
            self.assertEqual(float(le_ids["base-hint-top-margin"].attrib["height"]), self.tokens.spacing.fieldPadding)
            self.assertLess(float(le_ids["hover-hint-top-margin"].attrib["height"]), 1.0)
            self.assertLess(float(le_ids["focus-hint-top-margin"].attrib["height"]), 1.0)
            self.assertEqual(float(le_ids["focusframe-hint-top-margin"].attrib["height"]), 2 * self.tokens.spacing.borderWidth)
            for prefix in ("base", "hover", "focus", "focusframe"):
                self.assertGreaterEqual(len(le_ids[f"{prefix}-center"]), 1)

    def test_matches_repo_golden_files(self):
        matched = 0
        for rel, content in self.files.items():
            disk_path = ROOT / rel
            if disk_path.is_file():
                matched += 1
                data = content.encode("utf-8") if isinstance(content, str) else content
                self.assertEqual(disk_path.read_bytes(), data, f"altın dosyayla uyuşmuyor: {rel}")
        self.assertGreaterEqual(matched, 48)


class AuroraeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tokens = tok.load(ROOT)
        cls.ctx = Context(cls.tokens, ROOT)
        cls.files = aurorae.outputs(cls.ctx)

    def test_outputs_and_golden_match(self):
        self.assertEqual(len(self.files), 14)
        for rel, content in self.files.items():
            disk_path = ROOT / rel
            self.assertTrue(disk_path.is_file(), f"eksik altın dosya: {rel}")
            data = content.encode("utf-8") if isinstance(content, str) else content
            self.assertEqual(disk_path.read_bytes(), data, f"altın dosyayla uyuşmuyor: {rel}")

    def test_metadata_and_rc_contracts(self):
        for _, (theme_id, _, _, tr_name) in manifest.THEMES.items():
            base = f"platform/kwin/aurorae/{theme_id}"
            meta = str(self.files[f"{base}/metadata.desktop"])
            self.assertIn(f"X-KDE-PluginInfo-Name={theme_id}", meta)
            self.assertIn(f"X-KDE-PluginInfo-Version={self.tokens.version}", meta)
            self.assertIn(f"Name[tr]={tr_name}", meta)

            rc = str(self.files[f"{base}/{theme_id}rc"])
            self.assertIn("[General]", rc)
            self.assertIn("[Layout]", rc)
            self.assertIn(f"PaddingTop={int(self.tokens.spacing.windowShadow)}", rc)
            self.assertRegex(rc, r"(?m)^TitleEdgeTop=\d+$")
            self.assertNotIn("BorderTop=", rc)
            self.assertNotIn("BorderLeftMaximized", rc)

    def test_decoration_and_buttons_svg(self):
        for theme_id, _, _, _ in manifest.THEMES.values():
            base = f"platform/kwin/aurorae/{theme_id}"
            dec_text = str(self.files[f"{base}/decoration.svg"])
            dec_ids = _ids(ET.fromstring(dec_text))
            for prefix in ("decoration", "decoration-inactive", "decoration-maximized", "decoration-maximized-inactive"):
                for part in svg.PARTS:
                    self.assertIn(f"{prefix}-{part}", dec_ids)
            self.assertIn("ro-decoration-topleft-shadow", dec_ids)
            self.assertIsNone(re.search(r"ro-decoration-maximized[^\"']*shadow", dec_text))

            for kind in ("close", "minimize", "maximize", "restore"):
                btn_text = str(self.files[f"{base}/{kind}.svg"])
                btn_ids = _ids(ET.fromstring(btn_text))
                for state in aurorae.BUTTON_STATES:
                    self.assertIn(state, btn_ids)
                self.assertIn('rx="', btn_text)

    def test_geometry_precondition_guard(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            shutil.copytree(ROOT / "core", root / "core")
            shutil.copy(ROOT / "VERSION", root / "VERSION")
            sp_path = root / "core/tokens/spacing.json"
            data = json.loads(sp_path.read_text(encoding="utf-8"))
            data["windowBorder"] = 1
            sp_path.write_text(json.dumps(data), encoding="utf-8")
            bad_ctx = Context(tok.load(root), root)
            with self.assertRaises(tok.TokenError):
                aurorae.outputs(bad_ctx)
            self.assertEqual(run(root, only=("aurorae",)), 1)


if __name__ == "__main__":
    unittest.main()
