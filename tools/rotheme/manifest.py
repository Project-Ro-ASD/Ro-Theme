"""Tek doğruluk kaynağı: paket kimliği, kurulum eşlemesi, /etc/xdg anahtarları, panel ve applet listeleri.

Üreteç, denetim, kurulum, tanı ve sıfırlama araçları yolları ve anahtar adlarını buradan okur;
bu bilgiler başka bir dosyada tekrar yazılmaz.
"""
from __future__ import annotations

from dataclasses import dataclass

# --- Paket kimliği ---
PACKAGE = "ro-theme"
FEDORA_RELEASE = 44
LICENSE = "GPL-3.0-or-later AND CC-BY-SA-4.0 AND OFL-1.1"
URL = "https://github.com/Project-Ro-ASD/Ro-Theme"
VENDOR = "Project Ro-ASD"

THEMES = {
    # tema -> (renk şeması / Plasma stili / Aurorae adı, global tema kimliği, görünen ad, Türkçe ad)
    "light": ("RoLight", "org.ro.light", "Ro Light", "Ro Açık"),
    "dark": ("RoDark", "org.ro.dark", "Ro Dark", "Ro Koyu"),
}
DEFAULT_THEME = "dark"
LAYOUT_TEMPLATE = "org.ro.desktop"
AURORAE_LIBRARY = "org.kde.kwin.aurorae.v2"
ICON_THEME = {"light": "ro-icons-light", "dark": "ro-icons"}
CURSOR_THEME = "breeze_cursors"
PLYMOUTH_THEME = "ro-theme"
KWIN_EFFECT = "ro-login-reveal"
STAMP_DIR = "/var/lib/ro-theme"


def aurorae_theme(theme: str) -> str:
    return f"__aurorae__svg__{THEMES[theme][0]}"


# --- Kurulum eşlemesi ---
# Hedeflerde kullanılabilen kökler; --destdir bunların önüne eklenir, --local kullanıcı köklerine çevirir.
DIRS = {
    "datadir": "/usr/share",
    "sysconfdir": "/etc",
    "bindir": "/usr/bin",
    "libexecdir": "/usr/libexec",
    "libdir": "/usr/lib64",          # Firefox tercihleri x86_64'te yalnız buradan okunur
    "prefix": "/usr",
    "localstatedir": "/var",
}


@dataclass(frozen=True)
class Entry:
    src: str                 # depo köküne göre yol (dizinse ağaç olarak kopyalanır)
    dest: str                # {datadir} gibi köklerle hedef
    mode: int = 0o644        # dosyalar için; dizinler 0755
    config: bool = False     # RPM %config(noreplace)
    local: bool = True       # --local (kullanıcı) kurulumunda da yer alır mı
    rename: bool = False     # tek dosya, hedef adı farklı


INSTALL: tuple[Entry, ...] = (
    Entry("platform/plasma/color-schemes/RoLight.colors", "{datadir}/color-schemes/RoLight.colors"),
    Entry("platform/plasma/color-schemes/RoDark.colors", "{datadir}/color-schemes/RoDark.colors"),
    Entry("platform/plasma/desktoptheme/RoLight", "{datadir}/plasma/desktoptheme/RoLight"),
    Entry("platform/plasma/desktoptheme/RoDark", "{datadir}/plasma/desktoptheme/RoDark"),
    Entry("platform/plasma/look-and-feel/org.ro.light", "{datadir}/plasma/look-and-feel/org.ro.light"),
    Entry("platform/plasma/look-and-feel/org.ro.dark", "{datadir}/plasma/look-and-feel/org.ro.dark"),
    Entry("platform/plasma/layout-templates/org.ro.desktop", "{datadir}/plasma/layout-templates/org.ro.desktop"),
    Entry("dist/qml/RoTokens.qml", "{datadir}/ro-theme/qml/RoTokens.qml"),
    Entry("assets/wallpapers/light.jpg", "{datadir}/ro-theme/wallpapers/light.jpg"),
    Entry("assets/wallpapers/dark.jpg", "{datadir}/ro-theme/wallpapers/dark.jpg"),
    Entry("assets/wallpapers/loginv2.jpg", "{datadir}/ro-theme/wallpapers/login.jpg", rename=True, local=False),
    Entry("assets/wallpapers/RoLight", "{datadir}/wallpapers/RoLight"),
    Entry("assets/wallpapers/RoDark", "{datadir}/wallpapers/RoDark"),
    Entry("platform/kwin/aurorae/RoLight", "{datadir}/aurorae/themes/RoLight"),
    Entry("platform/kwin/aurorae/RoDark", "{datadir}/aurorae/themes/RoDark"),
    Entry("platform/kwin/effects/ro-login-reveal", "{datadir}/kwin/effects/ro-login-reveal"),
    Entry("platform/icons/ro-icons", "{datadir}/icons/ro-icons"),
    Entry("platform/cursor/ro-cursor", "{datadir}/icons/ro-cursor"),
    Entry("platform/firefox/ro-theme.js", "{libdir}/firefox/defaults/pref/ro-theme.js", local=False),
    Entry("platform/grub/ro", "{datadir}/grub/themes/ro", local=False),
    Entry("platform/plymouth/ro-theme", "{datadir}/plymouth/themes/ro-theme", local=False),
    Entry("platform/plasmalogin/20-ro-theme.conf", "{prefix}/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf",
          local=False),
    Entry("scripts/ro-grub-theme.sh", "{bindir}/ro-grub-theme", mode=0o755, rename=True, local=False),
    # Kurulu araçların kullandığı Python paketi (bin/ sarmalayıcıları buradan import eder)
    Entry("tools/rotheme", "{datadir}/ro-theme/lib/rotheme", local=False),
    Entry("tools/rotheme/bin/ro-theme-diagnose", "{bindir}/ro-theme-diagnose", mode=0o755, local=False),
    Entry("tools/rotheme/bin/apply-dark-defaults", "{libexecdir}/ro-theme/apply-dark-defaults", mode=0o755,
          local=False),
    Entry("tools/rotheme/bin/check-plasma-runtime", "{libexecdir}/ro-theme/check-plasma-runtime", mode=0o755,
          local=False),
    *(Entry(f"platform/plasma/defaults/xdg/{name}", f"{{sysconfdir}}/xdg/{name}", config=True, local=False)
      for name in ("kdeglobals", "kcmfonts", "breezerc", "plasmarc", "ksplashrc", "kscreenlockerrc", "kwinrc")),
)

