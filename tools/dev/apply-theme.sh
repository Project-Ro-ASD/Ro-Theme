#!/usr/bin/env bash
set -euo pipefail

# Ro tema uygulama scripti
# Bu script kullanıcı oturumunda light/dark geçişini tek yerden yönetir.
# Tema dosyalarını moda göre EZMEZ; RoLight ve RoDark dosyaları generate-theme.sh ile ayrı üretilir.
# Doğru kullanım:
#   ./tools/dev/apply-theme.sh light
#   ./tools/dev/apply-theme.sh dark
#   ./tools/dev/apply-theme.sh dark --enable-kwin-effect

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MODE="dark"
WARNINGS=0
ENABLE_KWIN_EFFECT="${RO_THEME_ENABLE_KWIN_EFFECT:-0}"
LIVE_PLASMASHELL="${RO_THEME_LIVE_PLASMASHELL:-0}"

for arg in "$@"; do
  case "$arg" in
    light|dark)
      MODE="$arg"
      ;;
    --enable-kwin-effect)
      ENABLE_KWIN_EFFECT=1
      ;;
    --live-plasmashell)
      LIVE_PLASMASHELL=1
      ;;
    -h|--help)
      echo "Usage: $0 [light|dark] [--enable-kwin-effect] [--live-plasmashell]"
      exit 0
      ;;
    *)
      echo "Usage: $0 [light|dark] [--enable-kwin-effect] [--live-plasmashell]" >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  light)
    SCHEME="RoLight"
    LOOK_AND_FEEL="org.ro.light"
    PLASMA_THEME="RoLight"
    WALL="$HOME/.local/share/ro-theme/wallpapers/light.jpg"
    LOCK_WALL="$HOME/.local/share/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg"
    ;;
  dark)
    SCHEME="RoDark"
    LOOK_AND_FEEL="org.ro.dark"
    PLASMA_THEME="RoDark"
    WALL="$HOME/.local/share/ro-theme/wallpapers/dark.jpg"
    LOCK_WALL="$HOME/.local/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
    ;;
  *)
    echo "Usage: $0 light|dark" >&2
    exit 2
    ;;
esac

write_config() {
  # Plasma 6 için kwriteconfig6, eski sistemler için kwriteconfig5 denenir.
  local wrote=1
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 "$@" >/dev/null 2>&1 && wrote=0
  fi
  if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 "$@" >/dev/null 2>&1 && wrote=0
  fi
  return "$wrote"
}

delete_config() {
  # Eski KDE ColorScheme gibi stale anahtarları temizler.
  local wrote=1
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 "$@" --delete "" >/dev/null 2>&1 && wrote=0
  fi
  if command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 "$@" --delete "" >/dev/null 2>&1 && wrote=0
  fi
  return "$wrote"
}

call_dbus() {
  # Fedora/KDE sürüm farkları için qdbus6 ve qdbus beraber denenir.
  local bus
  for bus in qdbus6 qdbus qdbus-qt6 qdbus-qt5; do
    if command -v "$bus" >/dev/null 2>&1; then
      "$bus" "$@" >/dev/null 2>&1 && return 0
    fi
  done
  return 1
}

warn() {
  echo "Warning: $*" >&2
  WARNINGS=$((WARNINGS + 1))
}

write_config_or_warn() {
  local description="$1"
  shift
  if ! write_config "$@"; then
    warn "$description could not be written. Is kwriteconfig5/6 installed?"
  fi
}

echo "Applying Ro $MODE theme..."

# Renk şeması yalnızca KDE uygulama/pencere paletini değiştirir.
# Panel, dock ve popup yüzeyleri için ayrıca aşağıdaki Plasma style ayarı gerekir.
if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
  plasma-apply-colorscheme "$SCHEME" >/dev/null 2>&1 || warn "plasma-apply-colorscheme failed for $SCHEME"
else
  warn "plasma-apply-colorscheme not found; config files will still be written"
fi

# Global theme, renk şeması + Plasma style + splash kimliğini aynı moda bağlar.
# Layout reset işlemi burada yapılmaz; panel yerleşimi için test-layout/global theme reset kullanılır.
write_config_or_warn "LookAndFeelPackage" --file kdeglobals --group KDE --key LookAndFeelPackage "$LOOK_AND_FEEL"
write_config_or_warn "widgetStyle" --file kdeglobals --group KDE --key widgetStyle Breeze
write_config_or_warn "General ColorScheme" --file kdeglobals --group General --key ColorScheme "$SCHEME"
delete_config --file kdeglobals --group KDE --key ColorScheme || true
write_config_or_warn "Plasma theme" --file plasmarc --group Theme --key name "$PLASMA_THEME"
write_config_or_warn "KSplash engine" --file ksplashrc --group KSplash --key Engine KSplashQML
write_config_or_warn "KSplash theme" --file ksplashrc --group KSplash --key Theme "$LOOK_AND_FEEL"
write_config_or_warn "KWin decoration library" --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
write_config_or_warn "KWin decoration theme" --file kwinrc --group org.kde.kdecoration2 --key theme Breeze

