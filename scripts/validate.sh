#!/usr/bin/env bash
set -euo pipefail

# Ro doğrulama scripti
# Kurulum ve RPM build öncesi eksik dosya, bozuk JSON, uyumsuz global theme
# varsayılanı ve stale iç kopya gibi paketleme hatalarını görünür yapar.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

errors=0
warnings=0

section() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf '  [OK] %s\n' "$1"
}

warn() {
  printf '  [WARN] %s\n' "$1" >&2
  warnings=$((warnings + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  errors=$((errors + 1))
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    ok "$path"
  else
    fail "missing file: $path"
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    ok "$path"
  else
    fail "missing directory: $path"
  fi
}

check_absent_file() {
  local path="$1"
  local label="$2"

  if [[ -e "$path" ]]; then
    fail "$label still exists: $path"
  else
    ok "$label absent"
  fi
}

check_exec() {
  local path="$1"
  check_file "$path"
  if [[ -f "$path" && ! -x "$path" ]]; then
    fail "not executable: $path"
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    fail "cannot inspect missing file: $path"
    return
  fi

  if grep -Fq -- "$pattern" "$path"; then
    ok "$label"
  else
    fail "$label missing pattern: $pattern"
  fi
}

check_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    fail "cannot inspect missing file: $path"
    return
  fi

  if grep -Fq -- "$pattern" "$path"; then
    fail "$label contains forbidden pattern: $pattern"
  else
    ok "$label"
  fi
}

check_kde_group_without_color_scheme() {
  local path="$1"
  local label="$2"

  if [[ ! -f "$path" ]]; then
    fail "cannot inspect missing file: $path"
    return
  fi

  if awk '
    /^\[kdeglobals\]\[KDE\]$/ { in_group = 1; next }
    /^\[/ { in_group = 0 }
    in_group && /^ColorScheme=/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$path"; then
    fail "$label contains obsolete [kdeglobals][KDE] ColorScheme"
  else
    ok "$label has no obsolete [kdeglobals][KDE] ColorScheme"
  fi
}

check_json() {
  local path="$1"
  check_file "$path"
  if [[ ! -f "$path" ]]; then
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$path" >/dev/null 2>&1; then
      ok "valid JSON: $path"
    else
      fail "invalid JSON: $path"
    fi
  else
    warn "python3 not found; JSON syntax skipped for $path"
  fi
}

check_shell() {
  local path="$1"
  check_exec "$path"
  if [[ -f "$path" ]]; then
    if bash -n "$path"; then
      ok "valid shell syntax: $path"
    else
      fail "invalid shell syntax: $path"
    fi
  fi
}

check_scheme_contrast() {
  # Her renk setinde (Colors:*) metin rolleri kendi normal ve ikinci zemininde >= 4.5:1
  # (COL-14, COL-15, COL-17, COL-18, COL-28)
  local path="$1"
  local report
  if ! report="$(python3 - "$path" <<'PY'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
def lum(c):
    c = [x / 255 for x in c]; c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True); return (la + 0.05) / (lb + 0.05)
bad = []
for group, body in re.findall(r'\[(Colors:[^\n]*)\]\n(.*?)(?=\n\n|\n\[|\Z)', s, re.S):
    d = {k: tuple(map(int, v.split(','))) for k, v in (l.split('=', 1) for l in body.splitlines() if '=' in l)}
    for bg in ['BackgroundNormal', 'BackgroundAlternate']:
        for k, v in d.items():
            if k.startswith('Foreground') and ratio(v, d[bg]) < 4.5:
                bad.append(f'{group} {k} on {bg} {ratio(v, d[bg]):.2f}')
print('; '.join(bad)); sys.exit(1 if bad else 0)
PY
)"; then
    fail "$path set contrast: $report"
  else
    ok "$path every color set readable (WCAG AA)"
  fi
}

check_global_theme() {
  local package="$1"
  local look="$2"
  local scheme="$3"
  local plasma="$4"
  local defaults="platform/plasma/look-and-feel/$package/contents/defaults"

  check_file "$defaults"
  check_json "platform/plasma/look-and-feel/$package/metadata.json"
  check_file "platform/plasma/look-and-feel/$package/contents/splash/Splash.qml"
  check_file "platform/plasma/look-and-feel/$package/contents/splash/login.jpg"
  check_file "platform/plasma/look-and-feel/$package/contents/splash/login-blur.jpg"
  check_absent_file "platform/plasma/look-and-feel/$package/contents/lockscreen/LockScreen.qml" "$package unsafe custom lockscreen override"
  check_file "platform/plasma/look-and-feel/$package/contents/lockscreen/assets/login.jpg"
  check_contains "platform/plasma/look-and-feel/$package/contents/splash/Splash.qml" "property int stage" "$package stage-aware splash"
  check_not_contains "$defaults" "LookAndFeelPackage=" "$package does not write its own id (GT-04l)"
  check_contains "$defaults" "[ksplashrc][KSplash]" "$package splash group with file prefix (GT-04i)"
  check_contains "platform/plasma/look-and-feel/$package/metadata.json" "\"Name[tr]\"" "$package Turkish name (GT-07)"
  check_file "platform/plasma/look-and-feel/$package/contents/previews/preview.png"
  check_file "platform/plasma/look-and-feel/$package/contents/previews/fullscreenpreview.jpg"
  check_contains "$defaults" "ColorScheme=$scheme" "$package ColorScheme"
  check_kde_group_without_color_scheme "$defaults" "$package defaults"
  check_contains "$defaults" "name=$plasma" "$package Plasma style"
  check_contains "$defaults" "Engine=KSplashQML" "$package KSplash engine"
  check_contains "$defaults" "Theme=$look" "$package KSplash theme"
  check_contains "$defaults" "library=org.kde.kwin.aurorae.v2" "$package Ro Aurorae decoration library (WD-02/03)"
  check_contains "$defaults" "theme=__aurorae__svg__$scheme" "$package Ro Aurorae decoration theme"
  check_not_contains "$defaults" "[kwinrc][Plugins]" "$package leaves KWin effects at KDE defaults (FX-02/23)"
}

check_plasma_surface_svg() {
  local path="$1"
  local label="$2"

  check_file "$path"
  check_contains "$path" '<g id="center">' "$label seam-safe center group"
  check_not_contains "$path" '<rect id="center"' "$label has no stroked center rect"
  check_not_contains "$path" 'stroke=' "$label has no corner stroke artefact"
}