# Kurulumda sentezlenen açık simge teması: ro-icons'a göreli bağlar + değiştirilmiş index.theme
LIGHT_ICONS = {
    "dest": "{datadir}/icons/ro-icons-light",
    "base": "ro-icons",
    "name": "Ro Icons (Light)",
    "inherits": "Papirus-Light",
}

# Kurulumdan sonra aynı içerikli görselleri hardlink'le birleştirilecek ağaçlar
HARDLINK_TREES = ("{datadir}/wallpapers", "{datadir}/ro-theme/wallpapers", "{datadir}/plasma/look-and-feel")

LICENSE_FILES = ("LICENSE", "LICENSES/CC-BY-SA-4.0.txt", "LICENSES/ASSETS.md")
DOC_FILES = ("README.md",)

# --- /etc/xdg: dosyalar ve sıfırlama aracının kullanıcıdan sileceği anahtarlar ---
XDG_FILES = ("kdeglobals", "kcmfonts", "breezerc", "plasmarc", "ksplashrc", "kscreenlockerrc", "kwinrc")

# Eski sürümlerden kalan, sıfırlamada ayrıca silinen anahtarlar: dosya -> grup -> anahtarlar
LEGACY_KEYS = {
    "kdeglobals": {"[KDE]": ("ColorScheme",)},
    "kwinrc": {"[Plugins]": tuple(f"kwin4_effect_{e}Enabled" for e in
                                  ("scale", "glide", "squash", "magiclamp", "windowaperture", "frozenapp"))
                            + ("ro-smooth-motionEnabled",)},
}
LEGACY_MARKER = "ro-theme/default-dark-applied"      # ~/.config altına göre
BACKUP_DIR = "ro-theme"                             # ~/.config/ro-theme/backup-<tarih>-<rastgele>

# --- Panel düzeni ---
PANEL = {
    "location": "bottom",
    "hiding": "none",
    "floating": True,
    "launcher": ("org.ro.launcher", "org.kde.plasma.kickoff"),   # ilki varsa o, yoksa ikincisi
    "launcher_icon": "start-here",
    "task_launchers": ("org.kde.dolphin.desktop", "org.kde.konsole.desktop",
                       "org.mozilla.firefox.desktop", "systemsettings.desktop"),
    "tray_items": ("org.kde.plasma.networkmanagement", "org.kde.plasma.bluetooth", "org.kde.plasma.volume",
                   "org.kde.plasma.notifications", "org.kde.plasma.battery"),
}

# --- check-plasma-runtime ---
RUNTIME_APPLETS = {
    "layout": {"required": ("org.kde.plasma.kickoff", "org.kde.plasma.panelspacer", "org.kde.plasma.digitalclock",
                            "org.kde.plasma.systemtray", "org.kde.plasma.icontasks"),
               "optional": ()},
    "popups": {"required": ("org.kde.plasma.systemtray",),
               "optional": ("org.kde.plasma.battery", "org.kde.plasma.brightness")},
}

# --- Masaüstü teması SVG sözleşmeleri (G1 dolduracak: dosya -> zorunlu element kimlikleri) ---
SVG_CONTRACTS: dict[str, tuple[str, ...]] = {}
