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
    "libdir": "/usr/lib64",
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
    Entry("platform/plasma/shells/org.kde.plasma.desktop/contents/updates/ro-peek-desktop.js",
          "{datadir}/plasma/shells/org.kde.plasma.desktop/contents/updates/ro-peek-desktop.js", local=False),
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
    # Fedora Firefox sistem tercihlerini /etc/firefox/pref altından okur (mimariden bağımsız)
    Entry("platform/firefox/ro-theme.js", "{sysconfdir}/firefox/pref/ro-theme.js", config=True, local=False),
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

# system-preview: yalnız bu üç bileşen sistem önizlemesi olarak kurulur (/etc/xdg'ye dokunulmaz).
PREVIEW_ENTRIES = tuple(e for e in INSTALL if e.src in (
    "assets/wallpapers/loginv2.jpg",
    "platform/plasmalogin/20-ro-theme.conf",
    "platform/plymouth/ro-theme",
))

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

# smoke: canlı oturum denemesinden önce yedeklenen kullanıcı ayarları.
SMOKE_CONFIG_FILES = ("plasma-org.kde.plasma.desktop-appletsrc", *XDG_FILES)

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
    "peek": "org.kde.plasma.showdesktop",          # saatin sağında
    "peek_icon": "show-desktop",
}

# --- check-plasma-runtime ---
RUNTIME_APPLETS = {
    "layout": {"required": ("org.kde.plasma.kickoff", "org.kde.plasma.panelspacer", "org.kde.plasma.digitalclock",
                            "org.kde.plasma.systemtray", "org.kde.plasma.icontasks",
                            "org.kde.plasma.showdesktop"),
               "optional": ()},
    "popups": {"required": ("org.kde.plasma.systemtray",),
               "optional": ("org.kde.plasma.battery", "org.kde.plasma.brightness")},
}

# --- Kaynak ağacı yolları (denetim ve üreteçler buradan okur) ---
TOKEN_DIR = "core/tokens"
COLOR_SCHEMES = "platform/plasma/color-schemes"
DESKTOPTHEME = "platform/plasma/desktoptheme"
LOOKANDFEEL = "platform/plasma/look-and-feel"
LAYOUT_TEMPLATES = "platform/plasma/layout-templates"
XDG_DIR = "platform/plasma/defaults/xdg"
AURORAE_DIR = "platform/kwin/aurorae"
KWIN_EFFECTS_DIR = "platform/kwin/effects"
PLYMOUTH_DIR = "platform/plymouth/ro-theme"
GRUB_DIR = "platform/grub/ro"
ICONS_DIR = "platform/icons/ro-icons"
CURSOR_DIR = "platform/cursor/ro-cursor"
FIREFOX_FILE = "platform/firefox/ro-theme.js"
PLASMALOGIN_FILE = "platform/plasmalogin/20-ro-theme.conf"
WALLPAPERS = "assets/wallpapers"
ASSETS = "assets"
DIST = "dist"


def theme_dir(mode: str) -> str:
    return f"{DESKTOPTHEME}/{THEMES[mode][0]}"


def look_dir(mode: str) -> str:
    return f"{LOOKANDFEEL}/{THEMES[mode][1]}"


def aurorae_dir(mode: str) -> str:
    return f"{AURORAE_DIR}/{THEMES[mode][0]}"


