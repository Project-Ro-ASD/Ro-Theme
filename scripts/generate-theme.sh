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
spacing = read_json('core/tokens/spacing.json')
dock_radius = spacing['dockHeight'] / 2  # TOK-02d: bağımsız token değil, tam hap geometrisi.

# Yerleşimlerin diğer davranışları kendi dosyalarında kalır; yüksekliklerin tek kaynağı token'dır.
layout_paths = [
    'platform/plasma/layout-templates/org.ro.desktop/contents/layout.js',
    'platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js',
    'platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js',
]
for path in layout_paths:
    layout_path = root / path
    layout = layout_path.read_text(encoding='utf-8')
    for panel, token in [('top', 'panelHeight'), ('dock', 'dockHeight')]:
        pattern = rf'(?m)^(\s*{panel}\.height\s*=\s*)[0-9]+(?:\.[0-9]+)?(\s*;[^\n]*)$'
        layout, count = re.subn(pattern, lambda m: f'{m[1]}{spacing[token]}{m[2]}', layout)
        if count != 1:
            raise SystemExit(f'{path}: expected exactly one {panel}.height assignment, found {count}')
    layout_path.write_text(layout, encoding='utf-8')

for path in [
    'platform/plasma/color-schemes',
    'platform/gtk/Ro-GTK/gtk-3.0',
    'platform/gtk/Ro-GTK/gtk-4.0',
    'platform/plasma/desktoptheme/RoLight',
    'platform/plasma/desktoptheme/RoDark',
    'platform/plasma/look-and-feel/org.ro.light/contents/layouts',
    'platform/plasma/look-and-feel/org.ro.dark/contents/layouts',
    'platform/kwin/effects/ro-smooth-motion/contents/code',
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
  --ro-radius-dock: {dock_radius:g}px;
  --ro-space-xs: {spacing['xs']}px;
  --ro-space-sm: {spacing['sm']}px;
  --ro-space-md: {spacing['md']}px;
  --ro-space-lg: {spacing['lg']}px;
  --ro-space-xl: {spacing['xl']}px;
  --ro-panel-height: {spacing['panelHeight']}px;
  --ro-dock-height: {spacing['dockHeight']}px;
  --ro-dock-icon-size: {spacing['dockIconSize']}px;
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
            'borderRadius': {**radius, 'dock': dock_radius},
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
    'pragma Singleton\n'
    'import QtQuick\n\n'
    '// Ro tasarım token\'ları (QML). scripts/generate-theme.sh tarafından core/tokens\'tan ÜRETİLİR, elle düzenlenmez.\n'
    '// Kullanım: widget paketine bu dosyayı kopyala ve qmldir\'e şunu ekle: singleton RoTokens 1.0 RoTokens.qml\n'
    '// Renkler bu dosyada yok: Kirigami.Theme kullan, böylece her renk şemasıyla uyumlu kalır.\n'
    '// Süreler taban değerdir (ms); Plasma animasyon hızı çarpanını (AnimationDurationFactor) uygulamak widget\'ın işidir.\n'
    'QtObject {\n'
    + _qml_props('radius', {**radius, 'dock': dock_radius}) + '\n'
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
def color_scheme(theme_id, tokens, dark_mode):
    accent = tokens['accent']
    bg = tokens['bg']
    bg_alt = tokens['bgAlt']
    surface = tokens['surface']
    surface_alt = tokens['surfaceAlt']
    # Ayrıntılı görünümdeki çizgili satır (View BackgroundAlternate): iki temada da yüzey ile ikinci yüzey
    # arasının yarısı (Ro-Theme-Docs 02 COL-15f; ~1.10 satır ayrımı). bgAlt kullanılmaz: koyu temada surface ile
    # aynı renkti, zebra kayboluyordu.
    view_alt = mix_hex(surface_alt, surface, 0.5)
    text = tokens['text']
    text_secondary = tokens['textSecondary']
    border = tokens['border']

    hover = mix_hex(accent, surface, 0.26 if dark_mode else 0.34)
    link = token_color(tokens, 'link', accent)
    visited = token_color(tokens, 'visited', text_secondary)
    negative = token_color(tokens, 'negative', text)
    neutral = token_color(tokens, 'neutral', text_secondary)
    positive = token_color(tokens, 'positive', accent)
    selection_text = token_color(tokens, 'selectionText', bg if dark_mode else text)
    button_bg = surface_alt
    button_alt = surface
    inactive_blend = mix_hex(border, bg, 0.72)
    header_bg = mix_hex(surface_alt, bg, 0.72)
    header_alt = mix_hex(surface, bg, 0.82)
    # KDE lock screen WallpaperFader uses the Complementary background to decide
    # whether to brighten or dim the wallpaper behind the password prompt. Ro Light
    # keeps normal app surfaces light, but uses a dark complementary surface so the
    # lock screen stays readable without washing out the wallpaper.
    if dark_mode:
        complementary_bg = surface
        complementary_alt = surface_alt
        complementary_text = text
        complementary_secondary = text_secondary
    else:
        complementary_bg = text
        complementary_alt = text_secondary
        complementary_text = bg
        complementary_secondary = border

    def group(name, normal_bg, alternate_bg, normal_fg, inactive_fg, include_active=True):
        active_line = f'ForegroundActive={rgb(accent)}\n' if include_active else ''
        return f'''[{name}]
BackgroundNormal={rgb(normal_bg)}
BackgroundAlternate={rgb(alternate_bg)}
ForegroundNormal={rgb(normal_fg)}
ForegroundInactive={rgb(inactive_fg)}
{active_line}ForegroundLink={rgb(link)}
ForegroundVisited={rgb(visited)}
ForegroundNegative={rgb(negative)}
ForegroundNeutral={rgb(neutral)}
ForegroundPositive={rgb(positive)}
DecorationFocus={rgb(accent)}
DecorationHover={rgb(hover)}
'''

    return f'''[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[General]
Name={theme_id}
ColorScheme={theme_id}
shadeSortColumn=true

{group('Colors:Window', bg, bg_alt, text, text_secondary)}
{group('Colors:View', surface, view_alt, text, text_secondary)}
{group('Colors:Button', button_bg, button_alt, text, text_secondary)}
{group('Colors:Tooltip', surface, surface_alt, text, text_secondary)}
{group('Colors:Header', header_bg, header_alt, text, text_secondary)}
{group('Colors:Header][Inactive', bg_alt, header_bg, text_secondary, text_secondary)}
{group('Colors:Complementary', complementary_bg, complementary_alt, complementary_text, complementary_secondary)}

[Colors:Selection]
BackgroundNormal={rgb(accent)}
BackgroundAlternate={rgb(hover)}
ForegroundActive={rgb(selection_text)}
ForegroundInactive={rgb(text_secondary)}
ForegroundLink={rgb(link)}
ForegroundVisited={rgb(visited)}
ForegroundNegative={rgb(negative)}
ForegroundNeutral={rgb(neutral)}
ForegroundPositive={rgb(positive)}
ForegroundNormal={rgb(selection_text)}
DecorationFocus={rgb(accent)}
DecorationHover={rgb(accent)}

[KDE]
ColorScheme={theme_id}
contrast=4

[WM]
activeBackground={rgb(surface)}
activeForeground={rgb(text)}
inactiveBackground={rgb(bg_alt)}
inactiveForeground={rgb(text_secondary)}
activeBlend={rgb(accent)}
inactiveBlend={rgb(inactive_blend)}
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

XDG_HEADER = '# Ro-ASD system defaults. Generated from core/tokens by scripts/generate-theme.sh.\n# Packaged as %config(noreplace); user settings in ~/.config always take precedence.\n'
default_scheme = 'RoDark'
kdeglobals = ini_groups(color_scheme(default_scheme, dark, True))
kdeglobals['[General]'] = [l for l in kdeglobals.get('[General]', []) if not l.startswith('Name=')]
# [KDE] ColorScheme eski bir yedek anahtar; eski %post bunu /etc/xdg'den siliyordu. Yazılmaz.
kdeglobals['[KDE]'] = [l for l in kdeglobals.get('[KDE]', []) if not l.startswith('ColorScheme=')]
set_key(kdeglobals, '[General]', 'ColorScheme', default_scheme)
set_key(kdeglobals, '[KDE]', 'LookAndFeelPackage', 'org.ro.dark')
set_key(kdeglobals, '[KDE]', 'widgetStyle', 'Breeze')
lock_wallpaper = 'file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg'
xdg_defaults = {
    'kdeglobals': kdeglobals,
    'plasmarc': {'[Theme]': ['name=RoDark']},
    'ksplashrc': {'[KSplash]': ['Engine=KSplashQML', 'Theme=org.ro.dark']},
    'kscreenlockerrc': {
        '[Greeter]': ['WallpaperPlugin=org.kde.image'],
        '[Greeter][Wallpaper][org.kde.image][General]': [f'Image={lock_wallpaper}', f'PreviewImage={lock_wallpaper}', 'Blur=false'],
    },
    # Plasma 5 kimlikli kwin4_effect_* satırları etkisiz olduğu için yazılmaz (FX-23).
    'kwinrc': {
        '[org.kde.kdecoration2]': ['library=org.kde.breeze', 'theme=Breeze'],
        '[Plugins]': ['ro-smooth-motionEnabled=false', 'magiclampEnabled=false'],
    },
}
xdg_dir = root / 'platform/plasma/defaults/xdg'
xdg_dir.mkdir(parents=True, exist_ok=True)
for name, groups in xdg_defaults.items():
    (xdg_dir / name).write_text(XDG_HEADER + '\n' + ini_text(groups), encoding='utf-8')

# Saklanan paletler (core/tokens/palettes/<ad>.light|dark.json) ayrı renk şeması olarak üretilir:
# karşılaştırma ve geri dönüş için. Ad: Ro<Ad>Light / Ro<Ad>Dark (ör. cool -> RoCoolLight).
saved_palettes = []
for light_path in sorted((root / 'core/tokens/palettes').glob('*.light.json')):
    pal = light_path.name[:-len('.light.json')]
    dark_path = light_path.with_name(f'{pal}.dark.json')
    if not dark_path.exists():
        raise SystemExit(f'palette {pal}: {dark_path} missing')
    base_id = 'Ro' + ''.join(part.capitalize() for part in pal.replace('_', '-').split('-'))
    for mode_path, suffix, is_dark in [(light_path, 'Light', False), (dark_path, 'Dark', True)]:
        theme_id = base_id + suffix
        (root / 'platform/plasma/color-schemes' / f'{theme_id}.colors').write_text(
            color_scheme(theme_id, json.loads(mode_path.read_text(encoding='utf-8')), is_dark), encoding='utf-8')
        saved_palettes.append(theme_id)

# Plasma çerçeve SVG'si (FrameSvg / 9 parça kuralı):
# - topleft/top/topright/left/center/right/bottomleft/bottom/bottomright öğeleri ayrı parçalardır.
#   Köşeler olduğu gibi çizilir, kenarlar ve orta esnetilir; köşe yuvarlaklığı köşe parçasının şeklidir,
#   bu yüzden köşe parçası (ve ona bitişik kenar kalınlığı) yarıçap kadar büyüktür.
# - hint-*-margin öğelerinin boyutu içeriğin çerçeveden ne kadar içeride duracağını belirler.
# - shadow-* öğeleri KWin gölgesidir; shadow-hint-*-margin gölgenin pencere dışına taşma miktarıdır.
# - Kenarlık stroke ile değil, yüzeyin üstüne dolgulu halka olarak çizilir: stroke parçaların
#   birleştiği yerde "L" izleri bırakıyordu (validate.sh stroke'u yasaklıyor).
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
    return (f'  <g id="{name}">\n'
            f'    <path d="{surface}" fill="{fill}" fill-opacity="{fill_opacity}"/>\n'
            f'    <path d="{ring}" fill="{border}" fill-opacity="{border_opacity}"/>\n'
            f'  </g>\n')

def _edge(name, x, y, w, h, outer, fill, fill_opacity, border, border_opacity):
    # outer: kenarlığın bulunduğu dış taraf (top/bottom/left/right) ya da None (orta parça)
    b = FRAME_BORDER
    line = {
        'top': (x, y, w, b), 'bottom': (x, y + h - b, w, b),
        'left': (x, y, b, h), 'right': (x + w - b, y, b, h),
    }.get(outer)
    out = (f'  <g id="{name}">\n'
           f'    <rect x="{fmt(x)}" y="{fmt(y)}" width="{fmt(w)}" height="{fmt(h)}" fill="{fill}" fill-opacity="{fill_opacity}"/>\n')
    if line:
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
    'RoLight': (light['surface'], rgba_opacity(light.get('glass'), '0.76'), light['border'], '0.58'),
    'RoDark': (dark['surface'], rgba_opacity(dark.get('glass'), '0.58'), dark['textSecondary'], '0.28'),
}
popup_radius = radius.get('popup', radius['lg'])
widget_radius = radius.get('widget', radius['lg'])
popup_padding = spacing.get('popupPadding', spacing['sm'])
popup_shadow = None  # TOK-09/10: katman ayrımı yüzey ve kenarlıkla yapılır.
solid_opacity = opacity.get('solid', 1.0)
for theme_name, (fill, alpha, stroke, stroke_alpha) in plasma_modes.items():
    base = root / 'platform/plasma/desktoptheme' / theme_name
    outputs = {
        # Popup'lar: normal (compositing açık), translucent (bulanıklık var), solid (compositing kapalı → opak)
        'dialogs/background.svg': plasma_frame_svg(fill, alpha, stroke, stroke_alpha, popup_radius, popup_padding, popup_shadow),
        'translucent/dialogs/background.svg': plasma_frame_svg(fill, alpha, stroke, stroke_alpha, popup_radius, popup_padding, popup_shadow),
        'solid/dialogs/background.svg': plasma_frame_svg(fill, solid_opacity, stroke, stroke_alpha, popup_radius, popup_padding, popup_shadow),
        'widgets/background.svg': plasma_frame_svg(fill, alpha, stroke, stroke_alpha, widget_radius, popup_padding),
        # NOT: Plasma paneli widgets/panel-background'dan okur; bu dosya şu an kullanılmıyor (yol haritası Faz 3).
        'panel/panel-background.svg': plasma_frame_svg(fill, alpha, stroke, stroke_alpha, radius['panel'], popup_padding),
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
    # AdaptiveTransparency kapalı: açıkken ekranda büyütülmüş pencere olduğunda Plasma popup'ları
    # tamamen opak çiziyor ve buzlu cam (yarı saydam yüzey + KWin blur) hiç görünmüyordu.
    (root / 'platform/plasma/desktoptheme' / theme_name / 'plasmarc').write_text('''[ContrastEffect]
enabled=true
contrast=0.35
saturation=1.05

[AdaptiveTransparency]
enabled=false
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
window_radius = radius.get('window', radius['md'])
window_border = spacing.get('windowBorder', 4)
titlebar_height = spacing.get('titlebarHeight', 36)
title_button = spacing.get('titleButton', 24)
window_shadow = 0  # TOK-09/10: Aurorae dış gölge boşluğu yok.
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
    shadow_alpha = 0
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
    # Hover nötr; sadece kapat düğmesi vurgu rengini kullanır
    hover = (accent, 1, on_accent) if kind == 'close' else (text, opacity['hover'], text)
    pressed = (accent, 0.8, on_accent) if kind == 'close' else (text, 0.24, text)
    # (öğe öneki, daire rengi, daire opaklığı, simge rengi, simge opaklığı)
    states = [
        ('active', text, 0, muted, 1),
        ('hover', hover[0], hover[1], hover[2], 1),
        ('pressed', pressed[0], pressed[1], pressed[2], 1),
        ('deactivated', text, 0, muted, 0.35),
        ('inactive', text, 0, muted, 0.55),
        ('hover-inactive', hover[0], hover[1], hover[2], 1),
        ('pressed-inactive', pressed[0], pressed[1], pressed[2], 1),
        ('deactivated-inactive', text, 0, muted, 0.25),
    ]
    out, x = [], 0
    for prefix, circle, circle_op, ink, ink_op in states:
        out.append(f'  <g id="{prefix}-center" transform="translate({x},0)">\n'
                   f'    <rect width="{size}" height="{size}" fill-opacity="0"/>\n'
                   f'    <circle cx="12" cy="12" r="11" fill="{circle}" fill-opacity="{fmt(circle_op)}"/>\n'
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
        f"Animation={motion.get('windowCloseMs', 150)}",
        '',
        '[Layout]',
        f'PaddingTop={window_shadow}',
        f'PaddingBottom={window_shadow}',
        f'PaddingLeft={window_shadow}',
        f'PaddingRight={window_shadow}',
        f'BorderLeft={window_border}',
        f'BorderRight={window_border}',
        f'BorderBottom={window_border}',
        'BorderLeftMaximized=0',
        'BorderRightMaximized=0',
        'BorderBottomMaximized=0',
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

# --- KWin efekti: süreler motion tokenlarından gelir ---
kwin_js = f'''"use strict";

// Ro Smooth Motion
// Motion constants are generated from core/tokens/motion.json by scripts/generate-theme.sh.
// Bounce, shake, squash and magic-lamp movements are intentionally avoided.

const OPEN_MS = {int(motion['windowOpenMs'])};
const CLOSE_MS = {int(motion['windowCloseMs'])};
const MINIMIZE_MS = {int(motion['windowMinimizeMs'])};

class RoSmoothMotion {{
    constructor() {{
        effects.windowAdded.connect(this.open.bind(this));
        effects.windowClosed.connect(this.close.bind(this));

        // Plasma/KWin sürüm farkları için iki minimize sinyali de desteklenir.
        if (effects.windowMinimized) {{
            effects.windowMinimized.connect(this.minimize.bind(this));
            effects.windowUnminimized.connect(this.unminimize.bind(this));
        }} else if (effects.windowMinimizeStateChanged) {{
            effects.windowMinimizeStateChanged.connect((w) => {{
                if (w.minimized) this.minimize(w);
                else this.unminimize(w);
            }});
        }}
    }}

    // Popup, desktop, fullscreen ve özel pencereler filtrelenir.
    animatable(w) {{
        if (!w) return false;
        if (w.deleted || w.popupWindow || w.specialWindow || w.desktopWindow) return false;
        if (w.fullScreen || !w.managed) return false;
        return !!(w.normalWindow || w.dialog);
    }}

    open(w) {{
        if (effects.hasActiveFullScreenEffect || !this.animatable(w) || !w.visible) return;
        animate({{
            window: w,
            duration: OPEN_MS,
            curve: QEasingCurve.OutCubic,
            animations: [
                {{ type: Effect.Opacity, from: 0.0, to: 1.0 }}
            ]
        }});
    }}

    close(w) {{
        if (effects.hasActiveFullScreenEffect || !this.animatable(w)) return;
        if (!w.visible || w.skipsCloseAnimation) return;
        animate({{
            window: w,
            duration: CLOSE_MS,
            curve: QEasingCurve.InCubic,
            animations: [
                {{ type: Effect.Opacity, from: 1.0, to: 0.0 }}
            ]
        }});
    }}

    minimize(w) {{
        if (!this.animatable(w)) return;
        animate({{
            window: w,
            duration: MINIMIZE_MS,
            curve: QEasingCurve.InOutCubic,
            animations: [
                {{ type: Effect.Opacity, from: 1.0, to: 0.0 }}
            ]
        }});
    }}

    unminimize(w) {{
        if (!this.animatable(w)) return;
        animate({{
            window: w,
            duration: OPEN_MS,
            curve: QEasingCurve.OutCubic,
            animations: [
                {{ type: Effect.Opacity, from: 0.0, to: 1.0 }}
            ]
        }});
    }}
}}

new RoSmoothMotion();
'''
(root / 'platform/kwin/effects/ro-smooth-motion/contents/code/main.js').write_text(kwin_js, encoding='utf-8')
PY

echo "generated: token outputs updated"
