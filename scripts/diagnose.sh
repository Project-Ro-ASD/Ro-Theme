#!/usr/bin/env bash
set -u

# Kurulu Ro temasında eksik dosya ve aktif ayarları gösteren güvenli tanı aracı.
# Varsayılan mod local kurulumu kontrol eder; RPM sonrası sistem geneli kontrol
# için --system kullanılmalıdır.

errors=0
warnings=0
MODE="local"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SELF_DIR/.." 2>/dev/null && pwd || printf '%s' "$SELF_DIR")"

for arg in "$@"; do
  case "$arg" in
    --local)
      MODE="local"
      ;;
    --system)
      MODE="system"
      ;;
    -h|--help)
      echo "Usage: $0 [--local|--system]"
      echo "  --local   Check files installed by tools/dev/install-local.sh under the current user"
      echo "  --system  Check files installed by the RPM under /usr/share and /usr/bin"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--local|--system]" >&2
      exit 2
      ;;
  esac
done

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

check_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    warn "missing command: $command_name"
  fi
}

check_any_command() {
  local label="$1"
  shift
  local found=0
  local command_name

  for command_name in "$@"; do
    if command -v "$command_name" >/dev/null 2>&1; then
      ok "$label: $command_name ($(command -v "$command_name"))"
      found=1
      break
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    warn "missing command group: $label ($*)"
  fi
}

check_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    ok "$path"
  else
    fail "missing: $path"
  fi
}

check_absent() {
  local path="$1"
  local reason="$2"
  if [[ -e "$path" ]]; then
    fail "$reason still exists: $path"
  else
    ok "$reason removed: $path"
  fi
}

check_system_preview_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    ok "$path"
  elif [[ "$MODE" = "system" ]]; then
    fail "missing: $path"
  else
    warn "missing system preview file: $path"
  fi
}

check_same_file_if_present() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ -f "$expected" && -f "$actual" ]]; then
    if cmp -s "$expected" "$actual"; then
      ok "$label in sync"
    else
      warn "$label differs; run sudo ./tools/dev/install-system-preview.sh or install the rebuilt RPM"
    fi
  fi
}

read_kde_config() {
  local file="$1"
  shift
  local key="${!#}"
  local groups=("${@:1:$(($# - 1))}")
  local args=(--file "$file")
  local group

  for group in "${groups[@]}"; do
    args+=(--group "$group")
  done
  args+=(--key "$key")

  if command -v kreadconfig6 >/dev/null 2>&1; then
    kreadconfig6 "${args[@]}" 2>/dev/null
    return
  fi

  if command -v kreadconfig5 >/dev/null 2>&1; then
    kreadconfig5 "${args[@]}" 2>/dev/null
    return
  fi

  echo ""
}

section "Commands"
check_command rpm
check_command kpackagetool6
check_command lookandfeeltool
check_command plasma-apply-colorscheme
check_command plasma-apply-wallpaperimage
check_any_command "Plasma DBus helper" qdbus6 qdbus qdbus-qt6 qdbus-qt5 gdbus
check_command plymouth-set-default-theme
check_command dracut
check_command grubby

if [[ "$MODE" = "local" ]]; then
  section "Local User Files"
  check_file "$HOME/.local/share/color-schemes/RoLight.colors"
  check_file "$HOME/.local/share/color-schemes/RoDark.colors"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoLight/metadata.json"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoLight/colors"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoLight/plasmarc"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoDark/metadata.json"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoDark/colors"
  check_file "$HOME/.local/share/plasma/desktoptheme/RoDark/plasmarc"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.light/metadata.json"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.dark/metadata.json"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js"
  check_absent "$HOME/.local/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/LockScreen.qml" "Unsafe custom light lockscreen override"
  check_absent "$HOME/.local/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/LockScreen.qml" "Unsafe custom dark lockscreen override"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg"
  check_file "$HOME/.local/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
  check_file "$HOME/.local/share/kwin/effects/ro-smooth-motion/metadata.json"
  check_file "$HOME/.local/share/ro-theme/wallpapers/dark.jpg"
  check_file "$HOME/.local/share/ro-theme/wallpapers/light.jpg"
  check_absent "$HOME/.local/share/plasma/desktoptheme/Ro" "Old Ro compatibility desktoptheme"
  check_absent "$HOME/.local/share/plasma/look-and-feel/org.ro.global" "Old Ro compatibility global theme"

  section "System Preview Files"
  check_system_preview_file /usr/share/sddm/themes/Ro/Main.qml
  check_same_file_if_present "$SOURCE_ROOT/platform/sddm/themes/Ro/Main.qml" /usr/share/sddm/themes/Ro/Main.qml "System SDDM preview"
  check_system_preview_file /usr/share/plymouth/themes/ro-theme/ro-theme.plymouth