check_token_contrast() {
  # WCAG 2.x: metin ve anlamsal renkler zeminde >= 4.5:1, seçim metni vurgu renginde >= 4.5:1
  local path="$1"
  local label="$2"
  local report
  if ! report="$(python3 - "$path" <<'PY'
import json, sys
t = json.load(open(sys.argv[1], encoding='utf-8'))
def lum(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True); return (la + 0.05) / (lb + 0.05)
bad = []
for fg in ['text', 'textSecondary', 'accent', 'link', 'negative', 'neutral', 'positive']:
    for bg in ['bg', 'surface']:
        r = ratio(t[fg], t[bg])
        if r < 4.5: bad.append(f'{fg} on {bg} {r:.2f}')
r = ratio(t['selectionText'], t['accent'])
if r < 4.5: bad.append(f'selectionText on accent {r:.2f}')
for k, c in t['selection'].items():
    r = ratio(c, t['accent'])
    if r < 4.5: bad.append(f'selection.{k} on accent {r:.2f}')
if len({t['negative'], t['neutral'], t['positive'], t['link'], t['visited'], t['text']}) < 6: bad.append('semantic colors not distinct')
# Kontrol kenarlığı (etkileşimli öğe sınırı) zemin ve yüzeyde >= 3:1 (COL-16, COL-28)
for bg in ['bg', 'surface']:
    r = ratio(t['controlBorder'], t[bg])
    if r < 3.0: bad.append(f'controlBorder on {bg} {r:.2f}')
# Vurgu tonu logo laciverti tonunda: 219 ± 6 derece (COL-04, COL-28)
import colorsys
h = t['accent'].lstrip('#'); hue = colorsys.rgb_to_hls(*[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])[0] * 360
if abs(hue - 219) > 6: bad.append(f'accent hue {hue:.0f} not 219+-6')
# Nötr yüzeyler gri: max(R,G,B) - min(R,G,B) <= 12 (COL-28)
for k in ['bg', 'surface', 'surfaceAlt', 'border']:
    h = t[k].lstrip('#'); c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if max(c) - min(c) > 12: bad.append(f'{k} not neutral gray')
print('; '.join(bad)); sys.exit(1 if bad else 0)
PY
)"; then
    fail "$label token contrast: $report"
  else
    ok "$label token contrast (WCAG AA)"
  fi
}

check_token_geometry() {
  # TOK-03/05/07: iç öğeler popup'a sığmalı; uygulama köşeleri Aurorae çerçevesinin altında kalmalı.
  local report
  if ! report="$(python3 - <<'PY'
import json, math, re, sys
from pathlib import Path

radius = json.loads(Path('core/tokens/radius.json').read_text())
spacing = json.loads(Path('core/tokens/spacing.json').read_text())
opacity = json.loads(Path('core/tokens/opacity.json').read_text())
errors = []

def positive(values, key):
    value = values[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ValueError(f'{key} must be a finite positive number')
    return value

try:
    # 07 PAN-01 B: dock yok, tek bar (spacing.panelHeight); TOK-09/10: popup gölgesi yok.
    for values, key in [(radius, 'dock'), (spacing, 'dockHeight'), (spacing, 'dockIconSize'), (spacing, 'shadowSize'), (opacity, 'shadow')]:
        if key in values:
            errors.append(f'obsolete token {key} (no dock since PAN-01 B; no popup shadows, TOK-09/10)')
    minimum = positive(radius, 'sm')
    popup = positive(radius, 'popup')
    padding = positive(spacing, 'popupPadding')
    maximum = popup - padding / 2
    # Tam daireler ve bağımsız widget yüzeyleri iç öğe değildir (TOK-02/03).
    for key in ['sm', 'md']:
        inner = positive(radius, key)
        if not minimum <= inner <= maximum:
            errors.append(f'radius.{key} ({inner}) must be between radius.sm ({minimum}) and radius.popup - popupPadding/2 ({maximum})')
    if padding < 0.3 * popup:
        errors.append(f'popupPadding ({padding}) must be >= 0.3 * radius.popup ({popup})')
    window = positive(radius, 'window')
    border = positive(spacing, 'windowBorder')
    if border < 0.3 * window:
        errors.append(f'windowBorder ({border}) must be >= 0.3 * radius.window ({window})')
    frame_border = positive(spacing, 'borderWidth')
    if frame_border >= min(popup, positive(radius, 'widget'), positive(radius, 'panel'), window):
        errors.append('borderWidth must be smaller than each frame radius')
    hover = positive(opacity, 'hover')
    if not 0.08 <= hover <= 0.14:
        errors.append(f'opacity.hover ({hover}) must be a neutral overlay intensity between 0.08 and 0.14')
    for path in ('dist/tokens/ro-colors.css', 'dist/qml/RoTokens.qml', 'dist/tokens/ro-tailwind.js'):
        if re.search(r'(?i)dock', Path(path).read_text()):
            errors.append(f'{path} still exports dock tokens; run scripts/generate-theme.sh')

    paths = [
        Path('platform/plasma/layout-templates/org.ro.desktop/contents/layout.js'),
        *Path('platform/plasma/look-and-feel').glob('org.ro.*/contents/layouts/org.kde.plasma.desktop-layout.js'),
    ]
    for path in paths:
        layout = path.read_text()
        expected = positive(spacing, 'panelHeight')
        heights = re.findall(r'(?m)^\s*bar\.height\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*;', layout)
        if len(heights) != 1 or float(heights[0]) != expected:
            errors.append(f'{path}: bar.height must match spacing.panelHeight ({expected}); run scripts/generate-theme.sh')
except (KeyError, ValueError, OSError) as error:
    errors.append(str(error))

print('; '.join(errors))
sys.exit(1 if errors else 0)
PY
)"; then
    fail "token geometry and layout: $report"
  else
    ok "token geometry, neutral hover and generated panel height"
  fi
}

