#!/usr/bin/env bash
set -euo pipefail

# Ro tema üretim yardımcısı
# Kaynak değerler core/tokens altındadır. Bu script, tokenlardan tekrar üretilebilen çıktıları yazar.
# Yorumlar Türkçe, kullanıcıya basılan çıktılar İngilizce tutulur.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import json
import re

root = Path('.')

def read_json(path):
    return json.loads((root / path).read_text(encoding='utf-8'))

light = read_json('core/tokens/colors.light.json')
dark = read_json('core/tokens/colors.dark.json')
motion = read_json('core/tokens/motion.json')
radius = read_json('core/tokens/radius.json')
opacity = read_json('core/tokens/opacity.json')
# FX-15 (2026-10-13, G1): cam opaklığının tek kaynağı opacity.glass (popup ve panel, iki temada aynı). Renk
# dosyalarında ayrı alfa tutulmaz; dist çıktılarındaki glass rengi yüzey rengi + bu opaklıktan türetilir.
for _tokens in (light, dark):
    _r, _g, _b = (int(_tokens['surface'].lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
    _tokens['glass'] = f"rgba({_r},{_g},{_b},{opacity['glass']})"
spacing = read_json('core/tokens/spacing.json')
fonts = read_json('core/tokens/fonts.json')

# 07 PAN-01 B (2026-10-13): altta tek bar; başlatıcı solda, ikon görev yöneticisi ortada, tepsi + saat sağda.
# Üç betik (iki global tema, yerleşim şablonu) buradan üretilir (PAN-22, PAN-25); elle düzenlenmez.
PANEL_TRAY_SHOWN = ['org.kde.plasma.networkmanagement', 'org.kde.plasma.bluetooth', 'org.kde.plasma.volume',
                    'org.kde.plasma.notifications', 'org.kde.plasma.battery']
# PAN-18 (ekip, ro-asd-desktop-standard): Fedora'da kurulu olanlar; Plasma 6 Sistem Ayarları adı systemsettings.desktop.
PANEL_LAUNCHERS = ['org.kde.dolphin.desktop', 'org.kde.konsole.desktop', 'org.mozilla.firefox.desktop',
                   'systemsettings.desktop']

def panel_layout_js(mode):
    # mode: 'light' | 'dark' (global tema: panelleri yeniler, duvar kâğıdını seçer) ya da None (şablon: yalnız ekler).
    clock = fonts['panelClock']
    # Plasma 6.7 dijital saati fontWeight'ı yüklemede sıfırlıyor; kalınlık fontconfig'in ağırlıklı aile adıyla verilir.
    clock_family = f"{clock['family']} {clock['styleName']}"
    head = ['// Ro desktop layout. Generated from core/tokens by scripts/generate-theme.sh; do not edit.',
            '// 07 PAN-01 B: single bottom bar; launcher left, icon task manager centred, tray and clock right.',
            '',
            'function safeAdd(panel, pluginId) {',
            '    try { return panel.addWidget(pluginId); } catch (e) { print("Ro layout: could not add " + pluginId + ": " + e); return null; }',
            '}',
            '']
    if mode:
        name = 'Ro' + mode.title()
        head += [f'// PAN-23 A: RPM installs the wallpaper package system-wide; tools/dev/install-local.sh uses the user data dir.',
                 f'var systemWallpaper = "/usr/share/wallpapers/{name}";',
                 f'var userWallpaper = userDataPath("data") + "/wallpapers/{name}";',
                 'var wallpaperPath = fileExists(systemWallpaper) ? systemWallpaper : userWallpaper;',
                 'var ds = desktops();',
                 'for (var i = 0; i < ds.length; i++) {',
                 '    ds[i].wallpaperPlugin = "org.kde.image";',
                 '    ds[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];',
                 '    ds[i].writeConfig("Image", "file://" + wallpaperPath);',
                 '    ds[i].writeConfig("FillMode", 2);',
                 '}',
                 '',
                 '// The global theme layout replaces the panels; the layout template (Add Panel) only adds one.',
                 'var oldPanels = panels();',
                 'for (var i = 0; i < oldPanels.length; i++) { oldPanels[i].remove(); }',
                 '']
    body = ['var bar = new Panel();',
            'bar.location = "bottom";',
            f"bar.height = {spacing['panelHeight']};",
            'bar.hiding = "none";',
            'try { bar.floating = true; } catch (e) {}',
            '',
            '// PAN-08/24, WGT-14: ro-launcher (ro-widgets package) when installed, otherwise Kickoff;',
            '// the bar never stays without a launcher. ro-launcher keeps its own icon (ro-start, the Ro logo',
            '// rings, from ro-widgets); Kickoff gets the distribution logo.',
            'var launcherId = knownWidgetTypes.indexOf("org.ro.launcher") >= 0 ? "org.ro.launcher" : "org.kde.plasma.kickoff";',
            'var launcher = safeAdd(bar, launcherId) || safeAdd(bar, "org.kde.plasma.kickoff");',
            'if (launcher && launcher.type !== "org.ro.launcher") { launcher.currentConfigGroup = ["General"]; launcher.writeConfig("icon", "start-here"); }',
            'safeAdd(bar, "org.kde.plasma.panelspacer");',
            '',
            'var tasks = safeAdd(bar, "org.kde.plasma.icontasks");',
            'if (tasks) {',
            '    tasks.currentConfigGroup = ["General"];',
            '    tasks.writeConfig("launchers", "' + ','.join('applications:' + a for a in PANEL_LAUNCHERS) + '");',
            '    tasks.writeConfig("showOnlyCurrentScreen", true);',
            '    tasks.writeConfig("showOnlyCurrentDesktop", false);',
            '    tasks.writeConfig("groupingStrategy", 1);',
            '    tasks.writeConfig("sortingStrategy", 1);',
            '    tasks.writeConfig("highlightWindows", true);',
            '}',
            'safeAdd(bar, "org.kde.plasma.panelspacer");',
            '',
            '// PAN-10: network, bluetooth, volume, notifications and battery visible; the expander arrow on the left.',
            '// Plasma 6.7 keeps tray settings in the tray applet\'s own [General] group.',
            'var tray = safeAdd(bar, "org.kde.plasma.systemtray");',
            'if (tray) {',
            '    tray.currentConfigGroup = ["General"];',
            '    tray.writeConfig("shownItems", "' + ','.join(PANEL_TRAY_SHOWN) + '");',
            '    tray.writeConfig("reverseIconOrder", true);',
            '    tray.writeConfig("scaleIconsToFit", false);   // PAN-03: tepsi ikonları sabit çerçevede kalır; ölçekli seçenek 56 px panelde tepsiyi görev ikonları kadar (38 px) büyütüp orantıyı bozuyordu',
            '}',
            '',
            f"// PAN-09: time only, {clock['family']} {clock['styleName']} {clock['pointSize']} pt (fonts.panelClock).",
            'var clock = safeAdd(bar, "org.kde.plasma.digitalclock");',
            'if (clock) {',
            '    clock.currentConfigGroup = ["Appearance"];',
            '    clock.writeConfig("showDate", false);',
            '    clock.writeConfig("showSeconds", false);',
            '    clock.writeConfig("autoFontAndSize", false);',
            f'    clock.writeConfig("fontFamily", "{clock_family}");',
            f"    clock.writeConfig(\"fontSize\", {clock['pointSize']});",
            '}']
    return '\n'.join(head + body) + '\n'

for path, mode in [('platform/plasma/layout-templates/org.ro.desktop/contents/layout.js', None),
                   ('platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js', 'light'),
                   ('platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js', 'dark')]:
    (root / path).write_text(panel_layout_js(mode), encoding='utf-8')

for path in [
    'platform/plasma/color-schemes',
    'platform/gtk/Ro-GTK/gtk-3.0',
    'platform/gtk/Ro-GTK/gtk-4.0',
    'platform/plasma/desktoptheme/RoLight',
    'platform/plasma/desktoptheme/RoDark',
    'platform/plasma/look-and-feel/org.ro.light/contents/layouts',
    'platform/plasma/look-and-feel/org.ro.dark/contents/layouts',
    'dist/tokens',
    'dist/qml',
]:
    (root / path).mkdir(parents=True, exist_ok=True)

# --- dist token çıktıları ---
colors_out = {'light': light, 'dark': dark}
(root / 'dist/tokens/ro-colors.json').write_text(
    json.dumps(colors_out, indent=2, ensure_ascii=False) + '\n', encoding='utf-8'
)

css = f''':root,
[data-ro-theme="light"] {{
  --ro-bg: {light['bg']};
  --ro-bg-alt: {light['bgAlt']};
  --ro-surface: {light['surface']};
  --ro-surface-alt: {light['surfaceAlt']};
  --ro-glass: {light['glass']};
  --ro-text: {light['text']};
  --ro-text-secondary: {light['textSecondary']};
  --ro-accent: {light['accent']};
  --ro-border: {light['border']};
  --ro-radius-sm: {radius['sm']}px;
  --ro-radius-md: {radius['md']}px;
  --ro-radius-lg: {radius['lg']}px;
  --ro-radius-xl: {radius['xl']}px;
  --ro-radius-panel: {radius['panel']}px;
  --ro-space-xs: {spacing['xs']}px;
  --ro-space-sm: {spacing['sm']}px;
  --ro-space-md: {spacing['md']}px;
  --ro-space-lg: {spacing['lg']}px;
  --ro-space-xl: {spacing['xl']}px;
  --ro-panel-height: {spacing['panelHeight']}px;
  --ro-opacity-glass: {opacity['glass']};
  --ro-opacity-glass-strong: {opacity['glassStrong']};
  --ro-opacity-hover: {opacity['hover']};
  --ro-opacity-disabled: {opacity['disabled']};
  --ro-motion-window-open: {motion['windowOpenMs']}ms;
  --ro-motion-window-close: {motion['windowCloseMs']}ms;
  --ro-motion-window-minimize: {motion['windowMinimizeMs']}ms;
  --ro-motion-curve: {motion['curve']};
  --ro-motion-scale-from: {motion['scaleFrom']};
  --ro-motion-slide: {motion['slidePx']}px;
}}

[data-ro-theme="dark"] {{
  --ro-bg: {dark['bg']};
  --ro-bg-alt: {dark['bgAlt']};
  --ro-surface: {dark['surface']};
  --ro-surface-alt: {dark['surfaceAlt']};
  --ro-glass: {dark['glass']};
  --ro-text: {dark['text']};
  --ro-text-secondary: {dark['textSecondary']};
  --ro-accent: {dark['accent']};
  --ro-border: {dark['border']};
}}
'''
(root / 'dist/tokens/ro-colors.css').write_text(css, encoding='utf-8')

tailwind = {
    'theme': {
        'extend': {
            'colors': {
                'ro': {
                    'light': light,
                    'dark': dark,
                }
            },
            'borderRadius': radius,
            'spacing': spacing,
            'opacity': opacity,
        }
    }
}
(root / 'dist/tokens/ro-tailwind.js').write_text(
    'module.exports = ' + json.dumps(tailwind, indent=2, ensure_ascii=False) + ';\n',
    encoding='utf-8'
)

# --- QML token modülü (Ro'nun kendi QML widget'ları için; renkler burada YOK, onlar Kirigami.Theme'den gelir) ---
def _qml_name(key):
    return key[0].lower() + key[1:]

def _qml_props(prefix, values, kind='real'):
    lines = []
    for key, value in values.items():
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            lines.append(f'    readonly property {kind} {prefix}{key[0].upper() + key[1:]}: {value}')
    return '\n'.join(lines)

qml_tokens = (
    '// SPDX-FileCopyrightText: Project Ro-ASD\n'
    '// SPDX-License-Identifier: GPL-3.0-or-later\n'
    'pragma Singleton\n'
    'import QtQuick\n\n'
    '// Ro tasarım token\'ları (QML). scripts/generate-theme.sh tarafından core/tokens\'tan ÜRETİLİR, elle düzenlenmez.\n'
    '// WGT-02: ro-theme paketi bu dosyayı /usr/share/ro-theme/qml/RoTokens.qml olarak kurar. ro-widgets derlenirken\n'
    '// oradan alır (elle kopyalama yok, TOK-16); widget qmldir: singleton RoTokens 1.0 RoTokens.qml\n'
    '// Renkler bu dosyada yok: Kirigami.Theme kullan, böylece her renk şemasıyla uyumlu kalır.\n'
    '// Süreler taban değerdir (ms); Plasma animasyon hızı çarpanını (AnimationDurationFactor) uygulamak widget\'ın işidir.\n'
    'QtObject {\n'
    + _qml_props('radius', radius) + '\n'
    + _qml_props('space', {k: v for k, v in spacing.items() if k in ('xs', 'sm', 'md', 'lg', 'xl')}) + '\n'
    + '    readonly property real borderWidth: ' + str(spacing.get('borderWidth', 1)) + '\n'
    + '    readonly property real popupPadding: ' + str(spacing.get('popupPadding', 12)) + '\n'
    + _qml_props('opacity', {k: v for k, v in opacity.items() if k != 'shadow'}) + '\n'
    + _qml_props('motion', {k: v for k, v in motion.items() if isinstance(v, (int, float))}) + '\n'
    '}\n'
)
(root / 'dist/qml/RoTokens.qml').write_text(qml_tokens, encoding='utf-8')

# --- Plasma SVG yüzeyleri ---
def rgba_opacity(value, fallback):
    # rgba(r,g,b,a) içindeki alpha değerini alır. Bulamazsa fallback kullanır.
    if isinstance(value, str) and value.startswith('rgba(') and value.endswith(')'):
        try:
            return str(float(value[:-1].split(',')[-1].strip()))
        except Exception:
            return fallback
    return fallback

def hex_to_rgb(value):
    value = value.strip().lstrip('#')
    if len(value) != 6:
        raise ValueError(f'Unsupported color value: {value}')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))

def rgb(value):
    return ','.join(str(c) for c in hex_to_rgb(value))

def mix_hex(foreground, background, amount):
    fg = hex_to_rgb(foreground)
    bg = hex_to_rgb(background)
    mixed = tuple(round((fg[i] * amount) + (bg[i] * (1 - amount))) for i in range(3))
    return '#{:02X}{:02X}{:02X}'.format(*mixed)

def token_color(tokens, key, fallback):
    value = tokens.get(key, fallback)
    if isinstance(value, str) and value.startswith('#'):
        return value
    return fallback

# [ColorEffects:Inactive] ChangeSelectionColor=false: odak dışındaki seçim de vurgu renginde kalır,
# soluklaşmaz (Ro-Theme-Docs 02 COL-13). true iken KDE seçimi soluk açık maviye çeviriyordu.
SCHEME_NAMES = {'RoLight': ('Ro Light', 'Ro Açık'), 'RoDark': ('Ro Dark', 'Ro Koyu')}