# --- Kurulu ağaçta bulunması zorunlu temel yollar (gereksinimler/01-manifest.md §7) ---
INSTALLED_REQUIRED: tuple[str, ...] = (
    "usr/share/color-schemes/RoLight.colors",
    "usr/share/color-schemes/RoDark.colors",
    "usr/share/plasma/desktoptheme/RoLight/metadata.json",
    "usr/share/plasma/desktoptheme/RoLight/plasmarc",
    "usr/share/plasma/desktoptheme/RoDark/metadata.json",
    "usr/share/plasma/desktoptheme/RoDark/plasmarc",
    "usr/share/plasma/look-and-feel/org.ro.light/metadata.json",
    "usr/share/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js",
    "usr/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg",
    "usr/share/plasma/look-and-feel/org.ro.dark/metadata.json",
    "usr/share/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js",
    "usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg",
    "usr/share/ro-theme/wallpapers/light.jpg",
    "usr/share/ro-theme/wallpapers/dark.jpg",
    "usr/share/ro-theme/wallpapers/login.jpg",
    "usr/share/wallpapers/RoLight/metadata.json",
    "usr/share/wallpapers/RoLight/contents/images/1920x1080.jpg",
    "usr/share/wallpapers/RoLight/contents/images/3840x2160.jpg",
    "usr/share/wallpapers/RoDark/metadata.json",
    "usr/share/wallpapers/RoDark/contents/images/1920x1080.jpg",
    "usr/share/wallpapers/RoDark/contents/images/3840x2160.jpg",
    "usr/share/plymouth/themes/ro-theme/ro-theme.plymouth",
    "usr/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf",
    "usr/bin/ro-theme-diagnose",
    "usr/libexec/ro-theme/apply-dark-defaults",
    "usr/libexec/ro-theme/check-plasma-runtime",
    "usr/share/ro-theme/qml/RoTokens.qml",
    "etc/xdg/kdeglobals",
    "etc/xdg/kcmfonts",
    "etc/xdg/breezerc",
    "etc/xdg/plasmarc",
    "etc/xdg/ksplashrc",
    "etc/xdg/kscreenlockerrc",
    "etc/xdg/kwinrc",
)

# --- Masaüstü teması SVG sözleşmeleri: dosya -> zorunlu element kimlikleri ---
# Kaynak: gereksinimler/11-uretec-svg.md §7-8. Yollar tema dizinine görelidir.
_PARTS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
_HINTS = ("top", "bottom", "left", "right")


def _nine(prefix: str, hints: bool = True) -> tuple[str, ...]:
    ids = [f"{prefix}-{part}" for part in _PARTS]
    if hints:
        ids += [f"{prefix}-hint-{side}-margin" for side in _HINTS]
    return tuple(ids)


def _states(prefixes, hints: bool = True) -> tuple[str, ...]:
    return tuple(i for prefix in prefixes for i in _nine(prefix, hints))


_FRAME_IDS = (
    tuple(_PARTS)
    + tuple(f"hint-{side}-margin" for side in _HINTS)
    + ("hint-stretch-borders",)
    + tuple(f"shadow-{part}" for part in _PARTS if part != "center")
    + tuple(f"shadow-hint-{side}-margin" for side in _HINTS)
)

_FRAME_FILES = (
    "dialogs/background.svg",
    "translucent/dialogs/background.svg",
    "solid/dialogs/background.svg",
    "widgets/background.svg",
    "widgets/translucentbackground.svg",
    "widgets/panel-background.svg",
    "translucent/widgets/panel-background.svg",
    "solid/widgets/panel-background.svg",
    "widgets/tooltip.svg",
    "translucent/widgets/tooltip.svg",
    "solid/widgets/tooltip.svg",
)

_TASKS_IDS = (
    tuple(i for prefix in ("", "north-", "west-", "east-")
          for state in ("normal", "focus", "hover", "minimized", "attention", "progress")
          for i in _nine(f"{prefix}{state}", hints=False))
    + tuple(f"{prefix}normal-hint-{side}-margin" for prefix in ("", "north-", "west-", "east-") for side in _HINTS)
    + tuple(f"group-expander-{side}" for side in ("top", "bottom", "left", "right"))
)