check_plasma_scrollbar_svg() {
  # PST-19: kaydırma çubuğu (hap tutamak, inset ipucu yok), stroke ve sabit renk yok, hint-scrollbar-size var.
  local path="$1"
  local label="$2"
  local report
  if ! report="$(python3 - "$path" <<'PY'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
bad = []
if '<stroke' in s or ' stroke=' in s: bad.append('stroke used')
if re.search(r'fill="#', s): bad.append('hard-coded fill color')
if 'id="hint-scrollbar-size"' not in s: bad.append('no hint-scrollbar-size')
for p in ('slider', 'mouseover-slider', 'background-vertical', 'background-horizontal'):
    for part in ('topleft', 'top', 'topright', 'left', 'center', 'right', 'bottomleft', 'bottom', 'bottomright'):
        if f'<g id="{p}-{part}">' not in s: bad.append(f'{p}-{part} missing')
print('; '.join(bad)); sys.exit(1 if bad else 0)
PY
)"; then
    fail "$label: $report"
  else
    ok "$label (pill handle, scheme classes, no stroke)"
  fi
}

check_plasma_indicator_svg() {
  # PST-20: onay işareti, radyo, anahtar; gerekli öğeler var, stroke ve sabit renk yok.
  local path="$1"
  local label="$2"
  local ids="$3"
  local report
  if ! report="$(python3 - "$path" "$ids" <<'PY'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
bad = []
if '<stroke' in s or ' stroke=' in s: bad.append('stroke used')
if re.search(r'fill="#', s): bad.append('hard-coded fill color')
for i in sys.argv[2].split():
    if f'id="{i}"' not in s: bad.append(f'{i} missing')
print('; '.join(bad)); sys.exit(1 if bad else 0)
PY
)"; then
    fail "$label: $report"
  else
    ok "$label (Ro-drawn, scheme classes, no stroke)"
  fi
}

check_plasma_control_svg() {
  # Ro'nun çizdiği kabuk kontrolleri (03 PST-22/23/26): her durum 9 parça, stroke yok, iç boşluk ipuçları,
  # renkler ColorScheme-* sınıflarından (PST-03; sabit fill hex yok), köşe token'dan (radius.md).
  local path="$1"
  local label="$2"
  local report
  if ! report="$(python3 - "$path" <<'PY'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
bad = []
if '<stroke' in s or ' stroke=' in s: bad.append('stroke used')
if re.search(r'fill="#', s): bad.append('hard-coded fill color')
if 'id="current-color-scheme"' not in s: bad.append('no current-color-scheme style')
prefixes = sorted({m.group(1) for m in re.finditer(r'<g id="([a-z+-]+?)-topleft"', s)})
if not prefixes: bad.append('no state frames')
for p in prefixes:
    for part in ['topleft', 'top', 'topright', 'left', 'center', 'right', 'bottomleft', 'bottom', 'bottomright']:
        if f'<g id="{p}-{part}">' not in s: bad.append(f'{p}-{part} missing')
    if not p.startswith('mask-') and f'id="{p}-hint-top-margin"' not in s and p != 'focusframe':
        bad.append(f'{p} margin hint missing')
if ' A ' not in s: bad.append('no rounded corner arc')
print('; '.join(bad)); sys.exit(1 if bad else 0)
PY
)"; then
    fail "$label: $report"
  else
    ok "$label (9-part states, scheme classes, no stroke)"
  fi
}

check_plasma_frame_svg() {
  # Yuvarlak popup çerçevesi: köşe parçaları yay (arc) ve iç boşluk ipuçları içermeli.
  local path="$1"
  local label="$2"

  check_plasma_surface_svg "$path" "$label"
  check_contains "$path" '<g id="topleft">' "$label corner element"
  check_contains "$path" ' A ' "$label rounded corner arc"
  check_contains "$path" 'id="hint-top-margin"' "$label content margin hint"
  if grep -Eq 'id="shadow-|id="ro-shadow-' "$path"; then
    fail "$label must not contain popup shadows (TOK-09/10)"
  else
    ok "$label no popup shadows"
  fi
}

check_aurorae_theme() {
  local name="$1"
  local dir="platform/kwin/aurorae/$name"

  check_dir "$dir"
  check_file "$dir/metadata.desktop"
  check_contains "$dir/metadata.desktop" "X-KDE-PluginInfo-Name=$name" "$name Aurorae plugin name"
  check_file "$dir/${name}rc"
  check_contains "$dir/${name}rc" "[Layout]" "$name Aurorae layout group"
  # WD-18: pencereler TOK-09 istisnası; gölge alanı spacing.windowShadow, büyütülmüş pencerede gölge yok.
  local pad
  pad="$(python3 -c "import json; print(json.load(open('core/tokens/spacing.json'))['windowShadow'])")"
  for side in Top Bottom Left Right; do
    check_contains "$dir/${name}rc" "Padding${side}=$pad" "$name window shadow padding $side = $pad"
  done
  check_contains "$dir/decoration.svg" 'id="ro-decoration-topleft-shadow"' "$name active window shadow"
  if grep -Eq 'id="ro-decoration-maximized.*-shadow"' "$dir/decoration.svg"; then
    fail "$name maximized window must not have a shadow"
  else
    ok "$name maximized window has no shadow"
  fi
  check_contains "$dir/close.svg" "rx=" "$name buttons are rounded squares (WD-06 B)"
  check_not_contains "$dir/${name}rc" "BorderLeftMaximized" "$name has no dead Border*Maximized keys (WD-17)"
  check_contains "$dir/metadata.desktop" "Name[tr]=" "$name Turkish display name (WD-04)"
  check_file "$dir/decoration.svg"
  for prefix in decoration decoration-inactive decoration-maximized decoration-maximized-inactive; do
    check_contains "$dir/decoration.svg" "id=\"$prefix-topleft\"" "$name $prefix frame"
  done
  for button in close minimize maximize restore; do
    check_file "$dir/$button.svg"
    check_contains "$dir/$button.svg" 'id="active-center"' "$name $button button"
  done
}

section "Project"
check_file VERSION
check_file README.md
check_file LICENSE
check_file packaging/ro-theme.spec
check_file assets/README.md
check_file docs/release-build.md
check_file packaging/README.md
check_file platform/README.md
check_file platform/plasma/README.md
check_file scripts/README.md
check_file tools/dev/README.md

section "Tokens"
check_json core/tokens/colors.light.json
check_json core/tokens/colors.dark.json
check_contains core/tokens/colors.light.json '"navy": "#213966"' "Ro brand navy"
check_contains core/tokens/colors.light.json '"ink": "#2B2D2F"' "Ro brand ink"
check_token_contrast core/tokens/colors.light.json "RoLight"
check_token_contrast core/tokens/colors.dark.json "RoDark"
check_absent_file core/tokens/palettes "archived trial palettes (COL-31)"
for scheme in RoLight RoDark; do
  check_scheme_contrast "platform/plasma/color-schemes/$scheme.colors"