else
  section "System RPM Files"
  check_file /usr/share/color-schemes/RoLight.colors
  check_file /usr/share/color-schemes/RoDark.colors
  check_file /usr/share/plasma/desktoptheme/RoLight/metadata.json
  check_file /usr/share/plasma/desktoptheme/RoLight/colors
  check_file /usr/share/plasma/desktoptheme/RoLight/plasmarc
  check_file /usr/share/plasma/desktoptheme/RoDark/metadata.json
  check_file /usr/share/plasma/desktoptheme/RoDark/colors
  check_file /usr/share/plasma/desktoptheme/RoDark/plasmarc
  check_file /usr/share/plasma/look-and-feel/org.ro.light/metadata.json
  check_file /usr/share/plasma/look-and-feel/org.ro.dark/metadata.json
  check_file /usr/share/plasma/look-and-feel/org.ro.light/contents/layouts/org.kde.plasma.desktop-layout.js
  check_file /usr/share/plasma/look-and-feel/org.ro.dark/contents/layouts/org.kde.plasma.desktop-layout.js
  check_absent /usr/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/LockScreen.qml "Unsafe custom light lockscreen override"
  check_absent /usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/LockScreen.qml "Unsafe custom dark lockscreen override"
  check_file /usr/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg
  check_file /usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
  check_file /usr/share/kwin/effects/ro-smooth-motion/metadata.json
  check_file /usr/share/ro-theme/wallpapers/dark.jpg
  check_file /usr/share/ro-theme/wallpapers/light.jpg
  check_file /usr/share/sddm/themes/Ro/Main.qml
  check_file /usr/share/plymouth/themes/ro-theme/ro-theme.plymouth
  check_file /usr/bin/ro-theme-diagnose
  check_absent /usr/share/plasma/desktoptheme/Ro "Old Ro compatibility desktoptheme"
  check_absent /usr/share/plasma/look-and-feel/org.ro.global "Old Ro compatibility global theme"
fi

section "Plasma Runtime"
RUNTIME_CHECKER=""
if [[ -x "$SELF_DIR/check-plasma-runtime.sh" ]]; then
  RUNTIME_CHECKER="$SELF_DIR/check-plasma-runtime.sh"
elif [[ -x /usr/libexec/ro-theme/check-plasma-runtime ]]; then
  RUNTIME_CHECKER="/usr/libexec/ro-theme/check-plasma-runtime"
fi

if [[ -n "$RUNTIME_CHECKER" ]]; then
  "$RUNTIME_CHECKER" popups || warn "popup runtime preflight failed; system tray popups may be broken by missing Plasma packages"
  "$RUNTIME_CHECKER" layout || warn "full panel layout preflight failed; tools/dev/test-layout.sh will skip safely"
else
  warn "check-plasma-runtime.sh not found next to diagnose.sh"
fi

section "Active KDE User Config"
active_scheme="$(read_kde_config kdeglobals General ColorScheme)"
kde_scheme="$(read_kde_config kdeglobals KDE ColorScheme)"
active_look="$(read_kde_config kdeglobals KDE LookAndFeelPackage)"
active_plasma="$(read_kde_config plasmarc Theme name)"
active_splash="$(read_kde_config ksplashrc KSplash Theme)"
active_ro_effect="$(read_kde_config kwinrc Plugins ro-smooth-motionEnabled)"
active_lock_plugin="$(read_kde_config kscreenlockerrc Greeter WallpaperPlugin)"
active_lock_image="$(read_kde_config kscreenlockerrc Greeter Wallpaper org.kde.image General Image)"
printf '  ColorScheme: %s\n' "$active_scheme"
printf '  KDE ColorScheme: %s\n' "$kde_scheme"
printf '  LookAndFeelPackage: %s\n' "$active_look"
printf '  Plasma Theme: %s\n' "$active_plasma"
printf '  Splash Theme: %s\n' "$active_splash"
printf '  Ro KWin Effect: %s\n' "$active_ro_effect"
printf '  Lock Screen WallpaperPlugin: %s\n' "$active_lock_plugin"
printf '  Lock Screen Image: %s\n' "$active_lock_image"
decoration_library="$(read_kde_config kwinrc org.kde.kdecoration2 library)"
decoration_theme="$(read_kde_config kwinrc org.kde.kdecoration2 theme)"
printf '  Decoration Library: %s\n' "$decoration_library"
printf '  Decoration Theme: %s\n' "$decoration_theme"

