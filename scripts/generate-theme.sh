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

root = Path('.')

def read_json(path):
    return json.loads((root / path).read_text(encoding='utf-8'))

light = read_json('core/tokens/colors.light.json')
dark = read_json('core/tokens/colors.dark.json')
motion = read_json('core/tokens/motion.json')
radius = read_json('core/tokens/radius.json')
opacity = read_json('core/tokens/opacity.json')
spacing = read_json('core/tokens/spacing.json')

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
  --ro-radius-dock: {radius['dock']}px;
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

def color_scheme(theme_id, tokens, dark_mode):
    accent = tokens['accent']
    bg = tokens['bg']
    bg_alt = tokens['bgAlt']
    surface = tokens['surface']
    surface_alt = tokens['surfaceAlt']
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
    complementary_bg = surface
    complementary_alt = surface_alt
    complementary_text = text
    complementary_secondary = text_secondary

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
ChangeSelectionColor=true
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
{group('Colors:View', surface, bg_alt, text, text_secondary)}
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

def plasma_svg(fill, fill_opacity, stroke, stroke_opacity):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <!-- Ro glass surface. Generated from core/tokens by scripts/generate-theme.sh. -->
  <!-- Plasma bu SVG'yi 9 parçaya böler; köşe stroke'ları popup üzerinde küçük L izleri bırakabildiği için yüzey stroke'suzdur. -->
  <g id="center">
    <rect x="8" y="8" width="32" height="32" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="top">
    <rect x="8" y="0" width="32" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="bottom">
    <rect x="8" y="40" width="32" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="left">
    <rect x="0" y="8" width="8" height="32" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="right">
    <rect x="40" y="8" width="8" height="32" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="topleft">
    <rect x="0" y="0" width="8" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="topright">
    <rect x="40" y="0" width="8" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="bottomleft">
    <rect x="0" y="40" width="8" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <g id="bottomright">
    <rect x="40" y="40" width="8" height="8" fill="{fill}" fill-opacity="{fill_opacity}"/>
  </g>
  <rect id="hint-stretch-borders" x="0" y="0" width="1" height="1" fill="#000000" fill-opacity="0"/>
</svg>
'''

plasma_modes = {
    'RoLight': (light['surface'], rgba_opacity(light.get('glass'), '0.76'), light['border'], '0.58'),
    'RoDark': (dark['surface'], rgba_opacity(dark.get('glass'), '0.58'), dark['textSecondary'], '0.28'),
}
for theme_name, (fill, alpha, stroke, stroke_alpha) in plasma_modes.items():
    for rel in ['panel/panel-background.svg', 'widgets/background.svg', 'dialogs/background.svg']:
        out = root / 'platform/plasma/desktoptheme' / theme_name / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(plasma_svg(fill, alpha, stroke, stroke_alpha), encoding='utf-8')

desktop_theme_colors = {
    'RoLight': color_scheme('RoLight', light, False),
    'RoDark': color_scheme('RoDark', dark, True),
}
for theme_name, content in desktop_theme_colors.items():
    (root / 'platform/plasma/desktoptheme' / theme_name / 'colors').write_text(content, encoding='utf-8')
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
  border-radius: 10px;
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
  border-bottom: 1px solid @ro_border;
}}

button {{
  background: @ro_surface_alt;
  color: @ro_text;
  border: 1px solid @ro_border;
  padding: 7px 12px;
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
  border: 1px solid @ro_border;
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