# Wallpaper değişimi color scheme dosyalarına yazılmaz; sadece global/apply akışında yapılır.
# Böylece Colors menüsünden RoDark/RoLight seçmek sadece paleti değiştirir.
if [[ -f "$WALL" ]]; then
  WALL_URI="file://$WALL"
  if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALL" >/dev/null 2>&1 || true
  fi

  if [[ "$LIVE_PLASMASHELL" = "1" ]]; then
    # PlasmaShell JS yalnızca açıkça istenirse çalışır. Bozuk plasmoid runtime'larında
    # evaluateScript/refresh çağrıları plasmashell crash döngüsünü tetikleyebilir.
    JS="
    var Desktops = desktops();
    for (var i = 0; i < Desktops.length; i++) {
      var d = Desktops[i];
      d.wallpaperPlugin = 'org.kde.image';
      d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
      d.writeConfig('Image', '$WALL_URI');
      d.writeConfig('FillMode', 2);
    }
    "
    call_dbus org.kde.plasmashell /PlasmaShell evaluateScript "$JS" || \
    call_dbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS" || \
    warn "PlasmaShell wallpaper DBus call failed"
  fi
else
  warn "wallpaper not found: $WALL"
fi

# Kilit ekranı her modda login.jpg görselini kullanır; masaüstü dark/light wallpaper'dan ayrıdır.
if [[ -f "$LOCK_WALL" ]]; then
  LOCK_WALL_URI="file://$LOCK_WALL"
  write_config_or_warn "Lock screen wallpaper plugin" --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
  write_config_or_warn "Lock screen login wallpaper image" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "$LOCK_WALL_URI"
  write_config_or_warn "Lock screen login wallpaper preview" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key PreviewImage "$LOCK_WALL_URI"
else
  warn "lock screen login wallpaper not found: $LOCK_WALL"
fi

# KDE stok animasyonları Ro geçiş hissiyle çakışır.
for key in \
  kwin4_effect_scaleEnabled \
  kwin4_effect_glideEnabled \
  kwin4_effect_squashEnabled \
  kwin4_effect_magiclampEnabled \
  magiclampEnabled \
  kwin4_effect_windowapertureEnabled \
  kwin4_effect_frozenappEnabled; do
  write_config_or_warn "KWin plugin $key" --file kwinrc --group Plugins --key "$key" false
done

if [[ "$ENABLE_KWIN_EFFECT" = "1" ]]; then
  write_config_or_warn "KWin Ro effect" --file kwinrc --group Plugins --key ro-smooth-motionEnabled true
else
  write_config_or_warn "KWin Ro effect" --file kwinrc --group Plugins --key ro-smooth-motionEnabled false
fi

if [[ "$ENABLE_KWIN_EFFECT" = "1" ]]; then
  # KWin paketini Plasma'nın paket sistemine yalnızca açıkça istenirse tanıt.
  if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type KWin/Effect --upgrade platform/kwin/effects/ro-smooth-motion >/dev/null 2>&1 || \
    kpackagetool6 --type KWin/Effect --install platform/kwin/effects/ro-smooth-motion >/dev/null 2>&1 || true
  elif command -v kpackagetool5 >/dev/null 2>&1; then
    kpackagetool5 --type KWin/Effect --upgrade platform/kwin/effects/ro-smooth-motion >/dev/null 2>&1 || \
    kpackagetool5 --type KWin/Effect --install platform/kwin/effects/ro-smooth-motion >/dev/null 2>&1 || true
  fi
fi

call_dbus org.kde.KWin /KWin reconfigure || warn "KWin reconfigure DBus call failed"
if [[ "$LIVE_PLASMASHELL" = "1" ]]; then
  call_dbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell || warn "PlasmaShell refresh DBus call failed"
fi

echo "Ro $MODE theme applied."
echo "KDE stock splash disabled; Ro blur splash enabled."
if [[ "$ENABLE_KWIN_EFFECT" != "1" ]]; then
  echo "Ro KWin JavaScript effect is disabled for safe local testing."
fi
if [[ "$LIVE_PLASMASHELL" != "1" ]]; then
  echo "Live PlasmaShell DBus refresh is disabled for crash-safe testing."
fi
if [[ "$WARNINGS" -ne 0 ]]; then
  echo "Finished with $WARNINGS warning(s). Run ./scripts/diagnose.sh for details." >&2
fi