SVG_CONTRACTS: dict[str, tuple[str, ...]] = {
    **{path: _FRAME_IDS for path in _FRAME_FILES},
    "widgets/lineedit.svg": _states(("base", "hover", "focus", "focusframe"))
                             + ("hint-focus-over-base", "hint-tile-center"),
    "widgets/button.svg": _states(("normal", "hover", "pressed", "focus",
                                   "toolbutton-hover", "toolbutton-pressed", "toolbutton-focus", "mask-normal")),
    "widgets/viewitem.svg": _states(("normal", "hover", "selected", "selected+hover")),
    "widgets/scrollbar.svg": _states(("slider", "mouseover-slider",
                                      "background-vertical", "background-horizontal"), hints=False)
                             + ("hint-scrollbar-size",),
    "widgets/checkmarks.svg": ("checkbox", "radiobutton"),
    "widgets/radiobutton.svg": ("hint-size", "normal", "shadow", "checked", "symbol", "hover", "focus"),
    "widgets/switch.svg": _states(("inactive", "active"))
                           + ("hint-bar-size", "handle", "handle-hover", "handle-pressed", "handle-focus",
                              "handle-shadow"),
    "widgets/slider.svg": _states(("groove", "groove-highlight"))
                           + ("hint-handle-size",)
                           + tuple(f"{direction}-slider-{part}" for direction in ("horizontal", "vertical")
                                   for part in ("handle", "hover", "focus", "shadow")),
    "widgets/plasmoidheading.svg": _states(("header", "footer"), hints=False),
    "widgets/tabbar.svg": _states(tuple(f"{side}-active-tab" for side in ("north", "south", "west", "east"))),
    "widgets/busywidget.svg": ("busywidget", "22-22-busywidget", "16-16-busywidget"),
    "widgets/tasks.svg": _TASKS_IDS,
    "widgets/bar_meter_horizontal.svg": _states(("bar-inactive", "bar-active")) + ("hint-bar-size",),
    "widgets/bar_meter_vertical.svg": _states(("bar-inactive", "bar-active")) + ("hint-bar-size",),
    "widgets/line.svg": ("horizontal-line", "vertical-line"),
    "widgets/frame.svg": _states(("plain", "raised", "sunken")),
    "widgets/listitem.svg": _states(("normal", "hover", "pressed", "section")) + ("separator",),
    "widgets/arrows.svg": ("down-arrow", "up-arrow", "left-arrow", "right-arrow"),
}

# Denetimde `stroke` ve hex `fill` yasağı uygulanan kontrol/gösterge dosyaları.
SVG_CONTROL_FILES: tuple[str, ...] = tuple(
    path for path in SVG_CONTRACTS if path.startswith("widgets/") and path not in _FRAME_FILES
)

# --- diagnose: kurulu dosya denetimi ---
# Her iki kurulum modunda da aranan dosyalar (hedefler {kök} ile genişletilir).
REQUIRED_FILES = (
    "{datadir}/color-schemes/RoLight.colors",
    "{datadir}/color-schemes/RoDark.colors",
    "{datadir}/plasma/desktoptheme/RoLight/metadata.json",
    "{datadir}/plasma/desktoptheme/RoLight/plasmarc",
    "{datadir}/plasma/desktoptheme/RoDark/metadata.json",
    "{datadir}/plasma/desktoptheme/RoDark/plasmarc",
    "{datadir}/plasma/look-and-feel/org.ro.light/metadata.json",
    "{datadir}/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js",
    "{datadir}/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg",
    "{datadir}/plasma/look-and-feel/org.ro.dark/metadata.json",
    "{datadir}/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js",
    "{datadir}/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg",
    "{datadir}/ro-theme/wallpapers/light.jpg",
    "{datadir}/ro-theme/wallpapers/dark.jpg",
    "{datadir}/wallpapers/RoLight/metadata.json",
    "{datadir}/wallpapers/RoLight/contents/images/1920x1080.jpg",
    "{datadir}/wallpapers/RoLight/contents/images/3840x2160.jpg",
    "{datadir}/wallpapers/RoDark/metadata.json",
    "{datadir}/wallpapers/RoDark/contents/images/1920x1080.jpg",
    "{datadir}/wallpapers/RoDark/contents/images/3840x2160.jpg",
    "{datadir}/ro-theme/qml/RoTokens.qml",
    "{datadir}/aurorae/themes/RoLight/metadata.desktop",
    "{datadir}/aurorae/themes/RoDark/metadata.desktop",
    "{datadir}/icons/ro-icons/index.theme",
    "{datadir}/icons/ro-icons-light/index.theme",
    "{datadir}/icons/ro-cursor/index.theme",
    "{datadir}/kwin/effects/ro-login-reveal/metadata.json",
)

