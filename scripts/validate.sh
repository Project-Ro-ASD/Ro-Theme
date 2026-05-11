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
check_contains core/tokens/colors.dark.json "#FAF0E6" "RoDark palette color FAF0E6"
check_contains core/tokens/colors.dark.json "#B9B4C7" "RoDark palette color B9B4C7"
check_contains core/tokens/colors.dark.json "#5C5470" "RoDark palette color 5C5470"
check_contains core/tokens/colors.dark.json "#352F44" "RoDark palette color 352F44"
check_contains core/tokens/colors.light.json "#E5E1DA" "RoLight palette color E5E1DA"
check_contains core/tokens/colors.light.json "#FBF9F1" "RoLight palette color FBF9F1"
check_contains core/tokens/colors.light.json "#AAD7D9" "RoLight palette color AAD7D9"
check_contains core/tokens/colors.light.json "#92C7CF" "RoLight palette color 92C7CF"
check_json core/tokens/motion.json
check_json core/tokens/radius.json
check_json core/tokens/opacity.json
check_json core/tokens/spacing.json
check_file dist/tokens/ro-colors.css
check_json dist/tokens/ro-colors.json
check_file dist/tokens/ro-tailwind.js

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
check_contains platform/plasma/color-schemes/RoLight.colors "BackgroundNormal=47,89,96" "RoLight complementary lockscreen dim surface"

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
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/widgets/background.svg "RoDark widget background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/panel/panel-background.svg "RoDark panel background"
check_plasma_surface_svg platform/plasma/desktoptheme/RoDark/dialogs/background.svg "RoDark dialog background"
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

section "SDDM And Plymouth"
check_file platform/sddm/themes/Ro/Main.qml
check_file platform/sddm/themes/Ro/theme.conf
check_file platform/sddm/themes/Ro/metadata.desktop
check_file platform/sddm/themes/Ro/assets/login.jpg
check_file platform/sddm/themes/Ro/assets/roasd-logo.png
check_absent_file platform/sddm/themes/Ro/assets/light.jpg "unused SDDM light wallpaper"
check_absent_file platform/sddm/themes/Ro/assets/dark.jpg "unused SDDM dark wallpaper"
check_contains platform/sddm/themes/Ro/Main.qml "sessionModel" "SDDM session chooser support"
check_contains platform/sddm/themes/Ro/Main.qml "Instantiator" "SDDM session model instantiator"
check_contains platform/sddm/themes/Ro/Main.qml "model.index" "SDDM real session index usage"
check_contains platform/sddm/themes/Ro/Main.qml "sessionIndexValue" "SDDM session index role"
check_contains platform/sddm/themes/Ro/Main.qml "keyboard.layouts" "SDDM keyboard layout chooser support"
check_contains platform/sddm/themes/Ro/Main.qml "selectedUserAvatar" "SDDM user avatar binding"
check_contains platform/sddm/themes/Ro/Main.qml "userAvatarAt" "SDDM user avatar lookup"
check_contains platform/sddm/themes/Ro/Main.qml "assets/roasd-logo.png" "SDDM login card logo"
check_contains platform/sddm/themes/Ro/Main.qml "#352F44" "SDDM Ro dark background color"
check_contains platform/sddm/themes/Ro/Main.qml "#AAD7D9" "SDDM Ro soft auth accent"
check_contains platform/sddm/themes/Ro/Main.qml "#92C7CF" "SDDM Ro action auth accent"
check_contains platform/sddm/themes/Ro/Main.qml "#FAF0E6" "SDDM Ro text color"
check_not_contains platform/sddm/themes/Ro/Main.qml "#30C7E0" "SDDM old cyan accent removed"
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
check_contains packaging/ro-theme.spec "Requires:       plymouth-plugin-script" "RPM Plymouth script plugin dependency"
check_contains .github/workflows/rpm-build.yml "plymouth-plugin-script" "GitHub workflow installs Plymouth test deps"
check_contains .github/workflows/rpm-build.yml "grubby" "GitHub workflow installs grubby test dep"
check_contains packaging/ro-theme.spec "Requires(post): dracut" "RPM dracut post dependency"
check_contains packaging/ro-theme.spec "Requires:       kf6-kconfig" "RPM KDE config dependency"
check_contains packaging/ro-theme.spec "Requires:       kf6-kservice" "RPM KDE service cache dependency"
check_contains packaging/ro-theme.spec "%dir %{_datadir}/ro-theme" "RPM owns Ro data directory"
check_contains packaging/ro-theme.spec "%dir %{_libexecdir}/ro-theme" "RPM owns Ro libexec directory"
check_contains packaging/ro-theme.spec "ro-theme-diagnose" "RPM diagnose command"
check_contains packaging/ro-theme.spec "kscreenlockerrc" "RPM lock screen wallpaper default"
check_contains packaging/ro-theme.spec "ro_theme_write_system_defaults" "RPM post enforces system defaults"
check_contains packaging/ro-theme.spec "contents/lockscreen/assets/login.jpg" "RPM lock screen login wallpaper default"
check_contains packaging/ro-theme.spec "Blur=false" "RPM lock screen wallpaper blur disabled"
check_contains packaging/ro-theme.spec "library=org.kde.breeze" "RPM Breeze decoration default"
check_contains packaging/ro-theme.spec "ro-smooth-motionEnabled=false" "RPM safe KWin effect default"
check_contains packaging/ro-theme.spec "--group KDE --key ColorScheme --delete" "RPM removes stale KDE ColorScheme fallback"
check_not_contains packaging/ro-theme.spec "tools/dev" "RPM package excludes developer tools"
check_contains tools/dev/install-system-preview.sh "--group KDE --key ColorScheme --delete" "system preview removes stale KDE ColorScheme fallback"

printf '\nValidation summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"

if [[ "$errors" -ne 0 ]]; then
  echo "Validation failed. Fix the [FAIL] lines above before installing or building RPM." >&2
  exit 1
fi

echo "Validation passed."