done
if grep -nE "^[A-Za-z]+=[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}$" scripts/generate-theme.sh >/dev/null; then
  fail "generator contains hard-coded RGB color lines (00 §4.1, COL-21)"
else
  ok "generator has no hard-coded RGB color lines"
fi
check_json core/tokens/motion.json
check_json core/tokens/radius.json
check_json core/tokens/opacity.json
check_json core/tokens/spacing.json
check_token_geometry
check_file dist/tokens/ro-colors.css
check_json dist/tokens/ro-colors.json
check_file dist/tokens/ro-tailwind.js
check_file dist/qml/RoTokens.qml

section "Scripts"
check_shell scripts/generate-theme.sh
check_shell scripts/diagnose.sh
check_shell scripts/check-plasma-runtime.sh
check_shell scripts/apply-dark-defaults.sh

section "Developer Tools"
check_shell tools/dev/install-local.sh
check_shell tools/dev/apply-theme.sh
check_shell tools/dev/test-layout.sh
check_shell tools/dev/test-local-safe.sh
check_shell tools/dev/install-system-preview.sh
check_shell tools/dev/test-rpm.sh
check_shell tools/dev/build-rpm.sh

section "Assets"
check_file assets/wallpapers/light.jpg
check_file assets/wallpapers/dark.jpg
check_file assets/brand/roasd-logo.png

section "Plasma Color Schemes"
check_file platform/plasma/color-schemes/RoLight.colors
check_file platform/plasma/color-schemes/RoDark.colors
check_contains platform/plasma/color-schemes/RoLight.colors "ColorScheme=RoLight" "RoLight color scheme id"
check_contains platform/plasma/color-schemes/RoDark.colors "ColorScheme=RoDark" "RoDark color scheme id"
check_not_contains platform/plasma/color-schemes/RoLight.colors "Wallpaper" "RoLight color scheme wallpaper-free"
check_not_contains platform/plasma/color-schemes/RoDark.colors "Wallpaper" "RoDark color scheme wallpaper-free"
check_not_contains platform/plasma/color-schemes/RoLight.colors "Image=" "RoLight color scheme image-free"
check_not_contains platform/plasma/color-schemes/RoDark.colors "Image=" "RoDark color scheme image-free"
check_contains platform/plasma/color-schemes/RoLight.colors "[Colors:Complementary]" "RoLight complementary group"
# Açık temada kilit ekranı yüzeyi bilerek koyu: açık temanın metin rengi (token'dan hesaplanır)
ro_light_text_rgb="$(python3 -c 'import json; h=json.load(open("core/tokens/colors.light.json"))["text"].lstrip("#"); print(",".join(str(int(h[i:i+2],16)) for i in (0,2,4)))')"
check_contains platform/plasma/color-schemes/RoLight.colors "BackgroundNormal=$ro_light_text_rgb" "RoLight complementary lockscreen dim surface"

for scheme in RoLight RoDark; do
  check_contains "platform/plasma/color-schemes/$scheme.colors" "ChangeSelectionColor=false" "$scheme keeps selection color in inactive views (COL-13)"
  view_bg="$(awk '/^\[Colors:View\]$/ { s = 1; next } /^\[/ { s = 0 } s && /^BackgroundNormal=/ { sub(/^[^=]*=/, ""); print }' "platform/plasma/color-schemes/$scheme.colors")"
  view_alt="$(awk '/^\[Colors:View\]$/ { s = 1; next } /^\[/ { s = 0 } s && /^BackgroundAlternate=/ { sub(/^[^=]*=/, ""); print }' "platform/plasma/color-schemes/$scheme.colors")"
  if [[ -n "$view_bg" && "$view_bg" != "$view_alt" ]]; then
    ok "$scheme view has a distinct alternate row color (COL-15f)"
  else
    fail "$scheme [Colors:View] BackgroundAlternate equals BackgroundNormal ($view_bg); alternate rows are invisible"
  fi
done

section "Plasma Desktop Themes"
check_dir platform/plasma/desktoptheme/RoLight
check_dir platform/plasma/desktoptheme/RoDark
check_json platform/plasma/desktoptheme/RoLight/metadata.json
check_json platform/plasma/desktoptheme/RoDark/metadata.json
check_contains platform/plasma/desktoptheme/RoLight/metadata.json '"Id": "RoLight"' "RoLight desktoptheme id"
check_contains platform/plasma/desktoptheme/RoDark/metadata.json '"Id": "RoDark"' "RoDark desktoptheme id"
check_contains platform/plasma/desktoptheme/RoLight/metadata.json "\"Version\": \"$(tr -d '[:space:]' < VERSION)\"" "RoLight desktoptheme version matches VERSION"
check_contains platform/plasma/desktoptheme/RoDark/metadata.json "\"Version\": \"$(tr -d '[:space:]' < VERSION)\"" "RoDark desktoptheme version matches VERSION"
check_contains platform/plasma/desktoptheme/RoLight/metadata.json '"License": "GPL-3.0-or-later"' "RoLight desktoptheme license"
check_contains platform/plasma/desktoptheme/RoDark/metadata.json '"License": "GPL-3.0-or-later"' "RoDark desktoptheme license"
check_file platform/plasma/desktoptheme/RoLight/colors
check_file platform/plasma/desktoptheme/RoLight/plasmarc
check_not_contains platform/plasma/desktoptheme/RoLight/plasmarc "[Wallpaper]" "RoLight Plasma style wallpaper-free"
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/widgets/background.svg "RoLight widget background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/widgets/panel-background.svg "RoLight panel background"
# FX-15: cam opaklığının tek kaynağı opacity.glass; renk dosyalarında ayrı alfa yok.
glass="$(python3 -c "import json; print(json.load(open('core/tokens/opacity.json'))['glass'])")"
for theme in RoLight RoDark; do
  for f in dialogs/background widgets/panel-background widgets/background; do
    check_contains "platform/plasma/desktoptheme/$theme/$f.svg" "fill-opacity=\"$glass\"" "$theme $f uses opacity.glass ($glass, FX-15)"
  done