# Yalnız sistem kurulumunda aranan ek dosyalar.
SYSTEM_FILES = (
    "{datadir}/ro-theme/wallpapers/login.jpg",
    "{datadir}/plymouth/themes/ro-theme/ro-theme.plymouth",
    "{prefix}/lib/plasmalogin/plasmalogin.conf.d/20-ro-theme.conf",
    "{bindir}/ro-theme-diagnose",
    "{libexecdir}/ro-theme/apply-dark-defaults",
    "{libexecdir}/ro-theme/check-plasma-runtime",
    *(f"{{sysconfdir}}/xdg/{name}" for name in XDG_FILES),
)

# Var olmaları güvenlik/bütünlük hatası sayılan yollar.
ABSENT_FILES = (
    "{datadir}/plasma/look-and-feel/org.ro.light/contents/lockscreen/LockScreen.qml",
    "{datadir}/plasma/look-and-feel/org.ro.dark/contents/lockscreen/LockScreen.qml",
    "{datadir}/plasma/desktoptheme/Ro",
    "{datadir}/plasma/look-and-feel/org.ro.global",
    # RGA-01 C: Plasma temaları kendi colors dosyasını taşımaz (sistem şeması ve vurgu rengi kullanılır)
    "{datadir}/plasma/desktoptheme/RoLight/colors",
    "{datadir}/plasma/desktoptheme/RoDark/colors",
)

# diagnose: etkin KDE yapılandırmasında karşılaştırılan anahtarlar (dosya, grup, anahtar).
KDE_KEYS = (
    ("kdeglobals", "[General]", "ColorScheme"),
    ("kdeglobals", "[KDE]", "ColorScheme"),
    ("kdeglobals", "[KDE]", "LookAndFeelPackage"),
    ("plasmarc", "[Theme]", "name"),
    ("ksplashrc", "[KSplash]", "Theme"),
    ("kscreenlockerrc", "[Greeter]", "WallpaperPlugin"),
    ("kscreenlockerrc", "[Greeter][Wallpaper][org.kde.image][General]", "Image"),
    ("kscreenlockerrc", "[Greeter][Wallpaper][org.kde.image][General]", "Blur"),
    ("kwinrc", "[org.kde.kdecoration2]", "library"),
    ("kwinrc", "[org.kde.kdecoration2]", "theme"),
)

# apply: global temanın contents/defaults dosyasından okunup oturuma yazılan anahtarlar.
APPLY_KEYS = (
    ("kdeglobals", "[General]", "ColorScheme"),
    ("kdeglobals", "[KDE]", "LookAndFeelPackage"),
    ("kdeglobals", "[Icons]", "Theme"),
    ("plasmarc", "[Theme]", "name"),
    ("ksplashrc", "[KSplash]", "Theme"),
    ("kscreenlockerrc", "[Greeter]", "WallpaperPlugin"),
    ("kscreenlockerrc", "[Greeter][Wallpaper][org.kde.image][General]", "Image"),
    ("kscreenlockerrc", "[Greeter][Wallpaper][org.kde.image][General]", "PreviewImage"),
    ("kscreenlockerrc", "[Greeter][Wallpaper][org.kde.image][General]", "Blur"),
    ("kwinrc", "[org.kde.kdecoration2]", "library"),
    ("kwinrc", "[org.kde.kdecoration2]", "theme"),
)
# apply ön uçuşunda zorunlu anahtarlar (eksikse oturum değiştirilmez).
APPLY_REQUIRED = (
    ("kdeglobals", "[General]", "ColorScheme"),
    ("kwinrc", "[org.kde.kdecoration2]", "library"),
    ("kwinrc", "[org.kde.kdecoration2]", "theme"),
)
