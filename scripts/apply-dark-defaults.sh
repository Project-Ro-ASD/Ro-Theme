#!/usr/bin/env bash
set -u

# RPM sonrası Ro Dark varsayılanlarını mevcut kullanıcıya veya tüm normal
# kullanıcılara uygular. Hata veren KDE yardımcıları kurulumu bozmasın diye
# fallback yazar, RO_THEME_DEBUG=1 verilirse yakalanan hataları gösterir.

FORCE=0
MODE="current"
DEBUG="${RO_THEME_DEBUG:-0}"
LOCK_WALL_URI="file:///usr/share/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg"
SYSTEM_WALLPAPER_DIR="/usr/share/ro-theme/wallpapers"

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=1
      ;;
    --all-users)
      MODE="all"
      ;;
    --current-user)
      MODE="current"
      ;;
    --debug)
      DEBUG=1
      ;;
    -h|--help)
      echo "Usage: $0 [--current-user|--all-users] [--force] [--debug]"
      exit 0
      ;;
  esac
done

debug() {
  if [[ "$DEBUG" = "1" ]]; then
    printf 'ro-theme defaults: %s\n' "$*" >&2
  fi
}

run_as_user() {
  local user="$1"
  shift

  if [[ "$(id -u 2>/dev/null || echo 1)" -ne 0 ]]; then
    "$@" >/dev/null 2>&1
    return $?
  fi

  if [[ "$(id -un 2>/dev/null || echo "")" = "$user" ]]; then
    "$@" >/dev/null 2>&1
    return $?
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$user" -- "$@" >/dev/null 2>&1
    return $?
  fi

  return 1
}

write_with_kwriteconfig() {
  local user="$1"
  local helper=""

  if command -v kwriteconfig6 >/dev/null 2>&1; then
    helper="kwriteconfig6"
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    helper="kwriteconfig5"
  else
    debug "kwriteconfig5/6 not found"
    return 1
  fi

  run_as_user "$user" "$helper" --file kdeglobals --group KDE --key LookAndFeelPackage org.ro.dark || return 1
  run_as_user "$user" "$helper" --file kdeglobals --group KDE --key widgetStyle Breeze || return 1
  run_as_user "$user" "$helper" --file kdeglobals --group General --key ColorScheme RoDark || return 1
  run_as_user "$user" "$helper" --file kdeglobals --group KDE --key ColorScheme --delete "" || true
  run_as_user "$user" "$helper" --file plasmarc --group Theme --key name RoDark || return 1
  run_as_user "$user" "$helper" --file ksplashrc --group KSplash --key Engine KSplashQML || return 1
  run_as_user "$user" "$helper" --file ksplashrc --group KSplash --key Theme org.ro.dark || return 1
  run_as_user "$user" "$helper" --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image || return 1
  run_as_user "$user" "$helper" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "$LOCK_WALL_URI" || return 1
  run_as_user "$user" "$helper" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key PreviewImage "$LOCK_WALL_URI" || return 1
  run_as_user "$user" "$helper" --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze || return 1
  run_as_user "$user" "$helper" --file kwinrc --group org.kde.kdecoration2 --key theme Breeze || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key ro-smooth-motionEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_scaleEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_glideEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_squashEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_magiclampEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key magiclampEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_windowapertureEnabled false || return 1
  run_as_user "$user" "$helper" --file kwinrc --group Plugins --key kwin4_effect_frozenappEnabled false || return 1

  return 0
}

