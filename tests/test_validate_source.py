"""Kaynak ağacı denetimlerinin geçen ve kalan senaryoları."""
from __future__ import annotations

import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tests.helpers import ROOT
from rotheme import manifest
from rotheme.kconfig import KConfig
from rotheme import tokens as tok
from rotheme.validate import Context, REGISTRY, run_checks

TOKEN_FILES = ("colors.light.json", "colors.dark.json", "radius.json", "spacing.json",
               "opacity.json", "motion.json", "fonts.json")
ROOT_FILES = ("README.md", "LICENSE", "packaging/ro-theme.spec", "assets/README.md",
              "docs/release-build.md", "packaging/README.md", "platform/README.md",
              "platform/plasma/README.md", "tools/README.md")


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_bytes(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def copy(root: Path, rel: str):
    write_bytes(root / rel, (ROOT / rel).read_bytes())


def rgb(value: str) -> str:
    h = value.lstrip("#")
    return f"{int(h[0:2], 16)},{int(h[2:4], 16)},{int(h[4:6], 16)}"


def scheme(mode: str) -> str:
    theme = manifest.THEMES[mode][0]
    cfg = KConfig()
    cfg.update("[General]", {"Name": manifest.THEMES[mode][2], "ColorScheme": theme})
    cfg.update("[ColorEffects:Inactive]", {"ChangeSelectionColor": False})
    cfg.update("[KDE]", {"ColorScheme": theme, "contrast": 4})

    def colors(group, background, alternate, foreground):
        cfg.update(group, {
            "BackgroundNormal": rgb(background), "BackgroundAlternate": rgb(alternate),
            **{key: rgb(foreground) for key in ("ForegroundNormal", "ForegroundInactive", "ForegroundActive",
                                                "ForegroundLink", "ForegroundVisited", "ForegroundNegative",
                                                "ForegroundNeutral", "ForegroundPositive")},
            "DecorationFocus": rgb(foreground), "DecorationHover": rgb(foreground),
        })

    colors("[Colors:Window]", "#FFFFFF", "#F0F0F0", "#000000")
    colors("[Colors:View]", "#FFFFFF", "#C8C8C8", "#000000")
    colors("[Colors:Button]", "#F0F0F0", "#FFFFFF", "#000000")
    colors("[Colors:Tooltip]", "#FFFFFF", "#F0F0F0", "#000000")
    colors("[Colors:Header]", "#FFFFFF", "#F0F0F0", "#000000")
    colors("[Colors:Header][Inactive]", "#FFFFFF", "#F0F0F0", "#000000")
    colors("[Colors:Complementary]", "#2B2D2F", "#37393C", "#FFFFFF")
    colors("[Colors:Selection]", "#FFFFFF", "#F0F0F0", "#000000")
    return cfg.dump()


def defaults(mode: str, fonts) -> str:
    theme = manifest.THEMES[mode][0]
    look = manifest.THEMES[mode][1]
    cfg = KConfig()
    cfg.update("[ksplashrc][KSplash]", {"Engine": "KSplashQML", "Theme": look})
    cfg.update("[kdeglobals][General]", {
        "ColorScheme": theme,
        "font": tok.font_string(fonts["general"]),
        "fixed": tok.font_string(fonts["fixed"]),
        "smallestReadableFont": tok.font_string(fonts["small"]),
        "toolBarFont": tok.font_string(fonts["toolbar"]),
        "menuFont": tok.font_string(fonts["menu"]),
        "XftAntialias": "true", "XftHintStyle": "hintslight", "XftSubPixel": "rgb",
    })
    cfg.update("[kdeglobals][KDE]", {"contrast": 4})
    cfg.update("[kwinrc][org.kde.kdecoration2]",
               {"library": manifest.AURORAE_LIBRARY, "theme": manifest.aurorae_theme(mode)})
    return cfg.dump()


def xdg(fonts) -> dict[str, str]:
    active = tok.font_string(fonts["windowTitle"])
    image = "file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
    return {
        "kdeglobals": KConfig.parse(
            "[General]\nXftAntialias=true\nXftHintStyle=hintslight\nXftSubPixel=rgb\n\n"
            f"[WM]\nactiveFont={active}\n\n[KDE]\nShowIconsOnPushButtons=false\n").dump(),
        "kcmfonts": "[General]\nforceFontDPI=0\n",
        "breezerc": "[Style]\nViewDrawTreeBranchLines=false\nMenuOpacity=60\n",
        "plasmarc": "[Theme]\nname=RoDark\n",
        "ksplashrc": "[KSplash]\nEngine=KSplashQML\nTheme=org.ro.dark\n",
        "kscreenlockerrc": ("[Greeter]\nWallpaperPlugin=org.kde.image\n\n"
                            "[Greeter][Wallpaper][org.kde.image][General]\n"
                            f"Image={image}\nPreviewImage={image}\nBlur=false\n"),
        "kwinrc": ("[org.kde.kdecoration2]\n"
                   f"library={manifest.AURORAE_LIBRARY}\ntheme=__aurorae__svg__RoDark\n"
                   "ButtonsOnLeft=M\nButtonsOnRight=IAX\n\n[Plugins]\nro-login-revealEnabled=true\n"),
    }


def frame_svg(glass: bool) -> str:
    opacity = "0.85" if glass else "1.0"
    parts = []
    for part in ("topright", "bottomleft", "bottomright", "top", "bottom", "left", "right"):
        parts.append(f'<g id="{part}"><rect x="0" y="0" width="8" height="8" fill="#FFFFFF"/></g>')
    shadows = "".join(
        f'<g id="shadow-{part}"><rect x="0" y="0" width="8" height="8" fill="#000000"/></g>'
        for part in ("topleft", "topright", "bottomleft", "bottomright", "top", "bottom", "left", "right"))
    hints = "".join(f'<rect id="hint-{side}-margin" x="0" y="0" width="1" height="1" fill-opacity="0"/>'
                    for side in ("top", "bottom", "left", "right"))
    shadow_hints = "".join(
        f'<rect id="shadow-hint-{side}-margin" x="0" y="0" width="1" height="1" fill-opacity="0"/>'
        for side in ("top", "bottom", "left", "right"))
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
        '<defs><radialGradient id="g"><stop offset="0" stop-opacity="0"/></radialGradient></defs>\n'
        '<g id="topleft"><path d="M 16,0 A 16,16 0 0 1 0,16 L 0,0 Z" fill="#FFFFFF"/></g>\n'
        + "\n".join(parts) + "\n"
        f'<g id="center"><rect x="16" y="16" width="32" height="32" fill="#FFFFFF" fill-opacity="{opacity}"/></g>\n'
        + hints + "\n" + '<rect id="hint-stretch-borders" width="1" height="1" fill-opacity="0"/>\n'
        + shadows + "\n" + shadow_hints + "\n</svg>\n"
    )