def color_scheme(theme_id, tokens, dark_mode):
    # Set başına rol eşlemesi: Ro-Theme-Docs 02 (COL-14…COL-26). Anlamsal token'lar zorunlu (COL-07): eksikse
    # üretim KeyError ile durur; yedek değer kullanılmaz ("hata = metin rengi" gibi hataları önlemek için).
    t = tokens
    bg, surface, surface_alt = t['bg'], t['surface'], t['surfaceAlt']
    text, text_secondary, accent = t['text'], t['textSecondary'], t['accent']
    # Çizgili satır: iki temada da yüzey ile ikinci yüzeyin yarısı (COL-15f).
    view_alt = mix_hex(surface_alt, surface, 0.5)

    def roles(normal_fg, inactive_fg, src):
        # Ortak ön plan rolleri (COL-14): etkin = vurgu (COL-08), odak = vurgu (COL-10), hover = vurgu (COL-09).
        return {
            'ForegroundNormal': normal_fg, 'ForegroundInactive': inactive_fg,
            'ForegroundActive': src['accent'], 'ForegroundLink': src['link'], 'ForegroundVisited': src['visited'],
            'ForegroundNegative': src['negative'], 'ForegroundNeutral': src['neutral'], 'ForegroundPositive': src['positive'],
            'DecorationFocus': src['accent'], 'DecorationHover': src['accent'],
        }

    def group(name, normal_bg, alternate_bg, fg):
        lines = [f'BackgroundNormal={rgb(normal_bg)}', f'BackgroundAlternate={rgb(alternate_bg)}']
        lines += [f'{k}={rgb(v)}' for k, v in fg.items()]
        return f'[{name}]\n' + '\n'.join(lines) + '\n'

    common = roles(text, text_secondary, t)
    # Seçim seti (COL-17): seçim zemini üstünde her rol >= 4.5; seçili öğede odak seçim metni renginde.
    sel = t['selection']
    selection = {
        'ForegroundNormal': t['selectionText'], 'ForegroundInactive': sel['inactive'],
        'ForegroundActive': t['selectionText'], 'ForegroundLink': sel['link'], 'ForegroundVisited': sel['visited'],
        'ForegroundNegative': sel['negative'], 'ForegroundNeutral': sel['neutral'], 'ForegroundPositive': sel['positive'],
        'DecorationFocus': t['selectionText'], 'DecorationHover': t['accentHover'],
    }
    # Complementary (COL-18): iki temada da koyu temanın yüzeyi ve rolleri (kilit ekranı, OSD).
    d = dark
    complementary = roles(d['text'], d['textSecondary'], d)
    display_name, display_name_tr = SCHEME_NAMES[theme_id]

    return f'''[ColorEffects:Disabled]
Color={rgb(bg)}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Color={rgb(text_secondary)}
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[General]
Name={display_name}
Name[tr]={display_name_tr}
ColorScheme={theme_id}
shadeSortColumn=true
accentActiveTitlebar=false
accentInactiveTitlebar=false

{group('Colors:Window', bg, surface_alt, common)}
{group('Colors:View', surface, view_alt, common)}
{group('Colors:Button', surface_alt, surface, common)}
{group('Colors:Tooltip', surface, surface_alt, common)}
{group('Colors:Header', bg, surface, common)}
{group('Colors:Header][Inactive', bg, surface, roles(text_secondary, text_secondary, t))}
{group('Colors:Complementary', d['surface'], d['surfaceAlt'], complementary)}
{group('Colors:Selection', accent, t['accentHover'], selection)}
[KDE]
ColorScheme={theme_id}
contrast=4

[WM]
activeBackground={rgb(bg)}
activeForeground={rgb(text)}
inactiveBackground={rgb(bg)}
inactiveForeground={rgb(text_secondary)}
activeBlend={rgb(text)}
inactiveBlend={rgb(t['border'])}
'''

(root / 'platform/plasma/color-schemes/RoLight.colors').write_text(
    color_scheme('RoLight', light, False), encoding='utf-8'
)
(root / 'platform/plasma/color-schemes/RoDark.colors').write_text(
    color_scheme('RoDark', dark, True), encoding='utf-8'
)

# --- Sistem varsayılanları (/etc/xdg; 22 SYS-01, SYS-11) ---
# Spec bu dosyaları %config(noreplace) ile /etc/xdg altına kurar; %post hiçbir ayar dosyasına yazmaz.
# kdeglobals renkleri yukarıdaki renk şemasıyla aynı kaynaktan gelir: yeni kullanıcı renkleri XDG
# zincirinden (/etc/xdg) alır, kullanıcı dosyasına yazılmaz. Diğer değerler bugünkü hâliyle taşınır (22b).
def ini_groups(text):
    # KDE INI metnini [grup] -> [satır] sözlüğüne çevirir; grup sırası korunur.
    groups, current = {}, None
    for line in text.splitlines():
        if line.startswith('[') and line.endswith(']'):
            current = line
            groups.setdefault(current, [])
        elif line.strip() and current is not None:
            groups[current].append(line)
    return groups

def ini_text(groups):
    return '\n'.join(head + '\n' + '\n'.join(lines) + '\n' for head, lines in groups.items() if lines)

def set_key(groups, head, key, value):
    lines = [l for l in groups.setdefault(head, []) if not l.startswith(key + '=')]
    groups[head] = lines + [f'{key}={value}']

# FNT-01…06: tek font tablosu; Qt 6 QFont::toString biçimi (ağırlıklar 400/600).
# Normal Noto değerleri Fedora ile aynı: /etc/xdg bunları tekrarlamaz (SYS-02).
# Global tema ise seçildiğinde altı rolü birlikte sunar (GT-04k).
def qfont_string(role):
    f = fonts[role]
    return f"{f['family']},{f['pointSize']},-1,5,{f['weight']},0,0,0,0,0,0,0,0,0,0,1,{f['styleName']},0,0"

font_roles = {'font': 'general', 'fixed': 'fixed', 'smallestReadableFont': 'small',
              'toolBarFont': 'toolbar', 'menuFont': 'menu'}
for mode in ['light', 'dark']:
    defaults_path = root / f'platform/plasma/look-and-feel/org.ro.{mode}/contents/defaults'
    groups = ini_groups(defaults_path.read_text(encoding='utf-8'))
    for key, role in font_roles.items():
        set_key(groups, '[kdeglobals][General]', key, qfont_string(role))
    set_key(groups, '[kdeglobals][WM]', 'activeFont', qfont_string('windowTitle'))
    # 06 GT-04c/e: ikon teması Ro Icons (Ro'nun kendi ikonları Papirus'un üstünde; açık modda Papirus-Light tabanlı
    # ro-icons-light), imleç Breeze (kendi imleç seti gelene kadar).
    set_key(groups, '[kdeglobals][Icons]', 'Theme', 'ro-icons' if mode == 'dark' else 'ro-icons-light')
    set_key(groups, '[kcminputrc][Mouse]', 'cursorTheme', 'breeze_cursors')
    # 06 GT-04j: masaüstü duvar kâğıdı Ro paketi (seed 102; 1080p ve 4K, Plasma boyutu seçer)
    set_key(groups, '[Wallpaper]', 'Image', 'RoDark' if mode == 'dark' else 'RoLight')
    # 06 GT-04i: açılış ekranı dosya önekiyle ([ksplashrc][KSplash]); GT-04l: LookAndFeelPackage'ı Plasma kendisi yazar.
    if '[KSplash]' in groups:
        groups['[ksplashrc][KSplash]'] = groups.pop('[KSplash]')
    groups['[kdeglobals][KDE]'] = [l for l in groups.get('[kdeglobals][KDE]', []) if not l.startswith('LookAndFeelPackage=')]
    defaults_path.write_text(f'# Ro {mode.title()} Global Theme defaults. Font roles generated from core/tokens/fonts.json.\n\n'
                             + ini_text(groups), encoding='utf-8')

XDG_HEADER = '# Ro-ASD system defaults. Generated from core/tokens by scripts/generate-theme.sh.\n# Packaged as %config(noreplace); user settings in ~/.config always take precedence.\n'
default_scheme = 'RoDark'
kdeglobals = ini_groups(color_scheme(default_scheme, dark, True))
kdeglobals['[General]'] = [l for l in kdeglobals.get('[General]', []) if not l.startswith('Name')]
# [KDE] ColorScheme eski bir yedek anahtar; eski %post bunu /etc/xdg'den siliyordu. Yazılmaz.
kdeglobals['[KDE]'] = [l for l in kdeglobals.get('[KDE]', []) if not l.startswith('ColorScheme=')]
set_key(kdeglobals, '[General]', 'ColorScheme', default_scheme)
set_key(kdeglobals, '[KDE]', 'LookAndFeelPackage', 'org.ro.dark')
# 06 GT-02/03: varsayılan koyu; otomatik açık/koyu geçişin çifti Ro paketleri (geçiş KDE varsayılanı gibi kapalı).
set_key(kdeglobals, '[KDE]', 'DefaultLightLookAndFeel', 'org.ro.light')
set_key(kdeglobals, '[KDE]', 'DefaultDarkLookAndFeel', 'org.ro.dark')