write_raw_fallback() {
  local home="$1"
  local uid="$2"
  local gid="$3"

  mkdir -p "$home/.config"

  {
    echo "[KDE]"
    echo "LookAndFeelPackage=org.ro.dark"
    echo "widgetStyle=Breeze"
    echo
    echo "[General]"
    echo "ColorScheme=RoDark"
  } > "$home/.config/kdeglobals"

  {
    echo "[Theme]"
    echo "name=RoDark"
  } > "$home/.config/plasmarc"

  {
    echo "[KSplash]"
    echo "Engine=KSplashQML"
    echo "Theme=org.ro.dark"
  } > "$home/.config/ksplashrc"

  {
    echo "[Greeter]"
    echo "WallpaperPlugin=org.kde.image"
    echo
    echo "[Greeter][Wallpaper][org.kde.image][General]"
    echo "Image=$LOCK_WALL_URI"
    echo "PreviewImage=$LOCK_WALL_URI"
  } > "$home/.config/kscreenlockerrc"

  {
    echo "[org.kde.kdecoration2]"
    echo "library=org.kde.breeze"
    echo "theme=Breeze"
    echo
    echo "[Plugins]"
    echo "ro-smooth-motionEnabled=false"
    echo "kwin4_effect_scaleEnabled=false"
    echo "kwin4_effect_glideEnabled=false"
    echo "kwin4_effect_squashEnabled=false"
    echo "kwin4_effect_magiclampEnabled=false"
    echo "magiclampEnabled=false"
    echo "kwin4_effect_windowapertureEnabled=false"
    echo "kwin4_effect_frozenappEnabled=false"
  } > "$home/.config/kwinrc"

  chown "$uid:$gid" \
    "$home/.config/kdeglobals" \
    "$home/.config/plasmarc" \
    "$home/.config/ksplashrc" \
    "$home/.config/kscreenlockerrc" \
    "$home/.config/kwinrc" 2>/dev/null || true
}

install_user_wallpapers() {
  local home="$1"
  local uid="$2"
  local gid="$3"

  mkdir -p "$home/.local/share/ro-theme/wallpapers" "$home/.local/share/wallpapers"

  if [[ -f "$SYSTEM_WALLPAPER_DIR/dark.jpg" ]]; then
    install -m 0644 "$SYSTEM_WALLPAPER_DIR/dark.jpg" "$home/.local/share/ro-theme/wallpapers/dark.jpg" 2>/dev/null || true
    install -m 0644 "$SYSTEM_WALLPAPER_DIR/dark.jpg" "$home/.local/share/wallpapers/Ro Dark.jpg" 2>/dev/null || true
  fi

  if [[ -f "$SYSTEM_WALLPAPER_DIR/light.jpg" ]]; then
    install -m 0644 "$SYSTEM_WALLPAPER_DIR/light.jpg" "$home/.local/share/ro-theme/wallpapers/light.jpg" 2>/dev/null || true
    install -m 0644 "$SYSTEM_WALLPAPER_DIR/light.jpg" "$home/.local/share/wallpapers/Ro Light.jpg" 2>/dev/null || true
  fi

  chown -R "$uid:$gid" "$home/.local/share/ro-theme" 2>/dev/null || true
  chown "$uid:$gid" \
    "$home/.local/share/wallpapers" \
    "$home/.local/share/wallpapers/Ro Dark.jpg" \
    "$home/.local/share/wallpapers/Ro Light.jpg" 2>/dev/null || true
}

apply_to_user() {
  local user="$1"
  local uid="$2"
  local gid="$3"
  local home="$4"
  local marker="$home/.config/ro-theme/default-dark-applied"

  [[ -n "$home" && -d "$home" ]] || return 0

  if [[ "$FORCE" -ne 1 && -f "$marker" ]]; then
    debug "skip $user; marker exists"
    return 0
  fi

  mkdir -p "$home/.config/ro-theme"
  install_user_wallpapers "$home" "$uid" "$gid"

  if write_with_kwriteconfig "$user"; then
    debug "kwriteconfig applied for $user"
  else
    debug "kwriteconfig failed for $user; writing raw fallback"
    write_raw_fallback "$home" "$uid" "$gid"
  fi

  touch "$marker" 2>/dev/null || true
  chown -R "$uid:$gid" "$home/.config/ro-theme" 2>/dev/null || true
}

apply_current_user() {
  local home="${HOME:-}"
  local user
  local uid
  local gid

  user="$(id -un 2>/dev/null || echo "")"
  uid="$(id -u 2>/dev/null || echo 0)"
  gid="$(id -g 2>/dev/null || echo 0)"

  apply_to_user "$user" "$uid" "$gid" "$home"
}

apply_all_users() {
  getent passwd | while IFS=: read -r user _ uid gid _ home shell; do
    case "$shell" in
      */nologin|*/false)
        continue
        ;;
    esac

    if [[ "$uid" -ge 1000 && -d "$home" ]]; then
      apply_to_user "$user" "$uid" "$gid" "$home"
    fi
  done
}

case "$MODE" in
  all)
    apply_all_users
    ;;
  current)
    apply_current_user
    ;;
esac

exit 0