done
for m in light dark; do
  check_not_contains "core/tokens/colors.$m.json" '"glass"' "colors.$m.json has no separate glass alpha (FX-15)"
done
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/dialogs/background.svg "RoLight dialog background"
check_file platform/plasma/desktoptheme/RoDark/colors
check_file platform/plasma/desktoptheme/RoDark/plasmarc
check_not_contains platform/plasma/desktoptheme/RoDark/plasmarc "[Wallpaper]" "RoDark Plasma style wallpaper-free"
for theme in RoLight RoDark; do
  python3 -c "import configparser,sys; c=configparser.ConfigParser(); c.read(sys.argv[1]); sys.exit(0 if c.getboolean(\"AdaptiveTransparency\", \"enabled\") else 1)" "platform/plasma/desktoptheme/$theme/plasmarc" && ok "$theme adaptive transparency on (FX-17 revised: opaque bar with a maximized window)" || fail "$theme plasmarc [AdaptiveTransparency] enabled must be true (FX-17)"
done
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/widgets/background.svg "RoDark widget background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/widgets/panel-background.svg "RoDark panel background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/dialogs/background.svg "RoDark dialog background"
for theme in RoLight RoDark; do
  for variant in "" translucent/ solid/; do
    check_plasma_frame_svg "platform/plasma/desktoptheme/$theme/${variant}dialogs/background.svg" "$theme ${variant}dialog frame"
    check_plasma_frame_svg "platform/plasma/desktoptheme/$theme/${variant}widgets/tooltip.svg" "$theme ${variant}tooltip frame"
    check_plasma_frame_svg "platform/plasma/desktoptheme/$theme/${variant}widgets/panel-background.svg" "$theme ${variant}panel frame"
  done
  check_plasma_frame_svg "platform/plasma/desktoptheme/$theme/widgets/translucentbackground.svg" "$theme translucent widget frame"
  for control in lineedit button viewitem; do
    check_plasma_control_svg "platform/plasma/desktoptheme/$theme/widgets/$control.svg" "$theme $control (Ro-drawn, not Breeze fallback)"
  done
  check_plasma_scrollbar_svg "platform/plasma/desktoptheme/$theme/widgets/scrollbar.svg" "$theme scrollbar (Ro-drawn, not Breeze fallback)"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/checkmarks.svg" "$theme checkmarks" "checkbox radiobutton"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/radiobutton.svg" "$theme radiobutton" "hint-size normal shadow checked symbol hover focus"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/switch.svg" "$theme switch" "hint-bar-size handle handle-hover handle-pressed handle-focus handle-shadow inactive-left active-left"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/slider.svg" "$theme slider" "hint-handle-size groove-left groove-highlight-left horizontal-slider-handle horizontal-slider-hover horizontal-slider-focus horizontal-slider-shadow vertical-slider-handle vertical-slider-hover vertical-slider-focus vertical-slider-shadow"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/plasmoidheading.svg" "$theme plasmoidheading" "header-topleft header-top header-topright header-left header-center header-right header-bottomleft header-bottom header-bottomright footer-topleft footer-top footer-topright footer-left footer-center footer-right footer-bottomleft footer-bottom footer-bottomright"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/bar_meter_horizontal.svg" "$theme bar_meter_horizontal" "hint-bar-size bar-inactive-center bar-active-center bar-active-topleft"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/bar_meter_vertical.svg" "$theme bar_meter_vertical" "hint-bar-size bar-inactive-center bar-active-center"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/line.svg" "$theme line" "horizontal-line vertical-line"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/frame.svg" "$theme frame" "plain-center plain-topleft raised-center sunken-center plain-hint-top-margin"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/listitem.svg" "$theme listitem" "normal-center hover-center pressed-center section-center separator normal-hint-left-margin"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/arrows.svg" "$theme arrows" "down-arrow up-arrow left-arrow right-arrow"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/tabbar.svg" "$theme tabbar" "north-active-tab-topleft north-active-tab-top north-active-tab-center north-active-tab-bottom north-active-tab-bottomright north-active-tab-hint-left-margin south-active-tab-topleft south-active-tab-top south-active-tab-center south-active-tab-bottom south-active-tab-bottomright south-active-tab-hint-left-margin west-active-tab-topleft west-active-tab-top west-active-tab-center west-active-tab-bottom west-active-tab-bottomright west-active-tab-hint-left-margin east-active-tab-topleft east-active-tab-top east-active-tab-center east-active-tab-bottom east-active-tab-bottomright east-active-tab-hint-left-margin"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/busywidget.svg" "$theme busywidget" "busywidget 22-22-busywidget 16-16-busywidget"
  check_plasma_indicator_svg "platform/plasma/desktoptheme/$theme/widgets/tasks.svg" "$theme tasks" "normal-hint-top-margin normal-topleft normal-center normal-bottomright focus-topleft focus-center focus-bottomright hover-topleft hover-center hover-bottomright minimized-topleft minimized-center minimized-bottomright attention-topleft attention-center attention-bottomright progress-topleft progress-center progress-bottomright north-normal-topleft north-normal-center north-normal-bottomright north-focus-topleft north-focus-center north-focus-bottomright north-hover-topleft north-hover-center north-hover-bottomright north-minimized-topleft north-minimized-center north-minimized-bottomright north-attention-topleft north-attention-center north-attention-bottomright north-progress-topleft north-progress-center north-progress-bottomright west-normal-topleft west-normal-center west-normal-bottomright west-focus-topleft west-focus-center west-focus-bottomright west-hover-topleft west-hover-center west-hover-bottomright west-minimized-topleft west-minimized-center west-minimized-bottomright west-attention-topleft west-attention-center west-attention-bottomright west-progress-topleft west-progress-center west-progress-bottomright east-normal-topleft east-normal-center east-normal-bottomright east-focus-topleft east-focus-center east-focus-bottomright east-hover-topleft east-hover-center east-hover-bottomright east-minimized-topleft east-minimized-center east-minimized-bottomright east-attention-topleft east-attention-center east-attention-bottomright east-progress-topleft east-progress-center east-progress-bottomright"
  check_aurorae_theme "$theme"
done
if [[ -e platform/plasma/desktoptheme/Ro ]]; then
  fail "removed compatibility desktop theme still exists: platform/plasma/desktoptheme/Ro"
fi