# 06 GT-07: global tema meta verisi; sürüm VERSION'dan, Türkçe ad ve açıklama.
for mode, tr_name in (('light', 'Ro Açık'), ('dark', 'Ro Koyu')):
    meta = {'KPlugin': {
        'Id': f'org.ro.{mode}', 'Name': f'Ro {mode.title()}', 'Name[tr]': tr_name,
        'Description': f'Ro Desktop {mode} global theme',
        'Description[tr]': f"Ro masaüstü {'açık' if mode == 'light' else 'koyu'} global teması",
        'Icon': 'preferences-desktop-theme-global', 'Version': (root / 'VERSION').read_text(encoding='utf-8').strip(),
        'License': 'GPL-3.0-or-later', 'Website': 'https://github.com/Project-Ro-ASD/Ro-Theme',
        'Authors': [{'Name': 'Project Ro-ASD'}]},
        'KPackageStructure': 'Plasma/LookAndFeel'}
    (root / f'platform/plasma/look-and-feel/org.ro.{mode}/metadata.json').write_text(
        json.dumps(meta, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
set_key(kdeglobals, '[KDE]', 'widgetStyle', 'Breeze')
set_key(kdeglobals, '[Icons]', 'Theme', 'ro-icons')
set_key(kdeglobals, '[WM]', 'activeFont', qfont_string('windowTitle'))
# 04 APP-11/13: Tamam/İptal düğmelerinde ikon yok; ana araç çubuğu ikon + metin (KDE varsayılanı), diğerleri yalnız ikon.
set_key(kdeglobals, '[KDE]', 'ShowIconsOnPushButtons', 'false')
set_key(kdeglobals, '[Toolbar style]', 'ToolButtonStyleOtherToolbars', 'IconOnly')
rendering = fonts['rendering']
for key, value in {'XftAntialias': str(rendering['antialias']).lower(),
                   'XftHintStyle': rendering['hintStyle'], 'XftSubPixel': rendering['subPixel']}.items():
    set_key(kdeglobals, '[General]', key, value)
lock_wallpaper = 'file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg'
xdg_defaults = {
    'kdeglobals': kdeglobals,
    'kcmfonts': {'[General]': [f"forceFontDPI={fonts['forceFontDPI']}"]},
    # 04 APP-03: Breeze stil ayarları; yalnız KDE varsayılanından farklı olanlar (SYS-02). Ağaç dal çizgisi,
    # araç çubuğu ayracı ve sürgü işaretleri kapalı; animasyon kısa etkileşim süresi (TOK-12g).
    'breezerc': {'[Style]': ['ToolBarDrawItemSeparator=false', 'ViewDrawTreeBranchLines=false',
                             'SliderDrawTickMarks=false', f"AnimationsDuration={motion['fastMs']}"]},
    'plasmarc': {'[Theme]': ['name=RoDark']},
    'ksplashrc': {'[KSplash]': ['Engine=KSplashQML', 'Theme=org.ro.dark']},
    'kscreenlockerrc': {
        '[Greeter]': ['WallpaperPlugin=org.kde.image'],
        '[Greeter][Wallpaper][org.kde.image][General]': [f'Image={lock_wallpaper}', f'PreviewImage={lock_wallpaper}', 'Blur=false'],
    },
    # Plasma 5 kimlikli eski efekt satırları etkisiz olduğu için yazılmaz (FX-23).
    'kwinrc': {
        # WD-16: solda pencere menüsü, sağda küçült/büyüt/kapat (KDE: MSE / HIAX).
        # WD-02/WD-03: Ro Aurorae (v2 eklentisi) varsayılan dekorasyon; global tema da aynısını seçer.
        '[org.kde.kdecoration2]': ['library=org.kde.kwin.aurorae.v2', f'theme=__aurorae__svg__{default_scheme}',
                                   'ButtonsOnLeft=M', 'ButtonsOnRight=IAX'],
        # Giriş sonrası masaüstü ve panel yumuşak yakınlaşarak belirir (platform/kwin/effects/ro-login-reveal).
        '[Plugins]': ['ro-login-revealEnabled=true'],
    },
}
xdg_dir = root / 'platform/plasma/defaults/xdg'
xdg_dir.mkdir(parents=True, exist_ok=True)
for name, groups in xdg_defaults.items():
    (xdg_dir / name).write_text(XDG_HEADER + '\n' + ini_text(groups), encoding='utf-8')

# Eski deneme paletleri (cool, stone) arşivde: docs/archive/palettes (Ro-Theme-Docs 02 COL-31). Üretilmez.

# Plasma çerçeve SVG'si (FrameSvg / 9 parça kuralı):
# - topleft/top/topright/left/center/right/bottomleft/bottom/bottomright öğeleri ayrı parçalardır.
#   Köşeler olduğu gibi çizilir, kenarlar ve orta esnetilir; köşe yuvarlaklığı köşe parçasının şeklidir,
#   bu yüzden köşe parçası (ve ona bitişik kenar kalınlığı) yarıçap kadar büyüktür.
# - hint-*-margin öğelerinin boyutu içeriğin çerçeveden ne kadar içeride duracağını belirler.
# - shadow-* öğeleri KWin gölgesidir; shadow-hint-*-margin gölgenin pencere dışına taşma miktarıdır.
# - Kenarlık stroke ile değil, yüzeyin üstüne dolgulu halka olarak çizilir: stroke parçaların
#   birleştiği yerde "L" izleri bırakıyordu (validate.sh stroke'u yasaklıyor). border=None: kenarlık yok.
FRAME_EDGE = 32   # esneyen kenar parçalarının taslak uzunluğu; görünümü etkilemez
FRAME_BORDER = spacing['borderWidth']  # dekoratif kenarlığın tek kaynağı (TOK-08)

def fmt(value):
    return ('%.4f' % value).rstrip('0').rstrip('.')

def _arc_sweep(ax, ay, p1, p2):
    # SVG'de y aşağı doğru: çapraz çarpım pozitifse yay saat yönündedir (sweep=1)
    cross = (p1[0] - ax) * (p2[1] - ay) - (p1[1] - ay) * (p2[0] - ax)
    return 1 if cross > 0 else 0

def _corner(name, ox, oy, dx, dy, r, fill, fill_opacity, border, border_opacity):
    # (ox, oy): parçanın sol üstü. (dx, dy): yay merkezinden dış köşeye yön (-1/+1).
    ax = ox + (r if dx < 0 else 0)
    ay = oy + (r if dy < 0 else 0)
    b = FRAME_BORDER
    p1 = (ax + dx * r, ay)
    p2 = (ax, ay + dy * r)
    q1 = (ax + dx * (r - b), ay)
    q2 = (ax, ay + dy * (r - b))
    sweep = _arc_sweep(ax, ay, p1, p2)
    surface = (f'M {fmt(ax)},{fmt(ay)} L {fmt(p1[0])},{fmt(p1[1])} '
               f'A {fmt(r)},{fmt(r)} 0 0 {sweep} {fmt(p2[0])},{fmt(p2[1])} Z')
    ring = (f'M {fmt(p1[0])},{fmt(p1[1])} A {fmt(r)},{fmt(r)} 0 0 {sweep} {fmt(p2[0])},{fmt(p2[1])} '
            f'L {fmt(q2[0])},{fmt(q2[1])} A {fmt(r - b)},{fmt(r - b)} 0 0 {1 - sweep} {fmt(q1[0])},{fmt(q1[1])} Z')
    ring_el = f'    <path d="{ring}" fill="{border}" fill-opacity="{border_opacity}"/>\n' if border else ''
    return (f'  <g id="{name}">\n'
            f'    <path d="{surface}" fill="{fill}" fill-opacity="{fill_opacity}"/>\n'
            + ring_el + '  </g>\n')

def _edge(name, x, y, w, h, outer, fill, fill_opacity, border, border_opacity):
    # outer: kenarlığın bulunduğu dış taraf (top/bottom/left/right) ya da None (orta parça)
    b = FRAME_BORDER
    line = {
        'top': (x, y, w, b), 'bottom': (x, y + h - b, w, b),
        'left': (x, y, b, h), 'right': (x + w - b, y, b, h),
    }.get(outer)
    out = (f'  <g id="{name}">\n'
           f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" fill="{fill}" fill-opacity="{fill_opacity}"/>\n')
    if line and border:
        out += (f'    <rect x="{fmt(line[0])}" y="{fmt(line[1])}" width="{fmt(line[2])}" height="{fmt(line[3])}" '
                f'fill="{border}" fill-opacity="{border_opacity}"/>\n')
    return out + '  </g>\n'

def _shadow_stops(alpha, start, steps=6):
    # Yumuşak (ease-out) düşüş: start..1 arasında alpha*(1-t)^2.
    # start > 0 ise (köşe parçası) start'tan önce gölge yok: KWin köşe gölgesini pencerenin altına da
    # çiziyor ve popup yarı saydam olduğu için köşe kavisinin içinde koyu leke olarak görünüyordu.
    stops = []
    if start > 0:
        stops.append(f'<stop offset="{fmt(start - 0.001)}" stop-color="#000000" stop-opacity="0"/>')
    for i in range(steps + 1):
        t = i / steps
        offset = start + (1 - start) * t
        stops.append(f'<stop offset="{fmt(offset)}" stop-color="#000000" stop-opacity="{fmt(alpha * (1 - t) ** 2)}"/>')
    return ''.join(stops)

def _shadows(r, size, alpha, ox, oy):
    # Köşe gölge parçası pencerenin köşe kavisinin altına kadar uzanır (boyut = gölge + yarıçap);
    # böylece yuvarlak köşenin dışında kalan saydam alanda da gölge kesintisiz görünür.
    t = size + r
    e = FRAME_EDGE
    start = r / t
    defs, body = [], []
    corners = {
        'topleft': (ox, oy, 1, 1), 'topright': (ox + t + e, oy, 0, 1),
        'bottomleft': (ox, oy + t + e, 1, 0), 'bottomright': (ox + t + e, oy + t + e, 0, 0),
    }
    for name, (x, y, fx, fy) in corners.items():
        cx, cy = x + fx * t, y + fy * t
        defs.append(f'<radialGradient id="ro-shadow-{name}" gradientUnits="userSpaceOnUse" cx="{fmt(cx)}" cy="{fmt(cy)}" r="{fmt(t)}">'
                    f'{_shadow_stops(alpha, start)}</radialGradient>')
        body.append(f'  <rect id="shadow-{name}" x="{fmt(x)}" y="{fmt(y)}" width="{fmt(t)}" height="{fmt(t)}" fill="url(#ro-shadow-{name})"/>\n')
    edges = {
        # ad: (x, y, w, h, gradyan başı -> sonu (pencereye bitişik kenardan dışa))
        'top': (ox + t, oy + r, e, size, (0, 1, 0, 0)),
        'bottom': (ox + t, oy + t + e, e, size, (0, 0, 0, 1)),
        'left': (ox + r, oy + t, size, e, (1, 0, 0, 0)),
        'right': (ox + t + e, oy + t, size, e, (0, 0, 1, 0)),
    }
    for name, (x, y, w, h, (x1, y1, x2, y2)) in edges.items():
        defs.append(f'<linearGradient id="ro-shadow-{name}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{_shadow_stops(alpha, 0)}</linearGradient>')
        body.append(f'  <rect id="shadow-{name}" x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" fill="url(#ro-shadow-{name})"/>\n')
    hints = (
        f'  <rect id="shadow-hint-top-margin" x="{fmt(ox)}" y="{fmt(oy - 40)}" width="1" height="{fmt(size)}" fill-opacity="0"/>\n'
        f'  <rect id="shadow-hint-bottom-margin" x="{fmt(ox + 4)}" y="{fmt(oy - 40)}" width="1" height="{fmt(size)}" fill-opacity="0"/>\n'
        f'  <rect id="shadow-hint-left-margin" x="{fmt(ox + 8)}" y="{fmt(oy - 40)}" width="{fmt(size)}" height="1" fill-opacity="0"/>\n'
        f'  <rect id="shadow-hint-right-margin" x="{fmt(ox + 8)}" y="{fmt(oy - 36)}" width="{fmt(size)}" height="1" fill-opacity="0"/>\n'
    )
    return defs, ''.join(body) + hints

def plasma_frame_svg(fill, fill_opacity, border, border_opacity, r, padding, shadow=None):
    # shadow: (boyut, opaklık) ya da None. Kenarlık stroke değil dolgu (bkz. üst açıklama).
    e = FRAME_EDGE
    size = 2 * r + e
    parts = [
        _corner('topleft', 0, 0, -1, -1, r, fill, fill_opacity, border, border_opacity),
        _corner('topright', r + e, 0, 1, -1, r, fill, fill_opacity, border, border_opacity),
        _corner('bottomleft', 0, r + e, -1, 1, r, fill, fill_opacity, border, border_opacity),
        _corner('bottomright', r + e, r + e, 1, 1, r, fill, fill_opacity, border, border_opacity),
        _edge('top', r, 0, e, r, 'top', fill, fill_opacity, border, border_opacity),
        _edge('bottom', r, r + e, e, r, 'bottom', fill, fill_opacity, border, border_opacity),
        _edge('left', 0, r, r, e, 'left', fill, fill_opacity, border, border_opacity),
        _edge('right', r + e, r, r, e, 'right', fill, fill_opacity, border, border_opacity),
        _edge('center', r, r, e, e, None, fill, fill_opacity, border, border_opacity),
    ]
    hx = size + 8
    hints = (
        f'  <rect id="hint-top-margin" x="{fmt(hx)}" y="0" width="1" height="{fmt(padding)}" fill-opacity="0"/>\n'
        f'  <rect id="hint-bottom-margin" x="{fmt(hx + 4)}" y="0" width="1" height="{fmt(padding)}" fill-opacity="0"/>\n'
        f'  <rect id="hint-left-margin" x="{fmt(hx + 8)}" y="0" width="{fmt(padding)}" height="1" fill-opacity="0"/>\n'
        f'  <rect id="hint-right-margin" x="{fmt(hx + 8)}" y="4" width="{fmt(padding)}" height="1" fill-opacity="0"/>\n'
        f'  <rect id="hint-stretch-borders" x="{fmt(hx)}" y="{fmt(padding + 8)}" width="1" height="1" fill-opacity="0"/>\n'
    )
    defs, shadow_body = [], ''
    width, height = hx + 40, size
    if shadow:
        sx = hx + 40
        defs, shadow_body = _shadows(r, shadow[0], shadow[1], sx, 48)
        width = sx + 2 * (shadow[0] + r) + FRAME_EDGE + 8
        height = max(height, 48 + 2 * (shadow[0] + r) + FRAME_EDGE + 8)
    defs_block = ('  <defs>\n    ' + '\n    '.join(defs) + '\n  </defs>\n') if defs else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{fmt(width)}" height="{fmt(height)}" viewBox="0 0 {fmt(width)} {fmt(height)}">\n'
            f'  <!-- Ro surface: radius {fmt(r)}, padding {fmt(padding)}. Generated from core/tokens by scripts/generate-theme.sh. -->\n'
            + defs_block + ''.join(parts) + hints + shadow_body + '</svg>\n')

plasma_modes = {
    # (yüzey, yüzey opaklığı, frameBorder, opaklık). Kabuk çerçeveleri TOK-09 revizeden (2026-10-19) beri kenarlıksız ve
    # gölgeli; frameBorder burada kullanılmıyor, kontroller (giriş alanı, düğme) kendi kenarlığını çizer.
    'RoLight': (light['surface'], str(opacity['glass']), light['frameBorder'], '1.0'),
    'RoDark': (dark['surface'], str(opacity['glass']), dark['frameBorder'], '1.0'),
}
# --- Plasma stili: giriş alanı ve düğme (03 PST-22, PST-23; köşe TOK-02f) ---
# Renkler sabit değil ColorScheme-* sınıflarıyla şemadan gelir (PST-03): kullanıcı vurgusu ve renk şeması kabuğa
# yansır. <style id="current-color-scheme"> yalnızca şemasız önizleme için yedek değerdir (token'dan).
def _ctl_corner_paths(ox, oy, dx, dy, r, b):
    ax = ox + (r if dx < 0 else 0)
    ay = oy + (r if dy < 0 else 0)
    p1, p2 = (ax + dx * r, ay), (ax, ay + dy * r)
    q1, q2 = (ax + dx * (r - b), ay), (ax, ay + dy * (r - b))
    sw = _arc_sweep(ax, ay, p1, p2)
    surface = f'M {fmt(ax)},{fmt(ay)} L {fmt(p1[0])},{fmt(p1[1])} A {fmt(r)},{fmt(r)} 0 0 {sw} {fmt(p2[0])},{fmt(p2[1])} Z'
    ring = (f'M {fmt(p1[0])},{fmt(p1[1])} A {fmt(r)},{fmt(r)} 0 0 {sw} {fmt(p2[0])},{fmt(p2[1])} '
            f'L {fmt(q2[0])},{fmt(q2[1])} A {fmt(r - b)},{fmt(r - b)} 0 0 {1 - sw} {fmt(q1[0])},{fmt(q1[1])} Z')
    return surface, ring

def _ctl_layer(shape, cls, opacity):
    op = '' if opacity >= 1 else f' fill-opacity="{fmt(opacity)}"'
    return '    ' + shape.replace('/>', f' class="{cls}" fill="currentColor"{op}/>') + '\n'

def _ctl_block(prefix, y0, r, fills, border, b, margins, pad=(0, 0)):
    # Bir durum için 9 parçalı çerçeve (dolgulu halka, stroke yok); fills: [(sınıf, opaklık)]; border: (sınıf, opaklık) | None
    # pad = (üst, alt): üst/alt sıradaki parçaların kutusu o kenarda saydam payla uzar, görünür şekil o kadar içeride
    # kalır (Plasma parça boyutunu kutudan okur). Varsayılan 0: eski çıktıyla birebir aynı.
    e = FRAME_EDGE; pt, pb = pad; ys = y0 + pt
    spec = {
        'topleft': ('c', 0, 0, -1, -1), 'topright': ('c', r + e, 0, 1, -1),
        'bottomleft': ('c', 0, r + e, -1, 1), 'bottomright': ('c', r + e, r + e, 1, 1),
        'top': ('e', r, 0, e, r, 'top'), 'bottom': ('e', r, r + e, e, r, 'bottom'),
        'left': ('e', 0, r, r, e, 'left'), 'right': ('e', r + e, r, r, e, 'right'),
        'center': ('e', r, r, e, e, None),
    }
    parts = []
    for name, sp in spec.items():
        body = ''
        if sp[0] == 'c':
            surface, ring = _ctl_corner_paths(sp[1], sp[2] + ys, sp[3], sp[4], r, b)
            for cls, op in fills:
                body += _ctl_layer(f'<path d="{surface}"/>', cls, op)
            if border:
                body += _ctl_layer(f'<path d="{ring}"/>', *border)
            px, pw = sp[1], r
        else:
            _, x, y, w, h, outer = sp
            y += ys
            for cls, op in fills:
                body += _ctl_layer(f'<rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}"/>', cls, op)
            line = {'top': (x, y, w, b), 'bottom': (x, y + h - b, w, b), 'left': (x, y, b, h), 'right': (x + w - b, y, b, h)}.get(outer)
            if border and line:
                body += _ctl_layer(f'<rect x="{fmt(line[0])}" y="{fmt(line[1])}" width="{fmt(line[2])}" height="{fmt(line[3])}"/>', *border)
            px, pw = x, w
        if pt and name.startswith('top'):
            body = f'    <rect x="{fmt(px)}" y="{fmt(y0)}" width="{fmt(pw)}" height="{fmt(pt)}" fill-opacity="0"/>\n' + body
        if pb and name.startswith('bottom'):
            body += f'    <rect x="{fmt(px)}" y="{fmt(ys + 2 * r + e)}" width="{fmt(pw)}" height="{fmt(pb)}" fill-opacity="0"/>\n'
        parts.append(f'  <g id="{prefix}-{name}">\n{body}  </g>\n')
    hx = 2 * r + e + 8
    top, bottom, left, right = margins
    hints = (
        f'  <rect id="{prefix}-hint-top-margin" x="{fmt(hx)}" y="{fmt(y0)}" width="1" height="{fmt(top)}" fill-opacity="0"/>\n'
        f'  <rect id="{prefix}-hint-bottom-margin" x="{fmt(hx + 4)}" y="{fmt(y0)}" width="1" height="{fmt(bottom)}" fill-opacity="0"/>\n'
        f'  <rect id="{prefix}-hint-left-margin" x="{fmt(hx + 8)}" y="{fmt(y0)}" width="{fmt(left)}" height="1" fill-opacity="0"/>\n'
        f'  <rect id="{prefix}-hint-right-margin" x="{fmt(hx + 8)}" y="{fmt(y0 + 4)}" width="{fmt(right)}" height="1" fill-opacity="0"/>\n'
    )
    return ''.join(parts) + hints

def _ctl_svg(content, r, rows, tokens):
    size = 2 * r + FRAME_EDGE
    scheme_style = (
        f'    .ColorScheme-Text {{ color:{tokens["text"].lower()}; }}\n'
        f'    .ColorScheme-ViewBackground {{ color:{tokens["surface"].lower()}; }}\n'
        f'    .ColorScheme-ButtonBackground {{ color:{tokens["surfaceAlt"].lower()}; }}\n'
        f'    .ColorScheme-ButtonText {{ color:{tokens["text"].lower()}; }}\n'
        f'    .ColorScheme-ViewFocus {{ color:{tokens["accent"].lower()}; }}\n'
        f'    .ColorScheme-ButtonFocus {{ color:{tokens["accent"].lower()}; }}\n'
        f'    .ColorScheme-Highlight {{ color:{tokens["accent"].lower()}; }}\n')
    h = rows * (size + 8) + 8
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{fmt(size + 60)}" height="{fmt(h)}" viewBox="0 0 {fmt(size + 60)} {fmt(h)}">\n'
            f'  <!-- Ro control: radius {fmt(r)}. Generated from core/tokens by scripts/generate-theme.sh. -->\n'
            f'  <defs>\n  <style id="current-color-scheme" type="text/css">\n{scheme_style}  </style>\n  </defs>\n{content}</svg>\n')

def plasma_lineedit_svg(tokens):
    # PST-22: base = View zemini + kenarlık (metin %50, >= 3:1 COL-16); hover kenar %70; focus vurgu kenarı;
    # focusframe = vurgu halkası (klavye odağı, Ro imzası, 2 × kenarlık).
    # PST-22 revize (2026-10-15): köşe düğmeyle aynı (radius.sm); üst/alt iç pay spacing.fieldPadding (Breeze yüksekliği).
    # Kilit ve giriş ekranı şifre alanının yanına alan yüksekliğinde kare düğme koyar; iki biçim uyumlu olmalı.
    r, b = radius['sm'], spacing['borderWidth']
    m = (spacing['fieldPadding'], spacing['fieldPadding'], spacing['sm'] + spacing['xs'], spacing['sm'] + spacing['xs'])
    size, out, y = 2 * r + FRAME_EDGE, '', 0
    for prefix, border, bw, margins in (
        ('base', ('ColorScheme-Text', 0.5), b, m),
        # hover/focus/focusframe yalnız halka. Plasma (TextFieldFocus.qml) bu katmanı kendi payı kadar alanın DIŞINA taşırır;
        # metin payı verilirse halka giriş ekranında yandaki düğmenin üstüne biner (2026-10-15). Pay 0 "tanımsız" sayılıp
        # köşe boyutuna düşüyor; Breeze gibi 0.001 (taşma yok) ve klavye odak halkası için halka kalınlığı (dışta 2 px).
        ('hover', ('ColorScheme-Text', 0.7), b, (0.001,) * 4),
        ('focus', ('ColorScheme-ViewFocus', 1), b, (0.001,) * 4),
        ('focusframe', ('ColorScheme-ViewFocus', 1), 2 * b, (2 * b,) * 4),
    ):
        # Halka katmanlarında orta parça saydam ama boş değil: boş grup olunca KSvg çerçevenin tamamını çizmez (AB2'deki gibi).
        fills = [('ColorScheme-ViewBackground', 1 if prefix == 'base' else 0)]
        out += _ctl_block(prefix, y, r, fills, border, bw, margins)
        y += size + 8
    out += '  <rect id="hint-focus-over-base" x="0" y="0" width="1" height="1" fill-opacity="0"/>\n'
    out += '  <rect id="hint-tile-center" x="0" y="0" width="1" height="1" fill-opacity="0"/>\n'
    return _ctl_svg(out, r, 4, tokens)

def plasma_button_svg(tokens):
    # PST-23 (revize 2026-10-09): köşe sm (8); normal = Button zemini + ince kenar (buttonEdge). Plasma kapalı onay
    # kutusunu bu çerçeveyle 16 px çizer: köşe 8'den büyük olursa şekil bozulur, kenar kutuyu görünür kılar.
    # Önceki not: normal = Button zemini, kenarsız; hover = + metin %8 (opacity.hover); pressed = + mixPressed;
    # focus = vurgu halkası; araç düğmesi normalde zeminsiz. mask-normal bulanıklık maskesi (PST-09).
    r, b = radius['sm'], spacing['borderWidth']
    m = (spacing['xs'], spacing['xs'], spacing['sm'] + spacing['xs'], spacing['sm'] + spacing['xs'])
    size, out, y = 2 * r + FRAME_EDGE, '', 0
    states = (
        ('normal', [('ColorScheme-ButtonBackground', 1)], ('ColorScheme-ButtonText', opacity['buttonEdge']), b, m),
        ('hover', [('ColorScheme-ButtonBackground', 1), ('ColorScheme-ButtonText', opacity['hover'])], None, b, m),
        ('pressed', [('ColorScheme-ButtonBackground', 1), ('ColorScheme-ButtonText', opacity['mixPressed'])], None, b, m),
        ('focus', [('ColorScheme-ButtonBackground', 1)], ('ColorScheme-ButtonFocus', 1), 2 * b, m),
        ('toolbutton-hover', [('ColorScheme-ButtonText', opacity['hover'])], None, b, m),
        ('toolbutton-pressed', [('ColorScheme-ButtonText', opacity['mixPressed'])], None, b, m),
        ('toolbutton-focus', [], ('ColorScheme-ButtonFocus', 1), 2 * b, m),
        ('mask-normal', [('ColorScheme-ButtonBackground', 1)], None, b, (0, 0, 0, 0)),
    )
    for prefix, fills, border, bw, margins in states:
        out += _ctl_block(prefix, y, r, fills, border, bw, margins)
        y += size + 8
    return _ctl_svg(out, r, len(states), tokens)

def plasma_viewitem_svg(tokens):
    # PST-13/26: Plasma listelerde klavye/fare ile "geçerli öğe" hover önekiyle, basılı öğe selected ile çizilir
    # (PlasmaExtras.Highlight). Kenarsız; dolgu vurgu rengiyle kademeli (listCurrent, listSelected,
    # listSelectedHover). Renk ColorScheme-Highlight: kullanıcı vurgu rengine uyar. Yazı rengi değişmediği
    # için tam vurgu dolgusu kullanılmaz (koyu yazı koyu zeminde okunmaz).
    r, b = radius['sm'], spacing['borderWidth']
    m = (spacing['xs'], spacing['xs'], spacing['sm'], spacing['sm'])
    states = (
        ('normal', [('ColorScheme-Highlight', 0)], None),
        ('hover', [('ColorScheme-Highlight', opacity['listCurrent'])], None),
        ('selected', [('ColorScheme-Highlight', opacity['listSelected'])], None),
        ('selected+hover', [('ColorScheme-Highlight', opacity['listSelectedHover'])], None),
    )
    size, out, y = 2 * r + FRAME_EDGE, '', 0
    for prefix, fills, border in states:
        out += _ctl_block(prefix, y, r, fills, border, b, m)
        y += size + 8
    return _ctl_svg(out, r, len(states), tokens)

def _pill_block(prefix, y0, R, pr, fills):
    # Kaydırma çubuğu için 9 parça: çerçeve kutusu R (toplam genişlik 2R), görünen hap yarıçapı pr; aradaki boşluk
    # (R - pr) parçaların içinde saydam kalır. Plasma'nın *-hint-*-inset ipuçlarına bağlı değildir (PST-19).
    e = FRAME_EDGE
    def layers(shape):
        return ''.join(_ctl_layer(shape, c, o) for c, o in fills)
    parts = {}
    for name, ox, oy, dx, dy in (('topleft', 0, 0, -1, -1), ('topright', R + e, 0, 1, -1),
                                 ('bottomleft', 0, R + e, -1, 1), ('bottomright', R + e, R + e, 1, 1)):
        cx = ox + (R if dx < 0 else 0)
        cy = y0 + oy + (R if dy < 0 else 0)
        p1, p2 = (cx + dx * pr, cy), (cx, cy + dy * pr)
        sw = _arc_sweep(cx, cy, p1, p2)
        parts[name] = layers(f'<path d="M {fmt(cx)},{fmt(cy)} L {fmt(p1[0])},{fmt(p1[1])} A {fmt(pr)},{fmt(pr)} 0 0 {sw} {fmt(p2[0])},{fmt(p2[1])} Z"/>')
    parts['left'] = layers(f'<rect x="{fmt(R - pr)}" y="{fmt(y0 + R)}" width="{fmt(pr)}" height="{fmt(e)}"/>')
    parts['right'] = layers(f'<rect x="{fmt(R + e)}" y="{fmt(y0 + R)}" width="{fmt(pr)}" height="{fmt(e)}"/>')
    parts['top'] = layers(f'<rect x="{fmt(R)}" y="{fmt(y0 + R - pr)}" width="{fmt(e)}" height="{fmt(pr)}"/>')
    parts['bottom'] = layers(f'<rect x="{fmt(R)}" y="{fmt(y0 + R + e)}" width="{fmt(e)}" height="{fmt(pr)}"/>')
    parts['center'] = layers(f'<rect x="{fmt(R)}" y="{fmt(y0 + R)}" width="{fmt(e)}" height="{fmt(e)}"/>')
    # Saydam sınır kutusu: her parçanın boyutu çerçeve kutusuna eşit olsun (görünen hap daha küçük).
    boxes = {'topleft': (0, 0, R, R), 'topright': (R + e, 0, R, R), 'bottomleft': (0, R + e, R, R),
             'bottomright': (R + e, R + e, R, R), 'left': (0, R, R, e), 'right': (R + e, R, R, e),
             'top': (R, 0, e, R), 'bottom': (R, R + e, e, R), 'center': (R, R, e, e)}
    out = ''
    for name, body in parts.items():
        bx, by, bw, bh = boxes[name]
        box = f'    <rect x="{fmt(bx)}" y="{fmt(y0 + by)}" width="{fmt(bw)}" height="{fmt(bh)}" class="ColorScheme-Text" fill="currentColor" fill-opacity="0"/>\n'
        out += f'  <g id="{prefix}-{name}">\n{box}{body}  </g>\n'
    return out

def plasma_scrollbar_svg(tokens, mode):
    # PST-19: 8 px hap tutamak vurgu renginde (açıkta %85 → %100, koyuda %50 → %90; beyaz zeminde aynı opaklık
    # daha soluk göründüğü için tema başına ayrı). Oluk nötr %8; Plasma onu yalnızca üzerine gelince gösterir.
    W = spacing['scrollbarWidth']; R = W / 2; pr = spacing['scrollbarHandle'] / 2
    suffix = 'Light' if mode == 'light' else 'Dark'
    states = (
        ('slider', [('ColorScheme-Highlight', opacity['scrollbar' + suffix])]),
        ('mouseover-slider', [('ColorScheme-Highlight', opacity['scrollbarHover' + suffix])]),
        ('background-vertical', [('ColorScheme-Text', opacity['scrollbarGroove'])]),
        ('background-horizontal', [('ColorScheme-Text', opacity['scrollbarGroove'])]),
    )
    out, y = '', 0
    for prefix, fills in states:
        out += _pill_block(prefix, y, R, pr, fills)
        y += W + FRAME_EDGE + 8
    out += f'  <rect id="hint-scrollbar-size" x="{fmt(W + FRAME_EDGE + 20)}" y="0" width="{fmt(W)}" height="{fmt(W)}" fill-opacity="0"/>\n'
    return _ctl_svg(out, R, len(states), tokens)

def _sized_g(id_, body, box):
    # Öğe boyutunu sabitleyen saydam kutu + gövde (KSvg öğe boyutunu sınır kutusundan alır).
    x, y, w, h = box
    return (f'  <g id="{id_}">\n    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" fill-opacity="0"/>\n'
            f'{body}  </g>\n')

def _disk(cx, cy, r, cls, op=1):
    o = '' if op >= 1 else f' fill-opacity="{fmt(op)}"'
    return f'    <circle cx="{fmt(cx)}" cy="{fmt(cy)}" r="{fmt(r)}" class="{cls}" fill="currentColor"{o}/>\n'

def _ring(cx, cy, r, w, cls, op=1):
    # Stroke yerine dolgulu halka (even-odd), 00 §4.4.
    o = '' if op >= 1 else f' fill-opacity="{fmt(op)}"'
    ri = r - w
    d = (f'M {fmt(cx - r)},{fmt(cy)} A {fmt(r)},{fmt(r)} 0 1 0 {fmt(cx + r)},{fmt(cy)} A {fmt(r)},{fmt(r)} 0 1 0 {fmt(cx - r)},{fmt(cy)} Z '
         f'M {fmt(cx - ri)},{fmt(cy)} A {fmt(ri)},{fmt(ri)} 0 1 0 {fmt(cx + ri)},{fmt(cy)} A {fmt(ri)},{fmt(ri)} 0 1 0 {fmt(cx - ri)},{fmt(cy)} Z')
    return f'    <path d="{d}" fill-rule="evenodd" class="{cls}" fill="currentColor"{o}/>\n'

def _checkmark(ox, oy, size, cls):
    # ✓: iki dolgulu, yuvarlak uçlu çubuk (stroke yok); 16 px kutu oranlarıyla.
    import math
    k = size / 16.0
    t = 2.0 * k
    out = ''
    for (x1, y1), (x2, y2) in (((4.6, 8.4), (7.0, 10.8)), ((7.0, 10.8), (11.6, 5.4))):
        x1, y1, x2, y2 = ox + x1 * k, oy + y1 * k, ox + x2 * k, oy + y2 * k
        L = math.hypot(x2 - x1, y2 - y1)
        a = math.degrees(math.atan2(y2 - y1, x2 - x1))
        out += (f'    <rect x="{fmt(-L / 2 - t / 2)}" y="{fmt(-t / 2)}" width="{fmt(L + t)}" height="{fmt(t)}" rx="{fmt(t / 2)}" '
                f'transform="translate({fmt((x1 + x2) / 2)} {fmt((y1 + y2) / 2)}) rotate({fmt(a)})" class="{cls}" fill="currentColor"/>\n')
    return out

def plasma_checkmarks_svg(tokens):
    # PST-20 A: seçili onay kutusu = vurgu dairesi + ✓ (görünüm zemini rengi; açıkta beyaz, koyuda koyu gri).
    # Kutu çerçevesi Plasma'da düğmenin "normal" çerçevesidir (PST-23); kısmi seçimde Plasma bu öğeyi %50 çizer.
    S = spacing['indicatorSize']; r = S / 2
    out = _sized_g('checkbox', _disk(r, r, r, 'ColorScheme-Highlight') + _checkmark(0, 0, S, 'ColorScheme-ViewBackground'), (0, 0, S, S))
    out += _sized_g('radiobutton', _disk(S + 8 + r, r, S / 5, 'ColorScheme-Highlight'), (S + 8, 0, S, S))
    return _ctl_svg(out, r, 1, tokens)

def plasma_radiobutton_svg(tokens):
    # PST-20 A: daire; seçili = vurgu dairesi + görünüm zemini renginde nokta; üzerine gelince vurgu kenarı;
    # odak = 1 px boşluklu 2 px vurgu halkası (Ro imzası). Gölge yok (TOK-09). Bütün öğeleri Plasma ortalar.
    S = spacing['indicatorSize']; r = S / 2; b = spacing['borderWidth']
    F = S + 6 * b; fr = F / 2
    out = f'  <circle id="hint-size" cx="{fmt(r)}" cy="{fmt(r)}" r="{fmt(r)}" fill-opacity="0"/>\n'
    x = lambda i: i * (F + 8)
    out += _sized_g('normal', _disk(x(1) + r, r, r, 'ColorScheme-ViewBackground') + _ring(x(1) + r, r, r, b, 'ColorScheme-Text', opacity['indicatorEdge']), (x(1), 0, S, S))
    out += _sized_g('shadow', '', (x(2), 0, S, S))
    out += _sized_g('checked', _disk(x(3) + r, r, r, 'ColorScheme-Highlight'), (x(3), 0, S, S))
    dot = S * 3 / 16
    out += _sized_g('symbol', _disk(x(4) + dot, dot, dot, 'ColorScheme-ViewBackground'), (x(4), 0, 2 * dot, 2 * dot))
    out += _sized_g('hover', _ring(x(5) + r, r, r, b, 'ColorScheme-Highlight'), (x(5), 0, S, S))
    out += _sized_g('focus', _ring(x(6) + fr, fr, fr, 2 * b, 'ColorScheme-Highlight'), (x(6), 0, F, F))
    return _ctl_svg(out, r, 2, tokens)

def plasma_switch_svg(tokens):
    # PST-20 A: hap çubuk; kapalı = metin %25, açık = vurgu (Plasma çubuğun tutamağa kadarki kısmını "active" ile
    # çizer); tutamak görünüm zemini renginde daire, çubuğun içinde (2 px boşluk). Gölge yok (TOK-09).
    W, H, K = spacing['switchWidth'], spacing['switchHeight'], spacing['switchKnob']
    r, kr, b = H / 2, K / 2, spacing['borderWidth']
    out, y = '', 0
    for prefix, fills in (('inactive', [('ColorScheme-Text', opacity['switchTrackOff'])]), ('active', [('ColorScheme-Highlight', 1)])):
        out += _ctl_block(prefix, y, r, fills, None, b, (0, 0, 0, 0))
        y += H + FRAME_EDGE + 8
    hx = 2 * r + FRAME_EDGE + 40
    out += f'  <rect id="hint-bar-size" x="{fmt(hx)}" y="0" width="{fmt(W)}" height="{fmt(H)}" fill-opacity="0"/>\n'
    hx += W + 8
    F = H + 6 * b; fr = F / 2
    knob = lambda x0: _disk(x0 + r, r, kr, 'ColorScheme-ViewBackground')
    out += _sized_g('handle', knob(hx), (hx, 0, H, H)); hx += H + 8
    out += _sized_g('handle-hover', knob(hx) + _ring(hx + r, r, kr, b, 'ColorScheme-Highlight'), (hx, 0, H, H)); hx += H + 8
    out += _sized_g('handle-pressed', knob(hx) + _disk(hx + r, r, kr, 'ColorScheme-Text', opacity['mixPressed']), (hx, 0, H, H)); hx += H + 8
    out += _sized_g('handle-focus', _ring(hx + fr, fr, fr, 2 * b, 'ColorScheme-Highlight'), (hx, 0, F, F)); hx += F + 8
    out += _sized_g('handle-shadow', '', (hx, 0, H, H))
    return _ctl_svg(out, r, 3, tokens)

def plasma_slider_svg(tokens):
    # PST-24 (G2): oluk 6 px hap, nötr metin %20; dolu kısım vurgu; tutamak 16 px vurgu dairesi (PST-20 ile aynı dolgulu
    # dil); üzerine gelince metin %12 ile koyulaşır; odak = 1 px boşluklu 2 px vurgu halkası; gölge yok (TOK-09).
    G, H, b = spacing['sliderGroove'], spacing['sliderHandle'], spacing['borderWidth']
    gr, hr = G / 2, H / 2
    out, y = '', 0
    for prefix, fills in (('groove', [('ColorScheme-Text', opacity['sliderGroove'])]),
                          ('groove-highlight', [('ColorScheme-Highlight', 1)])):
        out += _ctl_block(prefix, y, gr, fills, None, b, (0, 0, 0, 0))
        y += G + FRAME_EDGE + 8
    F = H + 6 * b; fr = F / 2
    x = 2 * gr + FRAME_EDGE + 40
    out += f'  <rect id="hint-handle-size" x="{fmt(x)}" y="0" width="{fmt(H)}" height="{fmt(H)}" fill-opacity="0"/>\n'
    x += H + 8
    for o in ('horizontal', 'vertical'):
        out += _sized_g(f'{o}-slider-handle', _disk(x + hr, hr, hr, 'ColorScheme-Highlight'), (x, 0, H, H)); x += H + 8
        out += _sized_g(f'{o}-slider-hover', _disk(x + hr, hr, hr, 'ColorScheme-Highlight') + _disk(x + hr, hr, hr, 'ColorScheme-Text', opacity['sliderHover']), (x, 0, H, H)); x += H + 8
        out += _sized_g(f'{o}-slider-focus', _ring(x + fr, fr, fr, 2 * b, 'ColorScheme-Highlight'), (x, 0, F, F)); x += F + 8
        out += _sized_g(f'{o}-slider-shadow', '', (x, 0, H, H)); x += H + 8
    return _ctl_svg(out, gr, 2, tokens)

def plasma_plasmoidheading_svg(tokens):
    # PST-17 (A): popup başlık ve alt şeridi popup ile aynı renkte; başlığın altında ve alt şeridin üstünde ince
    # ayraç (metin %15, opacity.separator). Dolu ve kaydırılan listelerde son satırın alt şeride karışmasını önler.
    # Plasma bu öğeyi yalnızca dialogs/background ile aynı temadan geliyorsa çizer. Şeridin iç boşluğu popup iç
    # boşluğundan (TOK-05) gelir; tema dosyasındaki hint-*-margin öğeleri etkisizdir (denendi).
    b, R, e = spacing['borderWidth'], spacing['xs'], FRAME_EDGE
    boxes = {'topleft': (0, 0, R, R), 'top': (R, 0, e, R), 'topright': (R + e, 0, R, R),
             'left': (0, R, R, e), 'center': (R, R, e, e), 'right': (R + e, R, R, e),
             'bottomleft': (0, R + e, R, R), 'bottom': (R, R + e, e, R), 'bottomright': (R + e, R + e, R, R)}
    def frame(prefix, y0, line_on):
        out = ''
        for name, (x, y, w, h) in boxes.items():
            body = f'    <rect x="{fmt(x)}" y="{fmt(y0 + y)}" width="{fmt(w)}" height="{fmt(h)}" fill-opacity="0"/>\n'
            if name.startswith(line_on):
                ly = y0 + y + h - b if line_on == 'bottom' else y0 + y
                body += (f'    <rect x="{fmt(x)}" y="{fmt(ly)}" width="{fmt(w)}" height="{fmt(b)}" class="ColorScheme-Text" '
                         f'fill="currentColor" fill-opacity="{fmt(opacity["separator"])}"/>\n')
            out += f'  <g id="{prefix}-{name}">\n{body}  </g>\n'
        return out
    out = frame('header', 0, 'bottom') + frame('footer', 2 * R + e + 8, 'top')
    return _ctl_svg(out, R, 2, tokens)

def plasma_tasks_svg(tokens):
    # PST-16 (B3): KDE'nin görev göstergesi dilinden türetildi (Breeze SVG'si kopyalanmadı): durum başına renkli blok,
    # köşe sm (8) yuvarlak, panel kenarı tarafında 3 px çizgi. Etkin/üzerinde vurgu, dikkat uyarı, ilerleme başarı
    # rengi; açık ve küçültülmüş nötr. Renkler ColorScheme-* sınıflarından (kullanıcı vurgusuna uyar).
    # Önek yok = alt panel; north-/east-/west- = üst/sağ/sol panel; çizgi panelin dayandığı ekran kenarı tarafında.
    # İçe boşluk (2026-10-19): Plasma görev yöneticisini panelin tüm kalınlığına yayar (fill area); görünür şekil çerçeve
    # alanını doldurursa kutucuklar birbirine değer ve panelin kenar çizgisinin üstüne biner. Her parçanın kutusu dış
    # kenarlarda I kadar saydam pay alır, şekil içeride çizilir: kutucuklar arası 2·I boşluk, panel kenarından I.
    br = radius['sm']; R = br + 2 * spacing['borderWidth']; e = FRAME_EDGE; t = spacing['taskLine']
    I = 2 * spacing['borderWidth']; Rc = R + I
    T, A, N, P = 'ColorScheme-Text', 'ColorScheme-Highlight', 'ColorScheme-NeutralText', 'ColorScheme-PositiveText'
    states = {
        'normal': (T, opacity['taskNormal'], T, opacity['taskNormalLine']),
        'focus': (A, opacity['taskFocus'], A, 1),
        'hover': (A, opacity['taskHover'], A, opacity['taskHoverLine']),
        'minimized': (T, opacity['taskMinimized'], T, opacity['taskMinimizedLine']),
        'attention': (N, opacity['taskAttention'], N, 1),
        'progress': (P, opacity['taskProgress'], None, 0),
    }
    # Parça kutuları (Rc = R + I; Plasma parça boyutunu bunlardan okur) ve içlerindeki görünür alan (dış kenarda I içeride).
    boxes = {'topleft': (0, 0, Rc, Rc), 'top': (Rc, 0, e, Rc), 'topright': (Rc + e, 0, Rc, Rc),
             'left': (0, Rc, Rc, e), 'center': (Rc, Rc, e, e), 'right': (Rc + e, Rc, Rc, e),
             'bottomleft': (0, Rc + e, Rc, Rc), 'bottom': (Rc, Rc + e, e, Rc), 'bottomright': (Rc + e, Rc + e, Rc, Rc)}
    def visible(name, x, y, w, h):
        if name.startswith('top'): y, h = y + I, h - I
        if name.startswith('bottom'): h = h - I
        if name.endswith('left'): x, w = x + I, w - I
        if name.endswith('right'): w = w - I
        return x, y, w, h
    def op_(v):
        return '' if v >= 1 else f' fill-opacity="{fmt(v)}"'
    def corner(x, y, name):
        L, Tp = name.endswith('left'), name.startswith('top')
        ox, oy = (x + R if L else x), (y + R if Tp else y)
        dx, dy = (-1 if L else 1), (-1 if Tp else 1)
        sw = 1 if dx * dy > 0 else 0
        return (f'M {fmt(ox)},{fmt(oy)} L {fmt(ox + dx * R)},{fmt(oy)} L {fmt(ox + dx * R)},{fmt(oy + dy * (R - br))} '
                f'A {fmt(br)},{fmt(br)} 0 0 {sw} {fmt(ox + dx * (R - br))},{fmt(oy + dy * R)} L {fmt(ox)},{fmt(oy + dy * R)} Z')
    def line(name, x, y, w, h, side):
        # Çizgi panel kenarı tarafında; yuvarlak köşede eğrinin içinde kalır (köşe parçasında br kadar içeriden).
        if side == 'bottom' and name.startswith('bottom'):
            x0 = x + (br if name == 'bottomleft' else 0); w0 = w - (0 if name == 'bottom' else br)
            return (x0, y + h - t, w0, t)
        if side == 'top' and name.startswith('top'):
            x0 = x + (br if name == 'topleft' else 0); w0 = w - (0 if name == 'top' else br)
            return (x0, y, w0, t)
        if side == 'left' and name.endswith('left'):
            y0 = y + (br if name == 'topleft' else 0); h0 = h - (0 if name == 'left' else br)
            return (x, y0, t, h0)
        if side == 'right' and name.endswith('right'):
            y0 = y + (br if name == 'topright' else 0); h0 = h - (0 if name == 'right' else br)
            return (x + w - t, y0, t, h0)
        return None
    out, y = '', 0
    for dir_prefix, side in (('', 'bottom'), ('north-', 'top'), ('west-', 'left'), ('east-', 'right')):
        for state, (bc, bo, lc, lo) in states.items():
            prefix = dir_prefix + state
            for name, (bx, by, bw, bh) in boxes.items():
                by += y
                body = f'    <rect x="{fmt(bx)}" y="{fmt(by)}" width="{fmt(bw)}" height="{fmt(bh)}" fill-opacity="0"/>\n'
                x, yy, w, h = visible(name, bx, by, bw, bh)
                if name in ('topleft', 'topright', 'bottomleft', 'bottomright'):
                    body += f'    <path d="{corner(x, yy, name)}" class="{bc}" fill="currentColor"{op_(bo)}/>\n'
                else:
                    body += f'    <rect x="{fmt(x)}" y="{fmt(yy)}" width="{fmt(w)}" height="{fmt(h)}" class="{bc}" fill="currentColor"{op_(bo)}/>\n'
                ln = line(name, x, yy, w, h, side) if lc else None
                if ln:
                    lx, ly, lw, lh = ln
                    body += f'    <rect x="{fmt(lx)}" y="{fmt(ly)}" width="{fmt(lw)}" height="{fmt(lh)}" class="{lc}" fill="currentColor"{op_(lo)}/>\n'
                out += f'  <g id="{prefix}-{name}">\n{body}  </g>\n'
            if state == 'normal':
                hx = 2 * Rc + e + 20; m = spacing['xs']
                for i, side_name in enumerate(('top', 'bottom', 'left', 'right')):
                    w_, h_ = (1, m) if side_name in ('top', 'bottom') else (m, 1)
                    out += f'  <rect id="{prefix}-hint-{side_name}-margin" x="{fmt(hx + 4 * i)}" y="{fmt(y)}" width="{fmt(w_)}" height="{fmt(h_)}" fill-opacity="0"/>\n'
            y += 2 * Rc + e + 8
    # PST-16 grup göstergesi (G1, 2026-10-15): aynı uygulamanın birden fazla penceresi. Plasma görev simgesinin panel
    # tarafına koyar; KDE'nin dili gibi vurgu renginde daire içinde "+" (artı, vurgu üstü metin rengi; etkin görevin
    # vurgu çizgisiyle karışmasın diye nokta/halka seçilmedi).
    gs = 11; gx = 2 * Rc + e + 40; c = gs / 2
    for gi, gname in enumerate(('top', 'bottom', 'left', 'right')):
        gy = y + gi * (gs + 4)
        body = (f'    <rect x="{fmt(gx)}" y="{fmt(gy)}" width="{gs}" height="{gs}" fill-opacity="0"/>\n'
                f'    <circle cx="{fmt(gx + c)}" cy="{fmt(gy + c)}" r="{fmt(c)}" class="ColorScheme-Highlight" fill="currentColor"/>\n'
                f'    <rect x="{fmt(gx + c - 0.75)}" y="{fmt(gy + 2.5)}" width="1.5" height="6" class="ColorScheme-HighlightedText" fill="currentColor"/>\n'
                f'    <rect x="{fmt(gx + 2.5)}" y="{fmt(gy + c - 0.75)}" width="6" height="1.5" class="ColorScheme-HighlightedText" fill="currentColor"/>\n')
        out += f'  <g id="group-expander-{gname}">\n{body}  </g>\n'
    svg = _ctl_svg(out, Rc, 24, tokens)
    return svg.replace('    .ColorScheme-Text', f'    .ColorScheme-HighlightedText {{ color:{tokens["selectionText"].lower()}; }}\n'
                       f'    .ColorScheme-NeutralText {{ color:{tokens["neutral"].lower()}; }}\n'
                       f'    .ColorScheme-PositiveText {{ color:{tokens["positive"].lower()}; }}\n    .ColorScheme-Text', 1)

def _arc(cx, cy, r, w, a0, sweep, cls, op=1):
    # Yuvarlak uçlu dolgulu yay (stroke yok, 00 §4.4); açı 0 = saat 12, saat yönünde.
    import math
    o = '' if op >= 1 else f' fill-opacity="{fmt(op)}"'
    ri, rc = r - w, w / 2
    def pt(rad, a):
        t = math.radians(a - 90)
        return cx + rad * math.cos(t), cy + rad * math.sin(t)
    a1 = a0 + sweep; big = 1 if sweep > 180 else 0
    (ox0, oy0), (ox1, oy1), (ix1, iy1), (ix0, iy0) = pt(r, a0), pt(r, a1), pt(ri, a1), pt(ri, a0)
    d = (f'M {fmt(ox0)},{fmt(oy0)} A {fmt(r)},{fmt(r)} 0 {big} 1 {fmt(ox1)},{fmt(oy1)} '
         f'A {fmt(rc)},{fmt(rc)} 0 0 1 {fmt(ix1)},{fmt(iy1)} '
         f'A {fmt(ri)},{fmt(ri)} 0 {big} 0 {fmt(ix0)},{fmt(iy0)} '
         f'A {fmt(rc)},{fmt(rc)} 0 0 1 {fmt(ox0)},{fmt(oy0)} Z')
    return f'    <path d="{d}" class="{cls}" fill="currentColor"{o}/>\n'

def plasma_busywidget_svg(tokens):
    # PST-21 A: vurgu renginde 270° yay, yuvarlak uçlu (Ro logo yayı); Plasma 2 sn'de bir tur döndürür.
    # Küçük boylar için 22-22- ve 16-16- öğeleri daha ince yayla ayrıca çizilir.
    out, x = '', 0
    for id_, S, w in (('busywidget', 32, spacing['busyArc']), ('22-22-busywidget', 22, spacing['busyArc22']),
                      ('16-16-busywidget', 16, spacing['busyArc16'])):
        c = S / 2
        out += _sized_g(id_, _arc(x + c, c, c - 0.5, w, 0, spacing['busySweep'], 'ColorScheme-Highlight'), (x, 0, S, S))
        x += S + 8
    style = _ctl_svg('', 1, 1, tokens).split('<defs>')[1].split('</defs>')[0]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{fmt(x)}" height="32" viewBox="0 0 {fmt(x)} 32">\n'
            f'  <!-- Ro busy indicator. Generated from core/tokens by scripts/generate-theme.sh. -->\n'
            f'  <defs>{style}</defs>\n{out}</svg>\n')