def build_source(root: Path):
    for rel in ROOT_FILES:
        write(root / rel, "")
    write(root / "VERSION", (ROOT / "VERSION").read_text(encoding="utf-8"))
    write(root / "LICENSES/CC-BY-SA-4.0.txt", "")
    write(root / "LICENSES/ASSETS.md", "")
    for name in TOKEN_FILES:
        copy(root, f"core/tokens/{name}")
    copy(root, "dist/qml/RoTokens.qml")

    fonts = tok.load(ROOT).fonts
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        write(root / manifest.COLOR_SCHEMES / f"{theme}.colors", scheme(mode))
        theme_dir = root / manifest.theme_dir(mode)
        write(theme_dir / "metadata.json", json.dumps({
            "KPlugin": {"Id": theme, "Version": (ROOT / "VERSION").read_text().strip(),
                        "License": "GPL-3.0-or-later"}}, indent=2) + "\n")
        write(theme_dir / "plasmarc", "[ContrastEffect]\nenabled=true\n\n[AdaptiveTransparency]\nenabled=true\n")
        for rel in manifest.SVG_CONTRACTS:
            source = ROOT / manifest.theme_dir(mode) / rel
            if source.is_file():
                write_bytes(theme_dir / rel, source.read_bytes())
            else:
                glass = rel in ("dialogs/background.svg", "widgets/panel-background.svg", "widgets/background.svg")
                write(theme_dir / rel, frame_svg(glass))
        button = theme_dir / "widgets/button.svg"
        text = button.read_text(encoding="utf-8")
        text = re.sub(r'(<g id="toolbutton-focus-center">\s*)(</g>)',
                      r'\1<rect width="32" height="32" fill-opacity="0"/>\n  \2', text)
        button.write_text(text, encoding="utf-8")

    shutil.copytree(ROOT / "platform/kwin/aurorae", root / "platform/kwin/aurorae")
    shutil.copytree(ROOT / "platform/kwin/effects/ro-login-reveal",
                    root / "platform/kwin/effects/ro-login-reveal")
    shutil.copytree(ROOT / "platform/grub/ro", root / manifest.GRUB_DIR)
    copy(root, manifest.FIREFOX_FILE)

    for mode in ("light", "dark"):
        look = root / manifest.look_dir(mode)
        for rel in ("contents/defaults", "contents/splash/login.jpg", "contents/splash/wallpaper-blur.jpg",
                    "contents/lockscreen/assets/login.jpg", "contents/previews/preview.png",
                    "contents/previews/fullscreenpreview.jpg"):
            write_bytes(look / rel, b"")
        write(look / "contents/defaults", defaults(mode, fonts))
        write(look / "metadata.json", json.dumps({"Name[tr]": manifest.THEMES[mode][3]}, indent=2) + "\n")
        write(look / "contents/splash/Splash.qml", "Item { property int stage: 1 }\n")
        write(look / "contents/layouts/org.kde.plasma.desktop-layout.js",
              "var bar = {};\nbar.height = 56;\nvar a = 'org.kde.plasma.icontasks';\n"
              "var b = 'reverseIconOrder';\nvar c = 'org.ro.launcher';\nvar d = 'org.kde.plasma.kickoff';\n")
    write(root / manifest.LAYOUT_TEMPLATES / "org.ro.desktop/contents/layout.js",
          "var bar = {};\nbar.height = 56;\nvar a = 'org.kde.plasma.icontasks';\n"
          "var b = 'reverseIconOrder';\n")

    for name, text in xdg(fonts).items():
        write(root / manifest.XDG_DIR / name, text)

    write(root / manifest.PLASMALOGIN_FILE,
          "[Greeter]\nWallpaperPluginId=org.kde.image\n\n"
          "[Greeter][Wallpaper][org.kde.image][General]\n"
          "Image=file:///usr/share/ro-theme/wallpapers/login.jpg\n")
    write_bytes(root / manifest.WALLPAPERS / "loginv2.jpg", b"jpg")

    dark = tok.load(ROOT).dark
    write(root / manifest.PLYMOUTH_DIR / "ro-theme.plymouth",
          "[Plymouth Theme]\nModuleName=two-step\nUseFirmwareBackground=true\n"
          f"BackgroundStartColor=0x{dark['bootBackground'].lstrip('#').lower()}\n"
          f"BackgroundEndColor=0x{dark['bootBackground'].lstrip('#').lower()}\n"
          f"ProgressBarBackgroundColor=0x{dark['surfaceAlt'].lstrip('#').lower()}\n"
          f"ProgressBarForegroundColor=0x{dark['accent'].lstrip('#').lower()}\n")
    for index in range(1, 87):
        write_bytes(root / manifest.PLYMOUTH_DIR / f"throbber-{index:04d}.png",
                    b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + (192).to_bytes(4, "big") * 2)
    for name in ("entry.png", "bullet.png", "lock.png", "capslock.png"):
        write_bytes(root / manifest.PLYMOUTH_DIR / name, b"")

    write(root / manifest.ICONS_DIR / "index.theme",
          "[Icon Theme]\nInherits=Papirus-Dark\nDirectories=actions/16\n\n[actions/16]\nSize=16\n")
    (root / manifest.ICONS_DIR / "actions/16").mkdir(parents=True)
    write(root / manifest.CURSOR_DIR / "index.theme", "[Icon Theme]\nName=Ro Cursor\n")


class SourceChecksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = tempfile.TemporaryDirectory()
        build_source(Path(cls.template.name))

    @classmethod
    def tearDownClass(cls):
        cls.template.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "root"
        shutil.copytree(self.template.name, self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def results(self, check=None, freshness=False):
        return run_checks(Context(self.root, freshness=freshness), check_id=check)

    def assert_fails(self, check):
        results = self.results(check)
        self.assertTrue(any(r.status == "FAIL" for r in results), f"{check}: FAIL bekleniyordu")

    def test_every_source_check_passes(self):
        for item in REGISTRY:
            if item.target != "source" or item.id == "VAL-FRS-01":
                continue
            results = self.results(item.id)
            self.assertTrue(results, item.id)
            self.assertEqual([], [r.message for r in results if r.status != "OK"], item.id)

    def test_freshness_passes_when_outputs_match(self):
        from unittest import mock
        from rotheme import generate
        with mock.patch.object(generate, "collect", return_value={"README.md": (self.root / "README.md").read_bytes()}):
            results = self.results("VAL-FRS-01", freshness=True)
        self.assertEqual(["OK"], [r.status for r in results])

    def test_freshness_fails_when_output_is_stale(self):
        from unittest import mock
        from rotheme import generate
        with mock.patch.object(generate, "collect", return_value={"README.md": b"eski degil\n"}):
            results = self.results("VAL-FRS-01", freshness=True)
        self.assertIn("FAIL", [r.status for r in results])

    def test_project_failure(self):
        (self.root / "README.md").unlink()
        self.assert_fails("VAL-PRJ-01")

    def test_token_failure(self):
        path = self.root / "core/tokens/colors.light.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["brand"]["navy"] = "#000000"
        path.write_text(json.dumps(data), encoding="utf-8")
        self.assert_fails("VAL-TOK-02")

    def test_dist_failure(self):
        (self.root / "dist/qml/RoTokens.qml").unlink()
        self.assert_fails("VAL-DST-01")

    def test_scheme_failure(self):
        path = self.root / manifest.COLOR_SCHEMES / "RoLight.colors"
        path.write_text(path.read_text(encoding="utf-8").replace("ColorScheme=RoLight", "ColorScheme=Yanlis"),
                        encoding="utf-8")
        self.assert_fails("VAL-SCH-01")

    def test_desktoptheme_failure(self):
        (self.root / manifest.theme_dir("light") / "metadata.json").unlink()
        self.assert_fails("VAL-DT-01")

    def test_desktoptheme_legacy_colors_failure(self):
        # RGA-01 C: kaynak ağaçta desktoptheme colors dosyası "eski dosya" olarak FAIL vermeli
        write(self.root / manifest.theme_dir("dark") / "colors", scheme("dark"))
        self.assert_fails("VAL-DT-02")

    def test_svg_failure(self):
        (self.root / manifest.theme_dir("dark") / "widgets/arrows.svg").unlink()
        self.assert_fails("VAL-SVG-07")

    def test_aurorae_failure(self):
        path = self.root / manifest.aurorae_dir("light") / "RoLightrc"
        path.write_text(path.read_text(encoding="utf-8").replace("PaddingTop=32", "PaddingTop=1"),
                        encoding="utf-8")
        self.assert_fails("VAL-AUR-01")

    def test_global_theme_failure(self):
        (self.root / manifest.look_dir("light") / "contents/splash/Splash.qml").unlink()
        self.assert_fails("VAL-GLO-01")

    def test_xdg_failure(self):
        (self.root / manifest.XDG_DIR / "kwinrc").unlink()
        self.assert_fails("VAL-XDG-01")

    def test_plymouth_failure(self):
        path = self.root / manifest.PLYMOUTH_DIR / "ro-theme.plymouth"
        path.write_text(path.read_text(encoding="utf-8").replace("ModuleName=two-step", "ModuleName=yanlis"),
                        encoding="utf-8")
        self.assert_fails("VAL-PLY-02")

    def test_grub_failure(self):
        (self.root / manifest.GRUB_DIR / "bg.jpg").unlink()
        self.assert_fails("VAL-GRB-01")

    def test_assets_failure(self):
        write_bytes(self.root / manifest.ICONS_DIR / "mimetypes/16/text-x-generic.svg", b"<svg/>")
        self.assert_fails("VAL-AST-02")

    def test_freshness_failure(self):
        with mock.patch("rotheme.generate.collect", return_value={"dist/qml/RoTokens.qml": b"farkli"}):
            results = self.results("VAL-FRS-01", freshness=True)
        self.assertTrue(any(r.status == "FAIL" for r in results))


if __name__ == "__main__":
    unittest.main()