section "Global Themes"
check_global_theme org.ro.light org.ro.light RoLight RoLight
check_global_theme org.ro.dark org.ro.dark RoDark RoDark
check_file platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js
check_file platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js '/usr/share/wallpapers/Ro Light.jpg' "org.ro.light system wallpaper path (PAN-23)"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'new Panel()' "org.ro.light global layout creates the bar"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'org.kde.plasma.icontasks' "org.ro.light bar has the icon task manager"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'reverseIconOrder' "org.ro.light tray arrow on the left"
check_not_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'google-chrome' "org.ro.light pins only installed apps (PAN-18)"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js '/usr/share/wallpapers/Ro Dark.jpg' "org.ro.dark system wallpaper path (PAN-23)"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'new Panel()' "org.ro.dark global layout creates the bar"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'org.kde.plasma.icontasks' "org.ro.dark bar has the icon task manager"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'reverseIconOrder' "org.ro.dark tray arrow on the left"
check_not_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'google-chrome' "org.ro.dark pins only installed apps (PAN-18)"
check_not_contains platform/plasma/layout-templates/org.ro.desktop/contents/layout.js '.remove()' "layout template never removes the user's panels (PAN-22)"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'knownWidgetTypes.indexOf("org.ro.launcher")' "layout uses ro-launcher when installed, Kickoff otherwise (WGT-14)"
check_contains packaging/ro-theme.spec "%{_datadir}/ro-theme/qml/RoTokens.qml" "RPM installs RoTokens.qml for ro-widgets (WGT-02)"
check_not_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'userDataPath() + "/ro-theme' "org.ro.light stale wallpaper API absent"
check_not_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'userDataPath() + "/ro-theme' "org.ro.dark stale wallpaper API absent"
if [[ -e platform/plasma/look-and-feel/org.ro.global ]]; then
  fail "removed compatibility global theme still exists: platform/plasma/look-and-feel/org.ro.global"
fi

section "Layout And Effects"
check_file platform/plasma/layout-templates/org.ro.desktop/metadata.json
check_file platform/plasma/layout-templates/org.ro.desktop/contents/layout.js
check_not_contains platform/plasma/layout-templates/org.ro.desktop/contents/layout.js 'writeConfig("Image"' "layout template wallpaper-free"
check_not_contains tools/dev/test-layout.sh "plasma-apply-wallpaperimage" "layout test wallpaper-free"
check_contains platform/plasma/layout-templates/org.ro.desktop/contents/layout.js 'org.kde.plasma.icontasks' "layout template creates the Ro bar"
if [ -e platform/kwin/effects ]; then fail "platform/kwin/effects must not exist (FX-03: ro-smooth-motion removed)"; else ok "no custom KWin effect (FX-03)"; fi
if grep -rIl -e "kwin4_effect_" -e "ro-smooth-motion" platform packaging scripts/generate-theme.sh tools/dev/test-rpm.sh scripts/diagnose.sh >/dev/null 2>&1; then
  fail "obsolete KWin effect keys or ro-smooth-motion referenced (FX-23)"
else
  ok "no obsolete KWin effect keys (FX-23)"
fi

section "GTK, Icons, Cursor"
check_file platform/gtk/Ro-GTK/gtk-3.0/gtk.css
check_file platform/gtk/Ro-GTK/gtk-4.0/gtk.css
check_file platform/icons/ro-icons/index.theme
check_file platform/cursor/ro-cursor/index.theme

section "Plasma Login Manager And Plymouth"
check_file platform/plasmalogin/20-ro-theme.conf
check_contains platform/plasmalogin/20-ro-theme.conf "WallpaperPlugin=org.kde.image" "Plasma Login Manager image wallpaper plugin"
check_contains platform/plasmalogin/20-ro-theme.conf "file:///usr/share/ro-theme/wallpapers/login.jpg" "Plasma Login Manager Ro wallpaper"
check_file assets/wallpapers/loginv2.jpg
check_absent_file platform/sddm "legacy SDDM source tree"
check_not_contains platform/plasma/look-and-feel/org.ro.light/contents/splash/Splash.qml "#30C7E0" "RoLight splash old cyan accent removed"
check_not_contains platform/plasma/look-and-feel/org.ro.dark/contents/splash/Splash.qml "#30C7E0" "RoDark splash old cyan accent removed"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/lockscreen/README.md "saat alanı" "RoLight lockscreen keeps KDE clock"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/lockscreen/README.md "saat alanı" "RoDark lockscreen keeps KDE clock"
# 16 · Plymouth: two-step modülü, Ro animasyonu (throbber), görseller ve renkler token'dan (PLY-01…07).
check_file platform/plymouth/ro-theme/ro-theme.plymouth
check_contains platform/plymouth/ro-theme/ro-theme.plymouth "ModuleName=two-step" "Plymouth uses two-step (password, progress, firmware logo; PLY-01 C)"
check_contains platform/plymouth/ro-theme/ro-theme.plymouth "UseFirmwareBackground=true" "Plymouth keeps the firmware logo (PLY-04)"
for img in entry bullet lock capslock; do check_file "platform/plymouth/ro-theme/${img}.png"; done
check_absent_file platform/plymouth/ro-theme/ro-theme.script "Plymouth script theme removed (PLY-01 C)"
check_absent_file platform/plymouth/ro-theme/roasd-logo.png "unused Plymouth logo copy removed (PLY-07)"
plymouth_frame_errors=0
for frame in $(seq -f "%04g" 1 86); do
  if [[ ! -f "platform/plymouth/ro-theme/throbber-${frame}.png" ]]; then
    fail "missing Plymouth animation frame: throbber-${frame}.png"
    plymouth_frame_errors=$((plymouth_frame_errors + 1))
  fi
done
if [[ "$plymouth_frame_errors" -eq 0 ]]; then
  ok "Plymouth animation frame sequence 0001-0086"
fi
if report="$(python3 - <<'PYC'
import json, re
from pathlib import Path
d = json.loads(Path('core/tokens/colors.dark.json').read_text())
t = Path('platform/plymouth/ro-theme/ro-theme.plymouth').read_text()
h = lambda k: '0x' + d[k].lstrip('#').lower()
want = {'BackgroundStartColor': h('bootBackground'), 'BackgroundEndColor': h('bootBackground'),
        'ProgressBarBackgroundColor': h('surfaceAlt'), 'ProgressBarForegroundColor': h('accent')}
