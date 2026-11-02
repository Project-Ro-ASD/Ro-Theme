"""Panel düzeni betikleri ve şablon üstverisi (gereksinimler/13 §4)."""
from __future__ import annotations

import json

from .. import manifest

HEADER = "// Ro panel düzeni — otomatik üretilir (core/tokens + manifest.PANEL); elle düzenlenmez.\n"

SAFE_ADD = """function safeAdd(panel, id) {
    try {
        return panel.addWidget(id);
    } catch (e) {
        print("Ro layout: could not add " + id + ": " + e);
        return null;
    }
}
"""


def _panel(t) -> str:
    p = manifest.PANEL
    launcher, fallback = p["launcher"]
    tasks = ",".join(f"applications:{d}" for d in p["task_launchers"])
    tray = ",".join(p["tray_items"])
    clock = t.fonts.panelClock
    height = t.spacing.panelHeight
    peek, peek_icon = p["peek"], p["peek_icon"]
    return f"""
var bar = new Panel();
bar.location = "{p['location']}";
bar.height = {height};
bar.hiding = "{p['hiding']}";
try {{ bar.floating = {str(p['floating']).lower()}; }} catch (e) {{}}

var launcherId = knownWidgetTypes.indexOf("{launcher}") !== -1 ? "{launcher}" : "{fallback}";
var launcher = safeAdd(bar, launcherId);
if (!launcher) {{
    launcher = safeAdd(bar, "{fallback}");
}}
if (launcher && launcher.type !== "{launcher}") {{
    launcher.currentConfigGroup = ["General"];
    launcher.writeConfig("icon", "{p['launcher_icon']}");
}}

safeAdd(bar, "org.kde.plasma.panelspacer");

var tasks = safeAdd(bar, "org.kde.plasma.icontasks");
if (tasks) {{
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", "{tasks}");
    tasks.writeConfig("showOnlyCurrentScreen", "true");
    tasks.writeConfig("showOnlyCurrentDesktop", "false");
    tasks.writeConfig("groupingStrategy", "1");
    tasks.writeConfig("sortingStrategy", "1");
    tasks.writeConfig("highlightWindows", "true");
}}

safeAdd(bar, "org.kde.plasma.panelspacer");

var tray = safeAdd(bar, "org.kde.plasma.systemtray");
if (tray) {{
    tray.currentConfigGroup = ["General"];
    tray.writeConfig("shownItems", "{tray}");
    tray.writeConfig("reverseIconOrder", "true");
    tray.writeConfig("scaleIconsToFit", "false");
}}

var clock = safeAdd(bar, "org.kde.plasma.digitalclock");
if (clock) {{
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", "false");
    clock.writeConfig("showSeconds", "false");
    clock.writeConfig("autoFontAndSize", "false");
    clock.writeConfig("fontFamily", "{clock.family} {clock.styleName}");
    clock.writeConfig("fontSize", "{clock.pointSize}");
}}

// Masaüstüne göz at: saatin sağında. Simgesi açıkça verilir; ro-icons'taki klasör biçimli
// user-desktop simgesine düşmesin diye Papirus'un show-desktop simgesi kullanılır.
var peek = safeAdd(bar, "{peek}");
if (peek) {{
    peek.currentConfigGroup = ["General"];
    peek.writeConfig("icon", "{peek_icon}");
}}
"""


def _desktop(theme: str) -> str:
    style = manifest.THEMES[theme][0]
    return f"""
var wallpaperPath = "/usr/share/wallpapers/{style}";
var userWallpaperPath = userDataPath("data") + "/wallpapers/{style}";
if (!fileExists(wallpaperPath) && fileExists(userWallpaperPath)) {{
    wallpaperPath = userWallpaperPath;
}}

var ds = desktops();
for (var i = 0; i < ds.length; i++) {{
    var d = ds[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://" + wallpaperPath);
    d.writeConfig("FillMode", "2");
}}

var ps = panels();
for (var j = 0; j < ps.length; j++) {{
    ps[j].remove();
}}
"""


def _script(t, theme: str | None) -> str:
    body = _desktop(theme) if theme else ""
    return HEADER + SAFE_ADD + body + _panel(t)


def outputs(ctx) -> dict[str, str]:
    t = ctx.tokens
    out = {f"platform/plasma/layout-templates/{manifest.LAYOUT_TEMPLATE}/contents/layout.js": _script(t, None)}
    for theme in ("light", "dark"):
        style, look, _, _ = manifest.THEMES[theme]
        out[f"platform/plasma/look-and-feel/{look}/contents/layouts/org.kde.plasma.desktop-layout.js"] = \
            _script(t, theme)
    out[f"platform/plasma/layout-templates/{manifest.LAYOUT_TEMPLATE}/metadata.json"] = json.dumps({
        "KPlugin": {
            "Authors": [{"Name": manifest.VENDOR}],
            "Category": "Plasma Desktop Panel",
            "Description": "Ro Desktop floating bottom panel layout",
            "Description[tr]": "Ro masaüstü yüzen alt panel düzeni",
            "EnabledByDefault": True,
            "Id": manifest.LAYOUT_TEMPLATE,
            "License": "GPL-3.0-or-later",
            "Name": "Ro Desktop Panel",
            "Name[tr]": "Ro Masaüstü Paneli",
            "Version": t.version,
            "Website": manifest.URL,
        },
        "KPackageStructure": "Plasma/LayoutTemplate",
        "X-Plasma-ContainmentCategories": ["panel"],
        "X-Plasma-Shell": "plasmashell",
    }, indent=2, ensure_ascii=False) + "\n"
    return out