def _tab_line(prefix, y0, r, side, cls, t, inset, off):
    # Yuvarlak uçlu çizgi (stroke yok): köşe parçalarında yarım daire uç, kenar parçasında düz gövde.
    # side: bottom | top; inset = uç merkezinin parça kenarına uzaklığı - t/2; off = çerçeve kenarından boşluk.
    e = FRAME_EDGE; rc = t / 2; cx = inset + rc
    ly = y0 + (2 * r + e - off - t if side == 'bottom' else off)
    def rect(x, w):
        return f'    <rect x="{fmt(x)}" y="{fmt(ly)}" width="{fmt(w)}" height="{fmt(t)}" class="{cls}" fill="currentColor"/>\n'
    def cap(x, left):
        return (f'    <path d="M {fmt(x)},{fmt(ly)} A {fmt(rc)},{fmt(rc)} 0 0 {0 if left else 1} {fmt(x)},{fmt(ly + t)} Z" '
                f'class="{cls}" fill="currentColor"/>\n')
    end = 2 * r + e - cx
    return {f'{prefix}-{side}left': cap(cx, True) + rect(cx, r - cx),
            f'{prefix}-{side}': rect(r, e),
            f'{prefix}-{side}right': rect(r + e, end - (r + e)) + cap(end, False)}