errs = [f'{k}={v}' for k, v in want.items() if f'{k}={v}' not in t]
size = sum(f.stat().st_size for f in Path('platform/plymouth/ro-theme').iterdir())
if size > 2 * 1024 * 1024:
    errs.append(f'theme is {size // 1024} KB (> 2 MB, PLY-05)')
print('; '.join(errs))
raise SystemExit(1 if errs else 0)
PYC
)"; then
  ok "Plymouth colors from tokens and theme <= 2 MB (PLY-03/05)"
else
  fail "Plymouth theme: $report; run scripts/generate-theme.sh"
fi

section "Packaging"
check_contains packaging/ro-theme.spec "Name:" "RPM name field"
check_contains packaging/ro-theme.spec "ro-theme" "RPM package name"
check_contains packaging/ro-theme.spec "%check" "RPM check phase"
check_contains packaging/ro-theme.spec "%postun" "RPM postun phase"
check_contains packaging/ro-theme.spec "%defattr(-,root,root,-)" "RPM root file ownership default"
check_contains packaging/ro-theme.spec "Requires:       plasma-workspace" "RPM Plasma dependency"
check_contains packaging/ro-theme.spec "Requires:       plasma-desktop" "RPM Plasma desktop dependency"
check_contains packaging/ro-theme.spec "Requires:       plasma-workspace" "RPM Plasma workspace dependency (brings libs, kpackage, kservice; PKG-05)"
check_contains packaging/ro-theme.spec "Recommends:     rsms-inter-fonts" "RPM recommends Inter for window titles (FNT-04, PKG-05)"
check_contains packaging/ro-theme.spec "License:        GPL-3.0-or-later AND CC-BY-SA-4.0" "RPM license covers code and artwork (PKG-08)"
check_file LICENSES/CC-BY-SA-4.0.txt
check_file LICENSES/ASSETS.md
check_contains packaging/ro-theme.spec "URL:            https://github.com/Project-Ro-ASD/Ro-Theme" "RPM URL is the repository (PKG-09)"
check_contains packaging/ro-theme.spec "%doc README.md" "RPM ships only user-facing docs (PKG-15)"
check_not_contains packaging/ro-theme.spec "%doc README.md docs" "RPM does not ship developer docs (PKG-15)"
check_contains packaging/ro-theme.spec "Requires:       plasma-login-manager" "RPM Plasma Login Manager dependency"
check_contains packaging/ro-theme.spec "Requires:       plymouth-plugin-two-step" "RPM Plymouth two-step plugin dependency (PLY-01 C)"
check_contains .github/workflows/rpm-build.yml "plymouth-plugin-two-step" "GitHub workflow installs Plymouth test deps"
# PLY-09/10: çekirdek parametreleri kurulum programının; initramfs yalnız tema değişince ve bir kez üretilir.
check_not_contains packaging/ro-theme.spec "grubby" "RPM does not change kernel parameters (PLY-09)"
check_not_contains packaging/ro-theme.spec "regenerate-all" "RPM does not rebuild every initramfs (PLY-10)"
check_contains packaging/ro-theme.spec 'if [ "$1" -eq 1 ]; then' "RPM selects the Plymouth theme only on first install (PLY-08 B)"
check_contains packaging/ro-theme.spec "Requires:       kf6-kconfig" "RPM KDE config dependency"
check_contains packaging/ro-theme.spec "%dir %{_datadir}/ro-theme" "RPM owns Ro data directory"
check_contains packaging/ro-theme.spec "%dir %{_libexecdir}/ro-theme" "RPM owns Ro libexec directory"
check_contains packaging/ro-theme.spec "ro-theme-diagnose" "RPM diagnose command"
check_contains packaging/ro-theme.spec "plasmalogin/plasmalogin.conf.d/20-ro-theme.conf" "RPM Plasma Login Manager default"
check_contains packaging/ro-theme.spec "wallpapers/login.jpg" "RPM Plasma Login Manager wallpaper"
check_not_contains packaging/ro-theme.spec "tools/dev" "RPM package excludes developer tools"
check_not_contains packaging/ro-theme.spec "%{_datadir}/sddm" "RPM excludes SDDM payload"
check_contains tools/dev/install-system-preview.sh "--group KDE --key ColorScheme --delete" "system preview removes stale KDE ColorScheme fallback"

section "System Defaults (/etc/xdg, DEFAULTS-OWNERSHIP-V1)"
# 22 SYS-01/06/07/11: varsayılanlar üreticiden gelir, %config(noreplace) ile kurulur; %post ve araçlar
# kullanıcı dosyasına ya da /etc/xdg'ye yazmaz.
XDG_DEFAULTS=platform/plasma/defaults/xdg
for f in kdeglobals kcmfonts breezerc plasmarc ksplashrc kscreenlockerrc kwinrc; do
  check_file "$XDG_DEFAULTS/$f"
  check_contains packaging/ro-theme.spec "%config(noreplace) %{_sysconfdir}/xdg/$f" "RPM installs /etc/xdg/$f as %config(noreplace)"
  check_not_contains "$XDG_DEFAULTS/$f" "kwin4_effect_" "$f has no obsolete Plasma 5 effect keys"
done
for g in "[Colors:Window]" "[Colors:View]" "[Colors:Button]" "[Colors:Selection]" "[Colors:Tooltip]" "[Colors:Complementary]" "[Colors:Header]" "[WM]" "[ColorEffects:Disabled]"; do
  check_contains "$XDG_DEFAULTS/kdeglobals" "$g" "system kdeglobals has $g (new users get Ro colors from /etc/xdg)"
done
check_contains "$XDG_DEFAULTS/kdeglobals" "ColorScheme=RoDark" "system kdeglobals selects RoDark"
check_contains "$XDG_DEFAULTS/kdeglobals" "DefaultLightLookAndFeel=org.ro.light" "automatic light/dark pair is Ro (GT-03)"
# 22 SYS-05: global tema defaults ile /etc/xdg aynı değeri vermeli; yoksa global temayı uygulayan ve uygulamayan
# kullanıcı farklı görünüm görür. Koyu paket varsayılanla birebir; açık pakette yalnız moda bağlı adlar farklı olabilir.
if report="$(python3 - <<'PY'
import re
import sys
from pathlib import Path

xdg = Path('platform/plasma/defaults/xdg')

def groups(path):
    out, cur = {}, None
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            cur = line
            out.setdefault(cur, {})
            continue
        k, _, v = line.partition('=')
        out[cur][k.strip()] = v.strip()
    return out

