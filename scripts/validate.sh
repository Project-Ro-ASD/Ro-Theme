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
  check_contains "$defaults" "LookAndFeelPackage=$look" "$package LookAndFeelPackage"
  check_contains "$defaults" "ColorScheme=$scheme" "$package ColorScheme"
  check_kde_group_without_color_scheme "$defaults" "$package defaults"
  check_contains "$defaults" "name=$plasma" "$package Plasma style"
  check_contains "$defaults" "Engine=KSplashQML" "$package KSplash engine"
  check_contains "$defaults" "Theme=$look" "$package KSplash theme"
  check_contains "$defaults" "library=org.kde.breeze" "$package Breeze decoration library"
  check_contains "$defaults" "theme=Breeze" "$package Breeze decoration theme"
  check_contains "$defaults" "ro-smooth-motionEnabled=false" "$package safe KWin effect default"
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

check_plasma_frame_svg() {
  # Yuvarlak popup çerçevesi: köşe parçaları yay (arc) içermeli, iç boşluk ve gölge tanımlı olmalı
  local path="$1"
  local label="$2"

  check_plasma_surface_svg "$path" "$label"
  check_contains "$path" '<g id="topleft">' "$label corner element"
  check_contains "$path" ' A ' "$label rounded corner arc"
  check_contains "$path" 'id="hint-top-margin"' "$label content margin hint"
}

