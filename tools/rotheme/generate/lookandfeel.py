"""Global tema dosyaları ve masaüstü teması üstverisi (gereksinimler/10 §6.2-6.3)."""
from __future__ import annotations

import json

from .. import manifest
from ..kconfig import KConfig
from ..tokens import font_string


def _json(data: dict) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def _metadata(t, theme: str) -> str:
    name, tr_name = manifest.THEMES[theme][2], manifest.THEMES[theme][3]
    kind = "light" if theme == "light" else "dark"
    return _json({
        "KPlugin": {
            "Id": manifest.THEMES[theme][1],
            "Name": name,
            "Name[tr]": tr_name,
            "Description": f"Ro Desktop {kind} global theme",
            "Description[tr]": f"Ro masaüstü {kind.replace('light', 'açık').replace('dark', 'koyu')} global teması",
            "Icon": "preferences-desktop-theme-global",
            "Version": t.version,
            "License": "GPL-3.0-or-later",
            "Website": manifest.URL,
            "Authors": [{"Name": manifest.VENDOR}],
        },
        "KPackageStructure": "Plasma/LookAndFeel",
    })


def _defaults(t, theme: str) -> str:
    style, look_and_feel, name, _ = manifest.THEMES[theme]
    f = t.fonts
    cfg = KConfig(header=[f"# {name} Global Theme defaults. Font roles generated from core/tokens/fonts.json."])
    cfg.groups["[kdeglobals][KDE]"] = {"widgetStyle": "Ro"}
    cfg.groups["[kdeglobals][General]"] = {
        "ColorScheme": style,
        "font": font_string(f.general),
        "fixed": font_string(f.fixed),
        "smallestReadableFont": font_string(f.small),
        "toolBarFont": font_string(f.toolbar),
        "menuFont": font_string(f.menu),
    }
    cfg.groups["[kdeglobals][WM]"] = {"activeFont": font_string(f.windowTitle)}
    cfg.groups["[kdeglobals][Icons]"] = {"Theme": manifest.ICON_THEME[theme]}
    cfg.groups["[plasmarc][Theme]"] = {"name": style}
    cfg.groups["[kwinrc][org.kde.kdecoration2]"] = {
        "library": manifest.AURORAE_LIBRARY, "theme": manifest.aurorae_theme(theme)}
    cfg.groups["[ksplashrc][KSplash]"] = {"Engine": "KSplashQML", "Theme": look_and_feel}
    cfg.groups["[kcminputrc][Mouse]"] = {"cursorTheme": manifest.CURSOR_THEME}
    cfg.groups["[Wallpaper]"] = {"Image": style}
    return cfg.dump()


def _desktoptheme_metadata(t, theme: str) -> str:
    style, _, name, tr_name = manifest.THEMES[theme]
    kind = "light" if theme == "light" else "dark"
    return _json({
        "KPlugin": {
            "Authors": [{"Name": manifest.VENDOR}],
            "Description": f"Ro Desktop {kind} Plasma theme",
            "Description[tr]": f"Ro masaüstü {kind.replace('light', 'açık').replace('dark', 'koyu')} Plasma teması",
            "EnabledByDefault": True,
            "Id": style,
            "License": "GPL-3.0-or-later",
            "Name": name,
            "Name[tr]": tr_name,
            "Version": t.version,
            "Website": manifest.URL,
        },
        "KPackageStructure": "Plasma/Theme",
        "X-Plasma-API": "5.0",
    })


PLASMARC = KConfig()
PLASMARC.groups["[ContrastEffect]"] = {"enabled": "true", "contrast": "0.35", "saturation": "1.05"}
PLASMARC.groups["[AdaptiveTransparency]"] = {"enabled": "true"}


def outputs(ctx) -> dict[str, str]:
    t = ctx.tokens
    out = {}
    for theme in ("light", "dark"):
        style, look, _, _ = manifest.THEMES[theme]
        base = f"platform/plasma/look-and-feel/{look}"
        out[f"{base}/metadata.json"] = _metadata(t, theme)
        out[f"{base}/contents/defaults"] = _defaults(t, theme)
        desktop = f"platform/plasma/desktoptheme/{style}"
        out[f"{desktop}/metadata.json"] = _desktoptheme_metadata(t, theme)
        out[f"{desktop}/plasmarc"] = PLASMARC.dump()
    return out