mode_keys = {'ColorScheme', 'theme', 'name', 'Theme'}
errors = []
for mode in ('dark', 'light'):
    d = groups(Path(f'platform/plasma/look-and-feel/org.ro.{mode}/contents/defaults'))
    for head, kv in d.items():
        m = re.match(r'^\[([^\]]+)\]((?:\[[^\]]+\])+)$', head)
        if not m:
            errors.append(f'org.ro.{mode}: {head} has no file prefix')
            continue
        fname, group = m.group(1), m.group(2)
        target = xdg / fname
        if not target.exists():
            continue
        tg = groups(target).get(group, {})
        for k, v in kv.items():
            if k in tg and tg[k] != v and not (mode == 'light' and k in mode_keys):
                errors.append(f'org.ro.{mode} {fname}{group} {k}={v} but /etc/xdg has {tg[k]}')
print('; '.join(errors))
sys.exit(1 if errors else 0)
PY
)"; then
  ok "global theme defaults agree with /etc/xdg (SYS-05)"
else
  fail "global theme and /etc/xdg disagree (SYS-05): $report"
fi
check_contains "$XDG_DEFAULTS/kwinrc" "ButtonsOnRight=IAX" "system kwinrc button layout (WD-16)"
check_file core/tokens/fonts.json
check_json core/tokens/fonts.json
if python3 - <<'PY'
from pathlib import Path
import configparser, json

root = Path('.')
tokens = json.loads((root/'core/tokens/fonts.json').read_text())
def config(path):
    c = configparser.ConfigParser(interpolation=None, strict=True)
    c.optionxform = str
    c.read(path)
    return c
def font(value, role):
    fields = value.split(',')
    f = tokens[role]
    assert len(fields) == 19 and fields[16] == f['styleName'], (role, value)
    assert (fields[0], float(fields[1]), int(fields[4])) == (f['family'], f['pointSize'], f['weight']), (role, value)
system = config(root/'platform/plasma/defaults/xdg/kdeglobals')
font(system['WM']['activeFont'], 'windowTitle')
roles = {'font':'general','fixed':'fixed','smallestReadableFont':'small','toolBarFont':'toolbar','menuFont':'menu'}
for key in roles:
    assert key not in system['General'], 'Fedora-identical font role must remain inherited: '+key
for mode in ['light','dark']:
    c = config(root/f'platform/plasma/look-and-feel/org.ro.{mode}/contents/defaults')
    for key, role in roles.items():
        font(c['kdeglobals][General'][key], role)
    font(c['kdeglobals][WM']['activeFont'], 'windowTitle')
    assert c['kdeglobals][WM']['activeFont'] == system['WM']['activeFont']
r = tokens['rendering']
assert system['General']['XftAntialias'] == str(r['antialias']).lower()
assert system['General']['XftHintStyle'] == r['hintStyle']
assert system['General']['XftSubPixel'] == r['subPixel']
dpi = config(root/'platform/plasma/defaults/xdg/kcmfonts')
assert int(dpi['General']['forceFontDPI']) == tokens['forceFontDPI'] == 0
PY
then
  ok "font roles, rendering and DPI defaults agree with font tokens"
else
  fail "font defaults disagree with font tokens or Fedora inheritance"
fi
if awk '/^\[KDE\]$/ { g = 1; next } /^\[/ { g = 0 } g && /^ColorScheme=/ { f = 1 } END { exit f ? 0 : 1 }' "$XDG_DEFAULTS/kdeglobals"; then
  fail "system kdeglobals contains obsolete [KDE] ColorScheme"
else
  ok "system kdeglobals has no obsolete [KDE] ColorScheme"
fi
check_contains "$XDG_DEFAULTS/kscreenlockerrc" "contents/lockscreen/assets/login.jpg" "system lock screen login wallpaper default"
check_contains "$XDG_DEFAULTS/kscreenlockerrc" "Blur=false" "system lock screen wallpaper blur disabled"
check_contains "$XDG_DEFAULTS/kwinrc" "library=org.kde.kwin.aurorae.v2" "system Ro Aurorae decoration default (WD-02)"
check_contains "$XDG_DEFAULTS/kwinrc" "theme=__aurorae__svg__RoDark" "system Ro Dark decoration theme"
check_contains packaging/ro-theme.spec "Requires:       aurorae" "RPM requires the Aurorae decoration plugin"
check_not_contains "$XDG_DEFAULTS/kwinrc" "[Plugins]" "system kwinrc leaves KWin effects at KDE defaults (FX-02/23)"
check_not_contains packaging/ro-theme.spec "kwin4_effect_" "RPM has no obsolete Plasma 5 effect keys"
check_not_contains packaging/ro-theme.spec "--all-users" "RPM never applies settings to all users"
check_not_contains packaging/ro-theme.spec "xdg/autostart" "RPM ships no autostart that writes user files"
check_not_contains packaging/ro-theme.spec "ro_theme_write_system_defaults" "RPM post does not rewrite system defaults"
post_section="$(awk '/^%post$/ { p = 1; next } /^%[a-z]/ && p { exit } p' packaging/ro-theme.spec)"
if grep -Eq '/etc/xdg|apply-dark-defaults|\$HOME|/home/' <<< "$post_section"; then
  fail "RPM %post writes to /etc/xdg or user files"
else
  ok "RPM %post does not touch /etc/xdg or user files"
fi
check_not_contains scripts/apply-dark-defaults.sh "getent passwd" "apply-dark-defaults only changes the current user"
check_not_contains scripts/apply-dark-defaults.sh "runuser" "apply-dark-defaults never acts as another user"
check_contains "$XDG_DEFAULTS/breezerc" "ViewDrawTreeBranchLines=false" "system Breeze style settings (APP-03)"
check_contains "$XDG_DEFAULTS/kdeglobals" "ShowIconsOnPushButtons=false" "system push buttons without icons (APP-11)"
check_contains scripts/apply-dark-defaults.sh "FILES=(kdeglobals kcmfonts" "explicit appearance reset includes the Ro-managed font DPI default"

printf '\nValidation summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"

if [[ "$errors" -ne 0 ]]; then
  echo "Validation failed. Fix the [FAIL] lines above before installing or building RPM." >&2
  exit 1
fi

echo "Validation passed."