def _inject(svg, pieces):
    # Üretilmiş çerçeve gruplarının sonuna ek gövde yerleştirir: {grup id: gövde}.
    for gid, body in pieces.items():
        k = svg.index(f'<g id="{gid}">\n'); j = svg.index('  </g>\n', k)
        svg = svg[:j] + body + svg[j:]
    return svg

def plasma_tabbar_svg(tokens):
    # PST-25 AB2: etkin sekme = vurgu tonlu hap (tabActive, liste vurgusuyla aynı) + içinde yuvarlak uçlu vurgu çizgisi;
    # çizgi içeriğe bakan kenarda (north = başlık sekmeleri, alt kenar; south = alt sekmeler, üst kenar).
    # Plasma bu çerçeveyi sekmeler arasında kaydırır. west-/east- PC3'te kullanılmaz; çizgisiz hap olarak verilir.
    r, b, e = radius['md'], spacing['borderWidth'], FRAME_EDGE
    m = (spacing['sm'], spacing['sm'], spacing['md'], spacing['md'])
    fills = [('ColorScheme-Highlight', opacity['tabActive'])]
    out, y, pieces = '', 0, {}
    # Plasma bu çerçeveyi panelde açık uygulamacığın (başlatıcı, tepsi) vurgusu olarak da çizer ve panelin tüm kalınlığına
    # yayar (2026-10-19): popup'a bakan kenar (çizginin olduğu kenar; alt panelde üst) panel kenar çizgisinin üstüne
    # binmesin, açılan popup'a yapışmasın diye o kenarda içe pay (2 × kenarlık). Yan kenarlara pay yok: sekme çubuğunda sekmeler
    # arasında boşluk açılmasın.
    I = 2 * b
    for d, side, pad in (('north', 'bottom', (0, I)), ('south', 'top', (I, 0)), ('west', None, (0, 0)), ('east', None, (0, 0))):
        out += _ctl_block(f'{d}-active-tab', y, r, fills, None, b, m, pad)
        if side:
            pieces.update(_tab_line(f'{d}-active-tab', y + pad[0], r, side, 'ColorScheme-Highlight', spacing['tabLine'], r - 2, 3))
        y += 2 * r + e + 8 + sum(pad)
    return _inject(_ctl_svg(out, r, 4, tokens), pieces)

