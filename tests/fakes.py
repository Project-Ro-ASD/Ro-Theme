"""Testler için sahte kaynak ağacı ve sahte PATH araçları."""
from __future__ import annotations

import os
from pathlib import Path

from tests.helpers import ROOT  # noqa: F401  (rotheme'i import yoluna ekler)
from rotheme import manifest

DEFAULTS = """[kdeglobals][General]
ColorScheme={theme}

[kdeglobals][KDE]
LookAndFeelPackage=org.ro.{mode}

[kdeglobals][Icons]
Theme={icons}

[plasmarc][Theme]
name={theme}

[ksplashrc][KSplash]
Theme=org.ro.{mode}

[kscreenlockerrc][Greeter]
WallpaperPlugin=org.kde.image

[kscreenlockerrc][Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/plasma/look-and-feel/org.ro.{mode}/contents/lockscreen/assets/login.jpg
PreviewImage=file:///usr/share/plasma/look-and-feel/org.ro.{mode}/contents/lockscreen/assets/login.jpg
Blur=false

[kwinrc][org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__{theme}
"""

XDG = """[General]
ColorScheme=RoDark

[KDE]
LookAndFeelPackage=org.ro.dark

[Icons]
Theme=ro-icons
"""


def write(path: Path, data: bytes | str = b"x\n", mode: int | None = None) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data, encoding="utf-8")
    else:
        path.write_bytes(data)
    if mode is not None:
        os.chmod(path, mode)
    return path


def make_source(root: Path) -> Path:
    """Manifestteki tüm girdileri karşılayan küçük bir kaynak ağacı üretir."""
    root = Path(root)
    for mode in ("light", "dark"):
        theme = manifest.THEMES[mode][0]
        base = root / "platform/plasma/look-and-feel" / f"org.ro.{mode}"
        write(base / "metadata.json", "{}\n")
        write(base / "contents/defaults",
              DEFAULTS.format(theme=theme, mode=mode, icons=manifest.ICON_THEME[mode]))
        write(base / "contents/layouts/org.kde.plasma.desktop-layout.js", "// düzen\n")
        write(base / "contents/lockscreen/assets/login.jpg", b"login")
        for dtheme in (f"platform/plasma/desktoptheme/{theme}",):
            write(root / dtheme / "metadata.json", "{}\n")
            write(root / dtheme / "plasmarc", "[Theme]\nname=default\n")
            write(root / dtheme / "widgets/background.svg", "<svg/>\n")
        write(root / "platform/plasma/color-schemes" / f"{theme}.colors", "[General]\nName=" + theme + "\n")
        write(root / "platform/kwin/aurorae" / theme / "metadata.desktop", "[Desktop Entry]\nName=" + theme + "\n")
        write(root / "platform/kwin/aurorae" / theme / "decoration.svg", "<svg/>\n")
        wbase = root / "assets/wallpapers" / theme
        write(wbase / "metadata.json", "{}\n")
        write(wbase / "contents/images/1920x1080.jpg", b"ayni-gorsel")
        write(wbase / "contents/images/3840x2160.jpg", b"ayni-gorsel")
    write(root / "assets/wallpapers/light.jpg", b"duvar-light")
    write(root / "assets/wallpapers/dark.jpg", b"duvar-dark")
    write(root / "assets/wallpapers/loginv2.jpg", b"giris")
    write(root / "dist/qml/RoTokens.qml", "pragma Singleton\n")
    write(root / "platform/plasma/layout-templates/org.ro.desktop/contents/layout.js", "// panel\n")
    write(root / "platform/plasma/shells/org.kde.plasma.desktop/contents/updates/ro-peek-desktop.js", "// güncelleme\n")
    write(root / "platform/icons/ro-icons/index.theme",
          "[Icon Theme]\nName=Ro Icons\nInherits=Papirus-Dark\n")
    write(root / "platform/icons/ro-icons/actions/16/a.svg", "<svg/>\n")
    write(root / "platform/icons/ro-icons/places/16/b.svg", "<svg/>\n")
    write(root / "platform/cursor/ro-cursor/index.theme", "[Icon Theme]\nName=Ro Cursor\n")
    write(root / "platform/kwin/effects/ro-login-reveal/metadata.json", "{}\n")
    write(root / "platform/kwin/effects/ro-login-reveal/contents/code/main.js", "//\n")
    write(root / "platform/firefox/ro-theme.js", "//\n")
    write(root / "platform/grub/ro/theme.txt", "title-text: Ro\n")
    write(root / "platform/plymouth/ro-theme/ro-theme.plymouth", "[Plymouth Theme]\nName=Ro\n")
    write(root / "platform/plasmalogin/20-ro-theme.conf", "[Greeter]\nWallpaperPlugin=org.kde.image\n")
    write(root / "scripts/ro-grub-theme.sh", "#!/bin/sh\n", 0o755)
    for name in manifest.XDG_FILES:
        write(root / "platform/plasma/defaults/xdg" / name, XDG)
    write(root / "tools/rotheme/__init__.py", "")
    write(root / "tools/rotheme/manifest.py", "# sahte\n")
    write(root / "tools/rotheme/bin/ro-theme-diagnose", "#!/usr/bin/python3\n", 0o755)
    write(root / "tools/rotheme/bin/apply-dark-defaults", "#!/usr/bin/python3\n", 0o755)
    write(root / "tools/rotheme/bin/check-plasma-runtime", "#!/usr/bin/python3\n", 0o755)
    write(root / "tools/rotheme/__pycache__/x.pyc", b"pyc")
    write(root / "tools/rotheme/tests/test_x.py", "# test\n")
    return root


def tool(bin_dir: Path, name: str, body: str) -> Path:
    return write(bin_dir / name, f"#!/bin/sh\n{body}\n", 0o755)