expected_plasma=""
expected_splash=""
expected_lock_image=""
case "$active_look" in
  org.ro.dark)
    expected_plasma="RoDark"
    expected_splash="org.ro.dark"
    expected_lock_image="plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
    ;;
  org.ro.light)
    expected_plasma="RoLight"
    expected_splash="org.ro.light"
    expected_lock_image="plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg"
    ;;
  org.ro.global)
    warn "Old removed global theme is still active: org.ro.global"
    ;;
  "")
    warn "LookAndFeelPackage is empty; reapply RoDark/RoLight from System Settings or run ./tools/dev/apply-theme.sh dark/light in a source checkout"
    ;;
  *)
    warn "LookAndFeelPackage is not Ro Dark/Light: $active_look"
    ;;
esac

if [[ -n "$kde_scheme" && -n "$active_scheme" && "$kde_scheme" != "$active_scheme" ]]; then
  warn "KDE ColorScheme mismatch: General=$active_scheme, KDE=$kde_scheme; reapply RoLight/RoDark from Colors or run ./tools/dev/apply-theme.sh dark/light in a source checkout"
fi

if [[ -n "$expected_plasma" && "$active_plasma" != "$expected_plasma" ]]; then
  warn "active Plasma theme mismatch: expected $expected_plasma for $active_look, got ${active_plasma:-empty}"
fi

if [[ -n "$expected_splash" && "$active_splash" != "$expected_splash" ]]; then
  warn "active Splash theme mismatch: expected $expected_splash for $active_look, got ${active_splash:-empty}"
fi

if [[ -n "$expected_lock_image" ]]; then
  if [[ "$active_lock_plugin" != "org.kde.image" ]]; then
    warn "lock screen wallpaper plugin mismatch: expected org.kde.image, got ${active_lock_plugin:-empty}"
  fi

  if [[ "$active_lock_image" != *"$expected_lock_image" ]]; then
    warn "lock screen wallpaper mismatch: expected login.jpg for $active_look, got ${active_lock_image:-empty}"
  fi
fi

if [[ "$active_plasma" = "Ro" ]]; then
  warn "old removed Plasma theme is still active: Ro"
fi

if [[ "$decoration_theme" = __aurorae__svg__Breeze* ]]; then
  warn "KWin decoration points to a missing local Aurorae Breeze theme; reapply RoDark/RoLight from System Settings or run ./tools/dev/apply-theme.sh dark/light in a source checkout"
elif [[ -n "$decoration_theme" && "$decoration_theme" != "Breeze" ]]; then
  warn "KWin decoration theme is not Breeze: $decoration_theme"
fi

if [[ -n "$decoration_library" && "$decoration_library" != "org.kde.breeze" ]]; then
  warn "KWin decoration library is not org.kde.breeze: $decoration_library"
fi

section "System Config"
if [[ -f /etc/sddm.conf.d/10-ro-theme.conf ]]; then
  ok "/etc/sddm.conf.d/10-ro-theme.conf"
  sed -n '1,20p' /etc/sddm.conf.d/10-ro-theme.conf
elif [[ "$MODE" = "local" ]]; then
  warn "missing system preview config: /etc/sddm.conf.d/10-ro-theme.conf"
else
  fail "missing: /etc/sddm.conf.d/10-ro-theme.conf"
fi

if command -v rpm >/dev/null 2>&1; then
  section "RPM Verify"
  if rpm -q ro-theme >/dev/null 2>&1; then
    rpm -q ro-theme
    if rpm -V ro-theme; then
      ok "rpm -V ro-theme returned clean"
    else
      warn "rpm -V ro-theme reported local file differences above"
    fi
  else
    if [[ "$MODE" = "system" ]]; then
      fail "ro-theme RPM is not installed"
    else
      warn "ro-theme RPM is not installed; this is expected before RPM testing"
    fi
  fi
fi

section "Recent Crashes"
if command -v coredumpctl >/dev/null 2>&1; then
  recent="$(coredumpctl list --since "30 minutes ago" 2>&1 | grep -E '/usr/bin/plasmashell|/usr/bin/kwin|/usr/libexec/kf6/kioworker|/usr/bin/kwin_wayland' || true)"
  if [[ -n "$recent" ]]; then
    warn "recent Plasma/KWin/KIO coredumps found in the last 30 minutes"
    printf '%s\n' "$recent" | tail -n 20
  else
    ok "no recent Plasma/KWin/KIO coredumps in the last 30 minutes"
  fi
else
  warn "coredumpctl not found; recent crash check skipped"
fi

printf '\nDiagnosis summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"

if [[ "$errors" -ne 0 ]]; then
  echo "Ro theme diagnosis found missing required files." >&2
  exit 1
fi

exit 0