def plasma_bar_meter_svg(tokens):
    # PST-14 (ilerleme çubuğu, PlasmaComponents.ProgressBar): sürgü G2 diliyle aynı (PST-24): oluk nötr
    # (sliderGroove), dolu kısım vurgu; hap, yükseklik progressBar. Pil, bildirim aktarımı, disk doluluğu.
    H = spacing['progressBar']; r = H / 2; e = FRAME_EDGE
    out = _ctl_block('bar-inactive', 0, r, [('ColorScheme-Text', opacity['sliderGroove'])], None, spacing['borderWidth'], (0, 0, 0, 0))
    out += _ctl_block('bar-active', H + e + 8, r, [('ColorScheme-Highlight', 1)], None, spacing['borderWidth'], (0, 0, 0, 0))
    hx = 2 * r + e + 40
    out += f'  <rect id="hint-bar-size" x="{fmt(hx)}" y="0" width="{fmt(H)}" height="{fmt(H)}" fill-opacity="0"/>\n'
    return _ctl_svg(out, r, 2, tokens)

def plasma_line_svg(tokens):
    # PST-14 (ayraç çizgisi; liste bölüm başlıkları, açılır liste öğeleri, sayı kutusu): 1 px, metin %15
    # (PST-17 ayracıyla aynı).
    b, L = spacing['borderWidth'], 32
    sep = ('ColorScheme-Text', opacity['separator'])
    out = (f'  <rect id="horizontal-line" x="0" y="0" width="{fmt(L)}" height="{fmt(b)}" class="{sep[0]}" fill="currentColor" fill-opacity="{fmt(sep[1])}"/>\n'
           f'  <rect id="vertical-line" x="{fmt(L + 8)}" y="0" width="{fmt(b)}" height="{fmt(L)}" class="{sep[0]}" fill="currentColor" fill-opacity="{fmt(sep[1])}"/>\n')
    return _ctl_svg(out, L / 2, 1, tokens)

def plasma_frame_widget_svg(tokens):
    # PST-14 (genel çerçeve, PlasmaComponents.Frame/GroupBox): zeminsiz, ince nötr kenar (frameEdge), köşe sm;
    # gölge olmadığı için raised ve sunken plain ile aynı (TOK-09).
    r, b = radius['sm'], spacing['borderWidth']; m = (spacing['sm'],) * 4
    out, y = '', 0
    for prefix in ('plain', 'raised', 'sunken'):
        out += _ctl_block(prefix, y, r, [('ColorScheme-Text', 0)], ('ColorScheme-Text', opacity['frameEdge']), b, m)
        y += 2 * r + FRAME_EDGE + 8
    return _ctl_svg(out, r, 3, tokens)

def plasma_listitem_svg(tokens):
    # PST-14 (eski tip liste öğesi, PlasmaExtras.ListItem / ItemDelegate zemini / pano menüsü): viewitem (PST-13 V3)
    # diliyle aynı: normal saydam, üzerinde vurgu listCurrent, basılı/seçili listSelected; bölüm metin %5; ayraç %15.
    r, b = radius['sm'], spacing['borderWidth']; m = (spacing['xs'], spacing['xs'], spacing['sm'], spacing['sm'])
    A, T = 'ColorScheme-Highlight', 'ColorScheme-Text'
    out, y = '', 0
    for prefix, fills in (('normal', [(T, 0)]), ('hover', [(A, opacity['listCurrent'])]),
                          ('pressed', [(A, opacity['listSelected'])]), ('section', [(T, opacity['listSection'])])):
        out += _ctl_block(prefix, y, r, fills, None, b, m)
        y += 2 * r + FRAME_EDGE + 8
    out += (f'  <rect id="separator" x="0" y="{fmt(y)}" width="32" height="{fmt(b)}" class="{T}" fill="currentColor" '
            f'fill-opacity="{fmt(opacity["separator"])}"/>\n')
    return _ctl_svg(out, r, 5, tokens)

def plasma_arrows_svg(tokens):
    # PST-14 (yön okları; açılır kutu, menülü düğme): ince, yuvarlak uçlu ok başı; iki dolgulu çubuk (stroke yok).
    import math
    S = spacing['arrowSize']; t = 1.5 * spacing['borderWidth']
    def chevron(ox, rot):
        out = ''
        for (x1, y1), (x2, y2) in (((4.5, 6.25), (8, 9.75)), ((8, 9.75), (11.5, 6.25))):
            L = math.hypot(x2 - x1, y2 - y1); a = math.degrees(math.atan2(y2 - y1, x2 - x1))
            out += (f'    <rect x="{fmt(-L / 2 - t / 2)}" y="{fmt(-t / 2)}" width="{fmt(L + t)}" height="{fmt(t)}" rx="{fmt(t / 2)}" '
                    f'transform="rotate({fmt(rot)} {fmt(ox + S / 2)} {fmt(S / 2)}) translate({fmt(ox + (x1 + x2) / 2)} {fmt((y1 + y2) / 2)}) rotate({fmt(a)})" '
                    f'class="ColorScheme-Text" fill="currentColor"/>\n')
        return out
    out = ''
    for i, (id_, rot) in enumerate((('down-arrow', 0), ('left-arrow', 90), ('up-arrow', 180), ('right-arrow', 270))):
        x = i * (S + 8)
        out += _sized_g(id_, chevron(x, rot), (x, 0, S, S))
    return _ctl_svg(out, S / 2, 1, tokens)