check_aurorae_theme() {
  local name="$1"
  local dir="platform/kwin/aurorae/$name"

  check_dir "$dir"
  check_file "$dir/metadata.desktop"
  check_contains "$dir/metadata.desktop" "X-KDE-PluginInfo-Name=$name" "$name Aurorae plugin name"
  check_file "$dir/${name}rc"
  check_contains "$dir/${name}rc" "[Layout]" "$name Aurorae layout group"
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
check_contains platform/plasma/desktoptheme/RoLight/metadata.json '"Version": "1.0.1"' "RoLight desktoptheme version"
check_contains platform/plasma/desktoptheme/RoDark/metadata.json '"Version": "1.0.1"' "RoDark desktoptheme version"
check_contains platform/plasma/desktoptheme/RoLight/metadata.json '"License": "GPL-3.0-or-later"' "RoLight desktoptheme license"
check_contains platform/plasma/desktoptheme/RoDark/metadata.json '"License": "GPL-3.0-or-later"' "RoDark desktoptheme license"
check_file platform/plasma/desktoptheme/RoLight/colors
check_file platform/plasma/desktoptheme/RoLight/plasmarc
check_not_contains platform/plasma/desktoptheme/RoLight/plasmarc "[Wallpaper]" "RoLight Plasma style wallpaper-free"
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/widgets/background.svg "RoLight widget background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/panel/panel-background.svg "RoLight panel background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoLight/dialogs/background.svg "RoLight dialog background"
check_file platform/plasma/desktoptheme/RoDark/colors
check_file platform/plasma/desktoptheme/RoDark/plasmarc
check_not_contains platform/plasma/desktoptheme/RoDark/plasmarc "[Wallpaper]" "RoDark Plasma style wallpaper-free"
for theme in RoLight RoDark; do
  check_contains "platform/plasma/desktoptheme/$theme/plasmarc" "enabled=false" "$theme adaptive transparency off (frosted glass stays visible)"
done
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/widgets/background.svg "RoDark widget background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/panel/panel-background.svg "RoDark panel background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/dialogs/background.svg "RoDark dialog background"
for theme in RoLight RoDark; do
  for variant in "" translucent/ solid/; do
    check_plasma_frame_svg "platform/plasma/desktoptheme/$theme/${variant}dialogs/background.svg" "$theme ${variant}dialog frame"
  done
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
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'userDataPath("data") + "/ro-theme/wallpapers/light.jpg"' "org.ro.light wallpaper path"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'userDataPath("data") + "/ro-theme/wallpapers/dark.jpg"' "org.ro.dark wallpaper path"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'new Panel()' "org.ro.light global layout creates panels"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'new Panel()' "org.ro.dark global layout creates panels"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'org.kde.plasma.icontasks' "org.ro.light global layout creates dock tasks"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'org.kde.plasma.icontasks' "org.ro.dark global layout creates dock tasks"
check_contains platform/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js 'dock.hiding = "dodgewindows"' "org.ro.light global layout dock dodge-windows"
check_contains platform/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js 'dock.hiding = "dodgewindows"' "org.ro.dark global layout dock dodge-windows"
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
check_contains platform/plasma/layout-templates/org.ro.desktop/contents/layout.js 'dock.hiding = "dodgewindows"' "layout dock dodge-windows"
check_json platform/kwin/effects/ro-smooth-motion/metadata.json
check_file platform/kwin/effects/ro-smooth-motion/contents/code/main.js

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
check_file platform/plymouth/ro-theme/ro-theme.plymouth
check_file platform/plymouth/ro-theme/ro-theme.script
plymouth_frame_errors=0
for frame in $(seq -f "%04g" 1 86); do
  if [[ ! -f "platform/plymouth/ro-theme/frames/animation/frame_${frame}.png" ]]; then
    fail "missing Plymouth animation frame: frame_${frame}.png"
    plymouth_frame_errors=$((plymouth_frame_errors + 1))
  fi
done
if [[ "$plymouth_frame_errors" -eq 0 ]]; then
  ok "Plymouth animation frame sequence 0001-0086"
fi

section "Packaging"
check_contains packaging/ro-theme.spec "Name:" "RPM name field"
check_contains packaging/ro-theme.spec "ro-theme" "RPM package name"
check_contains packaging/ro-theme.spec "%check" "RPM check phase"
check_contains packaging/ro-theme.spec "%postun" "RPM postun phase"
check_contains packaging/ro-theme.spec "%defattr(-,root,root,-)" "RPM root file ownership default"
check_contains packaging/ro-theme.spec "Requires:       plasma-workspace" "RPM Plasma dependency"
check_contains packaging/ro-theme.spec "Requires:       plasma-desktop" "RPM Plasma desktop dependency"
check_contains packaging/ro-theme.spec "Requires:       plasma-workspace-libs" "RPM Plasma applet plugin dependency"
check_contains packaging/ro-theme.spec "Requires:       plasma-login-manager" "RPM Plasma Login Manager dependency"
check_contains packaging/ro-theme.spec "Requires:       plymouth-plugin-script" "RPM Plymouth script plugin dependency"
check_contains .github/workflows/rpm-build.yml "plymouth-plugin-script" "GitHub workflow installs Plymouth test deps"
check_contains .github/workflows/rpm-build.yml "grubby" "GitHub workflow installs grubby test dep"
check_contains packaging/ro-theme.spec "Requires(post): dracut" "RPM dracut post dependency"
check_contains packaging/ro-theme.spec "Requires:       kf6-kconfig" "RPM KDE config dependency"
check_contains packaging/ro-theme.spec "Requires:       kf6-kservice" "RPM KDE service cache dependency"
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
for f in kdeglobals plasmarc ksplashrc kscreenlockerrc kwinrc; do
  check_file "$XDG_DEFAULTS/$f"
  check_contains packaging/ro-theme.spec "%config(noreplace) %{_sysconfdir}/xdg/$f" "RPM installs /etc/xdg/$f as %config(noreplace)"
  check_not_contains "$XDG_DEFAULTS/$f" "kwin4_effect_" "$f has no obsolete Plasma 5 effect keys"
done
for g in "[Colors:Window]" "[Colors:View]" "[Colors:Button]" "[Colors:Selection]" "[Colors:Tooltip]" "[Colors:Complementary]" "[Colors:Header]" "[WM]" "[ColorEffects:Disabled]"; do
  check_contains "$XDG_DEFAULTS/kdeglobals" "$g" "system kdeglobals has $g (new users get Ro colors from /etc/xdg)"
done
check_contains "$XDG_DEFAULTS/kdeglobals" "ColorScheme=RoDark" "system kdeglobals selects RoDark"
if awk '/^\[KDE\]$/ { g = 1; next } /^\[/ { g = 0 } g && /^ColorScheme=/ { f = 1 } END { exit f ? 0 : 1 }' "$XDG_DEFAULTS/kdeglobals"; then
  fail "system kdeglobals contains obsolete [KDE] ColorScheme"
else
  ok "system kdeglobals has no obsolete [KDE] ColorScheme"
fi
check_contains "$XDG_DEFAULTS/kscreenlockerrc" "contents/lockscreen/assets/login.jpg" "system lock screen login wallpaper default"
check_contains "$XDG_DEFAULTS/kscreenlockerrc" "Blur=false" "system lock screen wallpaper blur disabled"
check_contains "$XDG_DEFAULTS/kwinrc" "library=org.kde.breeze" "system Breeze decoration default"
check_contains "$XDG_DEFAULTS/kwinrc" "ro-smooth-motionEnabled=false" "system safe KWin effect default"
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

printf '\nValidation summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"

if [[ "$errors" -ne 0 ]]; then
  echo "Validation failed. Fix the [FAIL] lines above before installing or building RPM." >&2
  exit 1
fi

echo "Validation passed."
