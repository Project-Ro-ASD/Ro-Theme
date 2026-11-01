"""Sistem geneli `/etc/xdg` KDE varsayılanları (gereksinimler/10 §6.4)."""
from __future__ import annotations

from .. import manifest
from ..kconfig import KConfig
from ..tokens import font_string
from .colors import scheme

HEADER = [
    "# Ro-ASD system defaults. Generated from core/tokens by scripts/generate-theme.sh.",
    "# Packaged as %config(noreplace); user settings in ~/.config always take precedence.",
]


def _kdeglobals(t) -> KConfig:
    cfg = scheme(t, "dark")
    c, fonts = t.dark, t.fonts
    cfg.groups["[General]"] = {
        "ColorScheme": manifest.THEMES["dark"][0],
        "shadeSortColumn": "true",
        "accentActiveTitlebar": "false",
        "accentInactiveTitlebar": "false",
        "XftAntialias": "true" if fonts.rendering.antialias else "false",
        "XftHintStyle": fonts.rendering.hintStyle,
        "XftSubPixel": fonts.rendering.subPixel,
    }
    cfg.groups["[KDE]"] = {
        "contrast": "4",
        "LookAndFeelPackage": manifest.THEMES["dark"][1],
        "DefaultLightLookAndFeel": manifest.THEMES["light"][1],
        "DefaultDarkLookAndFeel": manifest.THEMES["dark"][1],
        "widgetStyle": "Ro",
        "ShowIconsOnPushButtons": "false",
    }
    cfg.groups["[WM]"]["activeFont"] = font_string(fonts.windowTitle)
    cfg.groups["[Icons]"] = {"Theme": manifest.ICON_THEME["dark"]}
    cfg.groups["[Toolbar style]"] = {"ToolButtonStyleOtherToolbars": "IconOnly"}
    return cfg


def _simple(groups: dict[str, dict[str, str]]) -> KConfig:
    cfg = KConfig(header=list(HEADER))
    for name, keys in groups.items():
        cfg.groups[name] = dict(keys)
    return cfg


def outputs(ctx) -> dict[str, str]:
    t = ctx.tokens
    lock = f"file://{manifest.DIRS['datadir']}/plasma/look-and-feel/{manifest.THEMES['dark'][1]}/contents/lockscreen/assets/login.jpg"
    files = {
        "kdeglobals": _kdeglobals(t),
        "kcmfonts": _simple({"[General]": {"forceFontDPI": str(t.fonts.forceFontDPI)}}),
        "breezerc": _simple({"[Style]": {
            "ToolBarDrawItemSeparator": "false",
            "ViewDrawTreeBranchLines": "false",
            "SliderDrawTickMarks": "false",
            "AnimationsDuration": str(t.motion.fastMs),
            "MenuOpacity": "60",
        }}),
        "plasmarc": _simple({"[Theme]": {"name": manifest.THEMES["dark"][0]}}),
        "ksplashrc": _simple({"[KSplash]": {"Engine": "KSplashQML", "Theme": manifest.THEMES["dark"][1]}}),
        "kscreenlockerrc": _simple({
            "[Greeter]": {"WallpaperPlugin": "org.kde.image"},
            "[Greeter][Wallpaper][org.kde.image][General]": {
                "Image": lock, "PreviewImage": lock, "Blur": "false"},
        }),
        "kwinrc": _simple({
            "[org.kde.kdecoration2]": {
                "library": manifest.AURORAE_LIBRARY,
                "theme": manifest.aurorae_theme("dark"),
                "ButtonsOnLeft": "M",
                "ButtonsOnRight": "IAX",
            },
            "[Plugins]": {f"{manifest.KWIN_EFFECT}Enabled": "true"},
        }),
    }
    for name, cfg in files.items():
        if name != "kdeglobals":
            cfg.header = list(HEADER)
    return {f"platform/plasma/defaults/xdg/{name}": cfg.dump() for name, cfg in files.items()}
