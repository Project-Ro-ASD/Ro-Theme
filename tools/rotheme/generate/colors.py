"""Renk şemaları ve Plasma masaüstü teması renk dosyaları (gereksinimler/10 §6.1-6.2)."""
from __future__ import annotations

from .. import manifest
from ..kconfig import KConfig
from ..tokens import Group, Tokens, mix, rgb


def _common(c: Group) -> dict[str, str]:
    return {
        "ForegroundNormal": rgb(c.text),
        "ForegroundInactive": rgb(c.textSecondary),
        "ForegroundActive": rgb(c.accent),
        "ForegroundLink": rgb(c.link),
        "ForegroundVisited": rgb(c.visited),
        "ForegroundNegative": rgb(c.negative),
        "ForegroundNeutral": rgb(c.neutral),
        "ForegroundPositive": rgb(c.positive),
        "DecorationFocus": rgb(c.accent),
        "DecorationHover": rgb(c.accent),
    }


def _colors_group(cfg: KConfig, name: str, background: str, alternate: str, roles: dict[str, str]) -> None:
    cfg.groups[name] = {"BackgroundNormal": background, "BackgroundAlternate": alternate, **roles}


def scheme(t: Tokens, theme: str) -> KConfig:
    """Bir temanın KDE renk şeması (gruplar belgedeki kesin sırada)."""
    c = t.colors(theme)
    dark = t.dark
    cfg = KConfig()

    cfg.groups["[ColorEffects:Disabled]"] = {
        "Color": rgb(c.bg),
        "ColorAmount": "0",
        "ColorEffect": "0",
        "ContrastAmount": "0.65" if theme == "light" else "0.45",
        "ContrastEffect": "1",
        "IntensityAmount": "0.1",
        "IntensityEffect": "2",
    }
    cfg.groups["[ColorEffects:Inactive]"] = {
        "ChangeSelectionColor": "false",
        "Color": rgb(c.textSecondary),
        "ColorAmount": "0.025",
        "ColorEffect": "2",
        "ContrastAmount": "0.1",
        "ContrastEffect": "2",
        "Enable": "false",
        "IntensityAmount": "0",
        "IntensityEffect": "0",
    }
    name, tr_name = manifest.THEMES[theme][2], manifest.THEMES[theme][3]
    cfg.groups["[General]"] = {
        "Name": name,
        "Name[tr]": tr_name,
        "ColorScheme": manifest.THEMES[theme][0],
        "shadeSortColumn": "true",
        "accentActiveTitlebar": "false",
        "accentInactiveTitlebar": "false",
    }

    roles = _common(c)
    _colors_group(cfg, "[Colors:Window]", rgb(c.bg), rgb(c.surfaceAlt), roles)
    _colors_group(cfg, "[Colors:View]", rgb(c.surface), rgb(mix(c.surfaceAlt, c.surface, 0.5)), roles)
    _colors_group(cfg, "[Colors:Button]", rgb(c.surfaceAlt), rgb(c.surface), roles)
    _colors_group(cfg, "[Colors:Tooltip]", rgb(c.surface), rgb(c.surfaceAlt), roles)
    _colors_group(cfg, "[Colors:Header]", rgb(c.bg), rgb(c.surface), roles)
    _colors_group(cfg, "[Colors:Header][Inactive]", rgb(c.bg), rgb(c.surface),
                  {**roles, "ForegroundNormal": rgb(c.textSecondary),
                   "ForegroundInactive": rgb(c.textSecondary)})
    _colors_group(cfg, "[Colors:Complementary]", rgb(dark.surface), rgb(dark.surfaceAlt), _common(dark))

    sel = c.selection
    _colors_group(cfg, "[Colors:Selection]", rgb(c.accent), rgb(c.accentHover), {
        "ForegroundNormal": rgb(c.selectionText),
        "ForegroundInactive": rgb(sel.inactive),
        "ForegroundActive": rgb(c.selectionText),
        "ForegroundLink": rgb(sel.link),
        "ForegroundVisited": rgb(sel.visited),
        "ForegroundNegative": rgb(sel.negative),
        "ForegroundNeutral": rgb(sel.neutral),
        "ForegroundPositive": rgb(sel.positive),
        "DecorationFocus": rgb(c.selectionText),
        "DecorationHover": rgb(c.accentHover),
    })

    cfg.groups["[KDE]"] = {"ColorScheme": manifest.THEMES[theme][0], "contrast": "4"}
    cfg.groups["[WM]"] = {
        "activeBackground": rgb(c.bg),
        "activeForeground": rgb(c.text),
        "inactiveBackground": rgb(c.bg),
        "inactiveForeground": rgb(c.textSecondary),
        "activeBlend": rgb(c.text),
        "inactiveBlend": rgb(c.border),
    }
    return cfg


def _paths(theme: str) -> tuple[str, str]:
    name = manifest.THEMES[theme][0]
    return (f"platform/plasma/color-schemes/{name}.colors",
            f"platform/plasma/desktoptheme/{name}/colors")


def outputs(ctx) -> dict[str, str]:
    out = {}
    for theme in ("light", "dark"):
        text = scheme(ctx.tokens, theme).dump()
        for path in _paths(theme):
            out[path] = text
    return out