popup_radius = radius.get('popup', radius['lg'])
widget_radius = radius.get('widget', radius['lg'])
popup_padding = spacing.get('popupPadding', spacing['sm'])
# TOK-09 revize (2026-10-19, tema sorumlusu): kabuk yüzeyleri (popup, panel, araç ipucu, masaüstü bileşeni) kenarlıksız;
# katman ayrımı yüzey tonu ve yumuşak gölgeyle (Breeze dili). Kenarlıklar köşelerde ve panele yapışık popup'ta Plasma'nın
# kendi ayırıcısıyla üst üste binip çift/basamaklı çizgi yapıyordu. Değerler TOK-10 (boyut 22, opaklık 0.38); panel ve
# araç ipucu küçük gölge (panelShadow).
popup_shadow = (spacing['popupShadow'], opacity['popupShadow'])
small_shadow = (spacing['panelShadow'], opacity['popupShadow'])
solid_opacity = opacity.get('solid', 1.0)
for theme_name, (fill, alpha, stroke, stroke_alpha) in plasma_modes.items():
    base = root / 'platform/plasma/desktoptheme' / theme_name
    shell_border = None  # kabuk çerçevelerinde kenarlık yok (TOK-09 revize); frameBorder kontrollerde kullanılır
    outputs = {
        # Popup'lar: normal (compositing açık), translucent (bulanıklık var), solid (compositing kapalı → opak)
        'dialogs/background.svg': plasma_frame_svg(fill, alpha, shell_border, 0, popup_radius, popup_padding, popup_shadow),
        'translucent/dialogs/background.svg': plasma_frame_svg(fill, alpha, shell_border, 0, popup_radius, popup_padding, popup_shadow),
        'solid/dialogs/background.svg': plasma_frame_svg(fill, solid_opacity, shell_border, 0, popup_radius, popup_padding, popup_shadow),
        'widgets/background.svg': plasma_frame_svg(fill, alpha, shell_border, 0, widget_radius, popup_padding, popup_shadow),
        # PST-15 (2026-10-13, P1): panel zemini Plasma'nın okuduğu yolda; köşe radius.panel, iç boşluk xs (44 px barda
        # ikonlar küçülmesin). Panel yüzerken widgets/ (yarı saydam, bulanıklıkta translucent/); bir pencere bara
        # değince (uyarlanır opaklık, büyütülmüş pencere) solid/ (opak). solid/ yoksa Plasma Breeze'inkine düşüyordu.
        **{k: plasma_frame_svg(fill, a_, shell_border, 0, radius['panel'], spacing['xs'], small_shadow)
           for k, a_ in (('widgets/panel-background.svg', alpha), ('translucent/widgets/panel-background.svg', alpha),
                         ('solid/widgets/panel-background.svg', solid_opacity))},
        # Kabuk kontrolleri (03): Breeze'e düşen giriş alanı ve düğme artık Ro köşesi ve kenarlığıyla çizilir.
        'widgets/lineedit.svg': plasma_lineedit_svg(light if theme_name == 'RoLight' else dark),
        'widgets/button.svg': plasma_button_svg(light if theme_name == 'RoLight' else dark),
        'widgets/viewitem.svg': plasma_viewitem_svg(light if theme_name == 'RoLight' else dark),
        'widgets/scrollbar.svg': plasma_scrollbar_svg(light if theme_name == 'RoLight' else dark, 'light' if theme_name == 'RoLight' else 'dark'),
        'widgets/checkmarks.svg': plasma_checkmarks_svg(light if theme_name == 'RoLight' else dark),
        'widgets/radiobutton.svg': plasma_radiobutton_svg(light if theme_name == 'RoLight' else dark),
        'widgets/switch.svg': plasma_switch_svg(light if theme_name == 'RoLight' else dark),
        'widgets/slider.svg': plasma_slider_svg(light if theme_name == 'RoLight' else dark),
        'widgets/plasmoidheading.svg': plasma_plasmoidheading_svg(light if theme_name == 'RoLight' else dark),
        'widgets/tabbar.svg': plasma_tabbar_svg(light if theme_name == 'RoLight' else dark),
        'widgets/busywidget.svg': plasma_busywidget_svg(light if theme_name == 'RoLight' else dark),
        'widgets/tasks.svg': plasma_tasks_svg(light if theme_name == 'RoLight' else dark),
        # PST-14 P2: Plasma bileşenlerinin gerçekten kullandığı, Breeze'e düşen öğeler.
        'widgets/bar_meter_horizontal.svg': plasma_bar_meter_svg(light if theme_name == 'RoLight' else dark),
        'widgets/bar_meter_vertical.svg': plasma_bar_meter_svg(light if theme_name == 'RoLight' else dark),
        'widgets/line.svg': plasma_line_svg(light if theme_name == 'RoLight' else dark),
        'widgets/frame.svg': plasma_frame_widget_svg(light if theme_name == 'RoLight' else dark),
        'widgets/listitem.svg': plasma_listitem_svg(light if theme_name == 'RoLight' else dark),
        'widgets/arrows.svg': plasma_arrows_svg(light if theme_name == 'RoLight' else dark),
        'widgets/translucentbackground.svg': plasma_frame_svg(fill, alpha, shell_border, 0, widget_radius, popup_padding, popup_shadow),
        # PST-18 (T5): araç ipucu bir ton koyu zemin (surfaceAlt), köşe sm, iç boşluk sm; TOK-09 revize ile kenarlık
        # yerine küçük gölge (2026-10-19).
        **{k: plasma_frame_svg((light if theme_name == 'RoLight' else dark)['surfaceAlt'], solid_opacity, shell_border, 0,
                               radius['sm'], spacing['sm'], small_shadow)
           for k in ('widgets/tooltip.svg', 'translucent/widgets/tooltip.svg', 'solid/widgets/tooltip.svg')},
    }
    for rel, content in outputs.items():
        out = base / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(content, encoding='utf-8')

desktop_theme_colors = {
    'RoLight': color_scheme('RoLight', light, False),
    'RoDark': color_scheme('RoDark', dark, True),
}
for theme_name, content in desktop_theme_colors.items():
    (root / 'platform/plasma/desktoptheme' / theme_name / 'colors').write_text(content, encoding='utf-8')
    # FX-17 revize (2026-10-13): AdaptiveTransparency açık. Panel boşken yarı saydam yüzer; bara pencere değince
    # (büyütülmüş) solid/widgets/panel-background ile opak Ro zeminine geçer. Büyütülmüş pencere varken popup'lar da
    # opak çizilir; arkalarında zaten opak pencere olduğu için cam kaybı pratikte görünmüyor.
    (root / 'platform/plasma/desktoptheme' / theme_name / 'plasmarc').write_text('''[ContrastEffect]
enabled=true
contrast=0.35
saturation=1.05

[AdaptiveTransparency]
enabled=true
''', encoding='utf-8')

# --- GTK yüzeyi ---
# Ro-GTK tek paket olarak kalır. Varsayılan kurulum dark olduğu için GTK yüzeyi dark tokenlardan üretilir.
gtk_css = f'''/* Generated from core/tokens by scripts/generate-theme.sh. */
@define-color ro_bg {dark['bg']};
@define-color ro_bg_alt {dark['bgAlt']};
@define-color ro_surface {dark['surface']};
@define-color ro_surface_alt {dark['surfaceAlt']};
@define-color ro_text {dark['text']};
@define-color ro_text_secondary {dark['textSecondary']};
@define-color ro_accent {dark['accent']};
@define-color ro_border {dark['border']};

* {{
  border-radius: {radius['md']}px;
}}

window,
dialog,
popover {{
  background: @ro_bg;
  color: @ro_text;
}}

headerbar,
.titlebar {{
  background: @ro_surface;
  color: @ro_text;
  border-bottom: {spacing['borderWidth']}px solid @ro_border;
}}

button {{
  background: @ro_surface_alt;
  color: @ro_text;
  border: {spacing['borderWidth']}px solid @ro_border;
  padding: {spacing['sm']}px {spacing['md']}px;
}}

button:hover {{
  border-color: @ro_accent;
}}

button:checked,
button:active {{
  background: @ro_accent;
  color: @ro_bg;
}}

entry,
textview,
spinbutton {{
  background: @ro_surface;
  color: @ro_text;
  border: {spacing['borderWidth']}px solid @ro_border;
}}

entry:focus,
textview:focus {{
  border-color: @ro_accent;
}}

selection,
.view:selected,
row:selected {{
  background: @ro_accent;
  color: @ro_bg;
}}
'''
for rel in ['platform/gtk/Ro-GTK/gtk-3.0/gtk.css', 'platform/gtk/Ro-GTK/gtk-4.0/gtk.css']:
    (root / rel).write_text(gtk_css, encoding='utf-8')

# --- KWin pencere dekorasyonu (Aurorae) ---
# Aurorae de Plasma çerçeveleriyle aynı 9 parça kuralını kullanır; öğe adları önekli olur:
#   decoration-*, decoration-inactive-*, decoration-maximized-*, decoration-maximized-inactive-*
# Gölge Aurorae'de ayrı değildir: Padding* alanı içinde çerçeve SVG'sinin parçası olarak çizilir.
# NOT: Aurorae KWin'e köşe yarıçapı bildirmez (setBorderRadius yok), yani uygulama içeriğinin köşeleri
# kırpılmaz. Dış hattın yuvarlak görünmesi için yan/alt kenarlık en az ~0.3 * yarıçap olmalı
# (içeriğin köşesi dış kavisin altında kalır).
version = (root / 'VERSION').read_text(encoding='utf-8').strip()
# Plasma stili meta verisindeki sürüm de VERSION'dan (elle güncellenince eskiyordu).
for _theme in ('RoLight', 'RoDark'):
    _meta_path = root / f'platform/plasma/desktoptheme/{_theme}/metadata.json'
    _meta = json.loads(_meta_path.read_text(encoding='utf-8'))
    _meta['KPlugin']['Version'] = version
    _meta_path.write_text(json.dumps(_meta, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
window_radius = radius.get('window', radius['md'])
window_border = spacing.get('windowBorder', 4)
titlebar_height = spacing.get('titlebarHeight', 36)
title_button = spacing.get('titleButton', 24)
# WD-18 (2026-10-13): pencereler TOK-09'un istisnası; yumuşak, her yöne eşit gölge (S2.5). Popup, menü ve ipucu
# gölgesiz kalır. Aurorae gölgeyi Padding* alanında çerçeve SVG'sinin parçası olarak çizer.
window_shadow = spacing['windowShadow']
if window_border < 0.3 * window_radius:
    raise SystemExit(f'windowBorder ({window_border}) must be >= 0.3 * radius.window ({window_radius}) '
                     'so client corners stay under the rounded frame')

def _aurorae_frame(prefix, ox, oy, pad, r, body, body_opacity, edge, edge_opacity, shadow_alpha, rounded=True):
    # Tüm parçalar pad + r kalınlığında: dışta gölge (pad), içte gövde (r). Gövdenin yan/alt kısmı
    # uygulama içeriğinin altında kalır, sadece windowBorder kadarı görünür.
    t = pad + r
    e = FRAME_EDGE
    defs, out = [], []

    def corner(name, x, y, dx, dy):
        ax = x + (t if dx < 0 else 0)
        ay = y + (t if dy < 0 else 0)
        if rounded and shadow_alpha > 0:
            gid = f'ro-{prefix}-{name}-shadow'
            defs.append(f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{fmt(ax)}" cy="{fmt(ay)}" r="{fmt(t)}">'
                        f'{_shadow_stops(shadow_alpha, r / t)}</radialGradient>')
            shadow = f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(t)}" height="{fmt(t)}" fill="url(#{gid})"/>\n'
        else:
            shadow = f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(t)}" height="{fmt(t)}" fill-opacity="0"/>\n'
        if rounded:
            b = FRAME_BORDER
            p1 = (ax + dx * r, ay)
            p2 = (ax, ay + dy * r)
            q1 = (ax + dx * (r - b), ay)
            q2 = (ax, ay + dy * (r - b))
            sw = _arc_sweep(ax, ay, p1, p2)
            body_path = (f'M {fmt(ax)},{fmt(ay)} L {fmt(p1[0])},{fmt(p1[1])} A {fmt(r)},{fmt(r)} 0 0 {sw} '
                         f'{fmt(p2[0])},{fmt(p2[1])} Z')
            ring = (f'M {fmt(p1[0])},{fmt(p1[1])} A {fmt(r)},{fmt(r)} 0 0 {sw} {fmt(p2[0])},{fmt(p2[1])} '
                    f'L {fmt(q2[0])},{fmt(q2[1])} A {fmt(r - b)},{fmt(r - b)} 0 0 {1 - sw} {fmt(q1[0])},{fmt(q1[1])} Z')
            shape = (f'    <path d="{body_path}" fill="{body}" fill-opacity="{body_opacity}"/>\n'
                     f'    <path d="{ring}" fill="{edge}" fill-opacity="{edge_opacity}"/>\n')
        else:
            shape = f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(t)}" height="{fmt(t)}" fill="{body}" fill-opacity="{body_opacity}"/>\n'
        out.append(f'  <g id="{prefix}-{name}">\n{shadow}{shape}  </g>\n')

    def side(name, x, y, w, h, outward):
        # outward: gölgenin uzandığı yön; gövde içte kalan r kalınlığındaki kısım
        b = FRAME_BORDER
        if outward == 'top':
            body_rect, line, grad, shadow_rect = (x, y + pad, w, h - pad), (x, y + pad, w, b), (0, 1, 0, 0), (x, y, w, pad)
        elif outward == 'bottom':
            body_rect, line, grad, shadow_rect = (x, y, w, h - pad), (x, y + h - pad - b, w, b), (0, 0, 0, 1), (x, y + h - pad, w, pad)
        elif outward == 'left':
            body_rect, line, grad, shadow_rect = (x + pad, y, w - pad, h), (x + pad, y, b, h), (1, 0, 0, 0), (x, y, pad, h)
        else:
            body_rect, line, grad, shadow_rect = (x, y, w - pad, h), (x + w - pad - b, y, b, h), (0, 0, 1, 0), (x + w - pad, y, pad, h)
        parts = ''
        if rounded and shadow_alpha > 0:
            gid = f'ro-{prefix}-{name}-shadow'
            defs.append(f'<linearGradient id="{gid}" x1="{grad[0]}" y1="{grad[1]}" x2="{grad[2]}" y2="{grad[3]}">'
                        f'{_shadow_stops(shadow_alpha, 0)}</linearGradient>')
            sx, sy, sw_, sh = shadow_rect
            parts += f'    <rect x="{fmt(sx)}" y="{fmt(sy)}" width="{fmt(sw_)}" height="{fmt(sh)}" fill="url(#{gid})"/>\n'
        else:
            parts += f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" fill-opacity="0"/>\n'
        bx, by, bw, bh = body_rect
        parts += f'    <rect x="{fmt(bx)}" y="{fmt(by)}" width="{fmt(bw)}" height="{fmt(bh)}" fill="{body}" fill-opacity="{body_opacity}"/>\n'
        if rounded:
            lx, ly, lw, lh = line
            parts += f'    <rect x="{fmt(lx)}" y="{fmt(ly)}" width="{fmt(lw)}" height="{fmt(lh)}" fill="{edge}" fill-opacity="{edge_opacity}"/>\n'
        out.append(f'  <g id="{prefix}-{name}">\n{parts}  </g>\n')

    corner('topleft', ox, oy, -1, -1)
    corner('topright', ox + t + e, oy, 1, -1)
    corner('bottomleft', ox, oy + t + e, -1, 1)
    corner('bottomright', ox + t + e, oy + t + e, 1, 1)
    side('top', ox + t, oy, e, t, 'top')
    side('bottom', ox + t, oy + t + e, e, t, 'bottom')
    side('left', ox, oy + t, t, e, 'left')
    side('right', ox + t + e, oy + t, t, e, 'right')
    out.append(f'  <g id="{prefix}-center">\n    <rect x="{fmt(ox + t)}" y="{fmt(oy + t)}" width="{fmt(e)}" height="{fmt(e)}" '
               f'fill="{body}" fill-opacity="{body_opacity}"/>\n  </g>\n')
    return defs, ''.join(out), 2 * t + e

def aurorae_decoration_svg(tokens):
    pad, r = window_shadow, window_radius
    bg = tokens['bg']
    edge = tokens['border']
    shadow_alpha = opacity['windowShadow']
    defs, body, x = [], [], 0
    # Aktif / pasif aynı şekil; pasifte kenarlık ve gölge daha sönük
    for prefix, edge_op, sh in [('decoration', 0.22, shadow_alpha), ('decoration-inactive', 0.12, shadow_alpha * 0.6)]:
        d, b, size = _aurorae_frame(prefix, x, 0, pad, r, bg, 1, edge, edge_op, sh)
        defs += d
        body.append(b)
        x += size + 8
    # Ekranı kaplayan pencere: köşe, gölge, kenarlık yok
    for prefix in ['decoration-maximized', 'decoration-maximized-inactive']:
        d, b, size = _aurorae_frame(prefix, x, 0, 0, 4, bg, 1, edge, 0, 0, rounded=False)
        defs += d
        body.append(b)
        x += size + 8
    total = 2 * (pad + r) + FRAME_EDGE
    defs_block = ('  <defs>\n    ' + '\n    '.join(defs) + '\n  </defs>\n') if defs else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{fmt(x)}" height="{fmt(total)}" viewBox="0 0 {fmt(x)} {fmt(total)}">\n'
            f'  <!-- Ro window decoration: radius {fmt(r)}, border {fmt(window_border)}. Generated by scripts/generate-theme.sh. -->\n'
            + defs_block + ''.join(body) + '</svg>\n')

# Buton simgeleri 24x24 kutuda; durumlar ayrı öğeler (active/hover/pressed/inactive/deactivated + -center)
BUTTON_GLYPHS = {
    'close': 'M 8.5,8.5 15.5,15.5 M 15.5,8.5 8.5,15.5',
    'minimize': 'M 8,12.5 H 16',
    'maximize': 'M 9.5,8 H 14.5 A 1.5,1.5 0 0 1 16,9.5 V 14.5 A 1.5,1.5 0 0 1 14.5,16 H 9.5 A 1.5,1.5 0 0 1 8,14.5 V 9.5 A 1.5,1.5 0 0 1 9.5,8 Z',
    'restore': 'M 10,8 H 15 A 1,1 0 0 1 16,9 V 14 M 8.5,10 H 13 A 1,1 0 0 1 14,11 V 15.5 H 9.5 A 1,1 0 0 1 8.5,14.5 Z',
}

def aurorae_button_svg(kind, tokens):
    size = 24
    text = tokens['text']
    muted = tokens['textSecondary']
    accent = tokens['accent']
    on_accent = tokens.get('selectionText', tokens['bg'])
    glyph = BUTTON_GLYPHS[kind]
    # WD-14 B: kapat üzerine gelince kırmızı (negative), glif güçlü renk üstü metin (selectionText: açıkta beyaz,
    # koyuda koyu; koyu temanın açık kırmızısında beyaz okunmuyor). Diğer düğmeler nötr; vurgu başlığa yayılmaz.
    negative = tokens['negative']
    hover = (negative, 1, on_accent) if kind == 'close' else (text, opacity['hover'], text)
    pressed = (negative, 0.8, on_accent) if kind == 'close' else (text, 0.24, text)
    # WD-06 B: normalde yalnız glif; üzerine gelince yuvarlatılmış kare zemin (köşe radius.titleButton).
    # (öğe öneki, zemin rengi, zemin opaklığı, simge rengi, simge opaklığı)
    states = [
        ('active', text, 0, muted, 1),
        ('hover', hover[0], hover[1], hover[2], 1),
        ('pressed', pressed[0], pressed[1], pressed[2], 1),
        ('deactivated', text, 0, muted, 0.35),
        ('inactive', text, 0, muted, 1),  # WD-11: pasifte de tıklanabilir, sönük değil
        ('hover-inactive', hover[0], hover[1], hover[2], 1),
        ('pressed-inactive', pressed[0], pressed[1], pressed[2], 1),
        ('deactivated-inactive', text, 0, muted, 0.25),
    ]
    out, x = [], 0
    for prefix, circle, circle_op, ink, ink_op in states:
        out.append(f'  <g id="{prefix}-center" transform="translate({x},0)">\n'
                   f'    <rect width="{size}" height="{size}" fill-opacity="0"/>\n'
                   f'    <rect x="1" y="1" width="22" height="22" rx="{fmt(radius["titleButton"])}" fill="{circle}" fill-opacity="{fmt(circle_op)}"/>\n'
                   f'    <path d="{glyph}" fill="none" stroke="{ink}" stroke-opacity="{fmt(ink_op)}" stroke-width="1.6" '
                   f'stroke-linecap="round" stroke-linejoin="round"/>\n  </g>\n')
        x += size + 4
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="{size}" viewBox="0 0 {x} {size}">\n'
            f'  <!-- Ro window button: {kind}. Generated by scripts/generate-theme.sh. -->\n' + ''.join(out) + '</svg>\n')

def aurorae_rc(tokens):
    edge_v = (titlebar_height - title_button) // 2
    lines = [
        '[General]',
        f"ActiveTextColor={rgb(tokens['text'])}",
        f"InactiveTextColor={rgb(tokens['textSecondary'])}",
        'TitleAlignment=Center',
        'TitleVerticalAlignment=Center',
        'UseTextShadow=false',
        f"Animation={motion['fastMs']}",  # WD-20
        '',
        '[Layout]',
        f'PaddingTop={window_shadow}',
        f'PaddingBottom={window_shadow}',
        f'PaddingLeft={window_shadow}',
        f'PaddingRight={window_shadow}',
        f'BorderLeft={window_border}',
        f'BorderRight={window_border}',
        f'BorderBottom={window_border}',
        f'TitleEdgeTop={edge_v}',
        f'TitleEdgeBottom={edge_v}',
        'TitleEdgeLeft=10',
        'TitleEdgeRight=10',
        f'TitleEdgeTopMaximized={edge_v}',
        f'TitleEdgeBottomMaximized={edge_v}',
        'TitleEdgeLeftMaximized=8',
        'TitleEdgeRightMaximized=8',
        'TitleBorderLeft=8',
        'TitleBorderRight=8',
        f'TitleHeight={title_button}',
        f'ButtonWidth={title_button}',
        f'ButtonHeight={title_button}',
        'ButtonSpacing=6',
        'ButtonMarginTop=0',
        'ButtonMarginTopMaximized=0',
        'ExplicitButtonSpacer=8',
    ]
    return '\n'.join(lines) + '\n'

aurorae_modes = {'RoLight': (light, 'Ro Light'), 'RoDark': (dark, 'Ro Dark')}
for theme_name, (tokens, visible_name) in aurorae_modes.items():
    base = root / 'platform/kwin/aurorae' / theme_name
    base.mkdir(parents=True, exist_ok=True)
    metadata = '\n'.join([
        '[Desktop Entry]',
        f'Name={visible_name}',
        f"Name[tr]={visible_name.replace('Light', 'Açık').replace('Dark', 'Koyu')}",
        'Comment=Ro Desktop window decoration',
        f'X-KDE-PluginInfo-Name={theme_name}',
        'X-KDE-PluginInfo-Author=Project Ro-ASD',
        f'X-KDE-PluginInfo-Version={version}',
        'X-KDE-PluginInfo-License=GPL-3.0-or-later',
    ]) + '\n'
    (base / 'metadata.desktop').write_text(metadata, encoding='utf-8')
    (base / f'{theme_name}rc').write_text(aurorae_rc(tokens), encoding='utf-8')
    (base / 'decoration.svg').write_text(aurorae_decoration_svg(tokens), encoding='utf-8')
    for kind in BUTTON_GLYPHS:
        (base / f'{kind}.svg').write_text(aurorae_button_svg(kind, tokens), encoding='utf-8')

# --- Plymouth (16): two-step modülü, Ro animasyonu, görseller ve renkler token'dan (PLY-01 C) ---
import struct, zlib

def write_png(path, w, h, shapes, ss=4):
    """Kenarları yumuşatılmış PNG (RGBA); PIL gerekmez. shapes: [(inside(x, y), (r, g, b))], sonraki üstte."""
    rows = bytearray()
    step = 1 / ss
    offs = [(i + 0.5) * step for i in range(ss)]
    for py in range(h):
        rows.append(0)
        for px in range(w):
            r = g = b = a = 0.0
            for inside, (cr, cg, cb) in shapes:
                hit = sum(1 for oy in offs for ox in offs if inside(px + ox, py + oy))
                cov = hit / (ss * ss)
                if cov:
                    r, g, b = (r * a * (1 - cov) + cr * cov) / (a * (1 - cov) + cov), (g * a * (1 - cov) + cg * cov) / (a * (1 - cov) + cov), (b * a * (1 - cov) + cb * cov) / (a * (1 - cov) + cov)
                    a = a * (1 - cov) + cov
            rows += bytes((round(r), round(g), round(b), round(a * 255)))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')
    path.write_bytes(data)

def rrect(x0, y0, x1, y1, rad):
    def inside(x, y):
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        cx = min(max(x, x0 + rad), x1 - rad)
        cy = min(max(y, y0 + rad), y1 - rad)
        return (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad
    return inside

def polygon(pts):
    def inside(x, y):
        hit = False
        for (ax, ay), (bx, by) in zip(pts, pts[1:] + pts[:1]):
            if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
                hit = not hit
        return hit
    return inside

def rgb_of(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))

ply = root / 'platform/plymouth/ro-theme'
ply.mkdir(parents=True, exist_ok=True)
# Parola alanı: çizgisiz yüzey (00 §4.4), köşe radius.md.
write_png(ply / 'entry.png', 320, 40, [(rrect(0, 0, 320, 40, radius['md']), rgb_of(dark['surface']))])
write_png(ply / 'bullet.png', 10, 10, [(lambda x, y: (x - 5) ** 2 + (y - 5) ** 2 <= 25, rgb_of(dark['text']))])
lock_color = rgb_of(dark['textSecondary'])
write_png(ply / 'lock.png', 34, 34, [
    (lambda x, y: y <= 12 and 25 <= (x - 17) ** 2 + (y - 12) ** 2 <= 64, lock_color),  # halka
    (lambda x, y: 12 <= y <= 16 and (9 <= x <= 12 or 22 <= x <= 25), lock_color),
    (rrect(6, 15, 28, 31, 4), lock_color),
])
caps_color = rgb_of(dark['neutral'])
write_png(ply / 'capslock.png', 24, 28, [
    (polygon([(12, 2), (22, 13), (16, 13), (16, 19), (8, 19), (8, 13), (2, 13)]), caps_color),
    (rrect(8, 22, 16, 26, 1), caps_color),
])

def ply_hex(value):
    return '0x' + value.lstrip('#').lower()

def ply_progress_mode(title):
    return (f'SuppressMessages=true\nProgressBarShowPercentComplete=true\nUseProgressBar=true\n'
            f'Title={title}\nSubTitle=Bilgisayarınızı kapatmayın\n')

(ply / 'ro-theme.plymouth').write_text(f"""[Plymouth Theme]
Name=Ro
Description=Ro boot splash: Ro animation under the firmware logo
ModuleName=two-step

# scripts/generate-theme.sh tarafından üretilir (16 · PLY-01 C). Düzen Fedora spinner temasıyla aynı.
[two-step]
Font=Noto Sans 12
TitleFont=Noto Sans Light 30
ImageDir=/usr/share/plymouth/themes/ro-theme
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.382
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.382
HorizontalAlignment=.5
VerticalAlignment=.75
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.96
Transition=none
TransitionDuration=0.0
BackgroundStartColor={ply_hex(dark['bootBackground'])}
BackgroundEndColor={ply_hex(dark['bootBackground'])}
ProgressBarBackgroundColor={ply_hex(dark['surfaceAlt'])}
ProgressBarForegroundColor={ply_hex(dark['accent'])}
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false
UseFirmwareBackground=true

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=true

[reboot]
UseEndAnimation=false
UseFirmwareBackground=true

[updates]
{ply_progress_mode('Güncellemeler yükleniyor…')}
[system-upgrade]
{ply_progress_mode('Sistem yükseltiliyor…')}
[firmware-upgrade]
{ply_progress_mode('Donanım yazılımı güncelleniyor…')}
[system-reset]
{ply_progress_mode('Sistem sıfırlanıyor…')}""", encoding='utf-8')

# --- GRUB teması (24 · GRUB-01): renkler token'dan; görseller, simgeler ve yazı tipi platform/grub/ro içinde elle üretilmiş sabit dosyalardır ---
grub = root / 'platform/grub/ro'
grub.mkdir(parents=True, exist_ok=True)
(grub / 'theme.txt').write_text(f"""# Ro GRUB teması. scripts/generate-theme.sh tarafından üretilir (24 · GRUB-01..04); renkler core/tokens'dan.
# Arka plan: yapay zekâ üretimi, akan dalga katmanları (bg.jpg). Menüde panel yok; seçili satır yarı saydam vurgu hapı.
title-text: ""
desktop-color: "{dark['bootBackground']}"
desktop-image: "bg.jpg"
desktop-image-scale-method: "stretch"
terminal-font: "Noto Sans Regular 16"

+ boot_menu {{
    left = 5%
    top = 50%-120
    width = 800
    height = 270
    item_font = "Noto Sans Regular 18"
    selected_item_font = "Noto Sans Regular 18"
    item_color = "{dark['textSecondary']}"
    selected_item_color = "{dark['text']}"
    item_height = 32
    item_padding = 0
    item_spacing = 20
    item_icon_space = 14
    icon_width = 32
    icon_height = 32
    item_pixmap_style = "item_*.png"
    selected_item_pixmap_style = "select_*.png"
    scrollbar = false
}}

+ label {{
    left = 5%
    top = 100%-60
    width = 60%
    height = 24
    font = "Noto Sans Regular 16"
    color = "{dark['textSecondary']}"
    text = "Enter: boot     E: edit     C: command line"
}}
""", encoding='utf-8')

PY

echo "generated: token outputs updated"
